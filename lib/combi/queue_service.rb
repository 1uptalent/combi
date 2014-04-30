require 'amqp'
require 'amqp/utilities/event_loop_helper'

module Combi
  class QueueService

    RPC_DEFAULT_TIMEOUT = 1
    RPC_WAIT_PERIOD = 0.01

    attr_accessor :rpc_callback

    def initialize(config, options)
      @config = config
      @options = options
      @rpc_queue = nil
      @ready_defer = EventMachine::DefaultDeferrable.new
    end

    def ready(&block)
      @ready_defer.callback &block
    end

    def log(message)
      return unless @debug_mode ||= ENV['DEBUG'] == 'true'
      puts "#{object_id} #{self.class.name} #{message}"
    end

    def start
      connect @config do
        if @options[:rpc] == :enabled
          create_rpc_queue
        else
          puts "ready"
          @ready_defer.succeed
        end
      end
    end

    def connect(config, &after_connect)
      @amqp_conn = AMQP.connect(config) do |connection, open_ok|
        @channel = AMQP::Channel.new @amqp_conn
        @channel.auto_recovery = true
        @exchange = @channel.direct ''
        after_connect.call
      end
    end

    def disconnect
      @amqp_conn.close do
        puts "disconnected from RABBIT"
      end
    end

    def publish(*args, &block)
      args[0] = args[0].to_json unless args[0].is_a? String
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
        rpc_queue.subscribe do |metadata, response|
          message = {
            'correlation_id' => metadata.correlation_id,
            'response' => response
          }
          rpc_callback.call(message) unless rpc_callback.nil?
        end
        @ready_defer.succeed
      end
    end

    def call(kind, message, options = {})
      log "sending request #{kind} #{message.inspect} with options #{options.inspect}"
      raise "RPC is not enabled or reply_to is not included" if (@rpc_queue.nil? || @rpc_queue.name.nil?) && options[:reply_to].nil?
      options[:timeout] ||= RPC_DEFAULT_TIMEOUT
      options[:routing_key] ||= 'rcalls_queue'
      options[:reply_to] ||= @rpc_queue.name
      request = {
        kind: kind,
        payload: message,
        options: {}
      }
      publish(request, options)
    end

  end
end
