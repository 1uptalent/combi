require 'amqp'
require 'amqp/utilities/event_loop_helper'

module Combi
  class QueueService

    RPC_DEFAULT_TIMEOUT = 1
    RPC_WAIT_PERIOD = 0.01

    def initialize(config, options)
      @response_store = ResponseStore.new
      @rpc_queue = nil
      @ready = false
      EM::next_tick do
        connect config do
          if options[:rpc] == :enabled
            create_rpc_queue
          else
            @ready = true
          end
        end
      end
    end

    def ready?
      @ready
    end

    def log(message)
      puts "#{object_id} #{self.class.name} #{message}"
    end

    def connect(config, &after_connect)
      @amqp_conn = AMQP.connect(config) do |connection, open_ok|
        @channel = AMQP::Channel.new @amqp_conn
        @channel.auto_recovery = true
        @exchange = @channel.direct ''
        after_connect.call
      end
    end

    def publish(*args, &block)
      args[0] = args[0].to_json if args[0].is_a? Hash
      @exchange.publish *args, &block
    end

    def queue(name, options = {}, &block)
      @channel.queue(name, options, &block)
    end

    def acknowledge(delivery_info)
      @channel.acknowledge(delivery_info.delivery_tag, false)
    end

    def respond(response, delivery_info)
      response = response.call if response.respond_to? :call
      publish response, routing_key: delivery_info.reply_to, correlation_id: delivery_info.correlation_id
    end

    def create_rpc_queue
      @rpc_queue.unsubscribe unless @rpc_queue.nil?
      @rpc_queue = queue('', exclusive: true, auto_delete: true) do |rpc_queue|
        log "\tRPC QUEUE: #{@rpc_queue.name}"
        @ready = true
        rpc_queue.subscribe &@response_store.method(:handle_rpc_response)
      end
    end

    def call(kind, message, options = {routing_key: 'rcalls_queue'}, &block)
      log "sending request #{message.inspect} with options #{options.inspect}"
      raise "RPC is not enabled or reply_to is not included" if (@rpc_queue.nil? || @rpc_queue.name.nil?) && options[:reply_to].nil?
      reply_to = options[:reply_to] || @rpc_queue.name
      log "reply to: #{reply_to}"
      options[:timeout] ||= RPC_DEFAULT_TIMEOUT
      correlation_id = rand(10_000_000).to_s
      request = {
        kind: kind,
        payload: message,
        options: {}
      }
      publish(request, routing_key: options[:routing_key], reply_to: reply_to, correlation_id: correlation_id)
      return if block.nil?
      EventedWaiter.wait_for(correlation_id, @response_store, options[:timeout], &block)
    end

    class ResponseStore
      def initialize()
        @responses = {}
      end

      def handle_rpc_response(header, response)
        store header.correlation_id,
              { 'response' => response,
                'amqp_header' => header }
      end

      def store(key, value)
        @responses[key] = value
      end

      def poll(key)
        @responses[key]
      end
    end

    class EventedWaiter
      def self.wait_for(key, response_store, timeout, &block)
        @waiter = new(key, response_store, timeout, Combi::Bus::RPC_MAX_POLLS, block)
        @waiter.evented_wait
      end

      def initialize(key, response_store, timeout, max_polls, block)
        @key = key
        @response_store = response_store
        @timeout = timeout
        @max_polls = max_polls
        @block = block
        @poll_delay = timeout.fdiv Combi::Bus::RPC_MAX_POLLS
        @elapsed = 0.0
      end

      def evented_wait
        @elapsed += @poll_delay
        value = @response_store.poll(@key)
        if value.nil? && @elapsed < @timeout
          EM.add_timer @poll_delay, &method(:evented_wait)
        elsif @elapsed < @timeout
          @block.call value
        else
          # timeout
        end
      end
    end

  end
end
