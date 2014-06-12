require 'amqp'
require 'amqp/utilities/event_loop_helper'

module Combi
  class QueueService

    attr_accessor :rpc_callback

    def initialize(config, options)
      @config = config
      @options = options
      @rpc_queue = nil
      @ready_defer = EventMachine::DefaultDeferrable.new
      @ready_callbacks = []
    end

    def ready(&block)
      @ready_callbacks << block
      @ready_defer.callback &block
    end

    def next_ready_only(&block)
      @ready_defer.callback &block
    end

    def log(message)
      return unless @debug_mode ||= ENV['DEBUG'] == 'true'
      puts "#{Time.now.to_f} #{self.class.name} #{message}"
    end

    def start
      @config[:reconnect_period] ||= 4
      reconnection_proc = Proc.new { EM.add_timer(@config[:reconnect_period] * rand) { start } }
      @config[:on_tcp_connection_failure] = reconnection_proc
      @config[:on_possible_authentication_failure] = reconnection_proc
      connect @config do
        if @options[:rpc] == :enabled
          create_rpc_queue
        else
          @ready_defer.succeed
        end
      end
    end

    def connect(config, &after_connect)
      puts "[INFO] trying to connect to queue"
      @amqp_conn = AMQP.connect(config) do |connection, open_ok|
        @channel = AMQP::Channel.new @amqp_conn
        @channel.auto_recovery = true
        @exchange = @channel.direct ''
        after_connect.call
        connection.on_tcp_connection_loss do |conn, settings|
          puts "[ERROR] Connection failed, resetting for reconnect"
          reconnect
        end
      end
    end

    def reconnect
      @ready_defer = EventMachine::DefaultDeferrable.new
      @ready_callbacks.each do |callback|
        @ready_defer.callback &callback
      end
      start
    end

    def disconnect
      @amqp_conn.close
    end

    def publish(*args, &block)
      @exchange.publish *args do
        block.call if block_given?
      end
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
      log "sending request #{kind} #{message.inspect[0..500]} with options #{options.inspect}"
      raise "RPC is not enabled or reply_to is not included" if (@rpc_queue.nil? || @rpc_queue.name.nil?) && options[:reply_to].nil?
      options[:expiration] = ((options[:timeout] || RPC_DEFAULT_TIMEOUT) * 1000).to_i
      options[:routing_key] ||= 'rcalls_queue'
      options[:reply_to] ||= @rpc_queue.name
      request = {
        kind: kind,
        payload: message,
        options: {}
      }
      publish(request.to_json, options)
    end

  end
end
