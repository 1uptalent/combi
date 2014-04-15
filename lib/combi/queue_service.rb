require 'amqp'
require 'amqp/utilities/event_loop_helper'

module Combi
  class QueueService

    RPC_DEFAULT_TIMEOUT = 1
    RPC_WAIT_PERIOD = 0.01

    class << self
      def start(config = CONFIG_AMQP, options = {})
        $stdout.sync = true
        EM.error_handler do |error|
          puts "\tERROR"
          puts "\t#{error.inspect}"
          puts error.backtrace
        end
        instance.connect config
        @rpc_queue = nil
        instance.create_rpc_queue if options[:rpc] == :enabled
      end

      def instance
        @@instance ||= self.new
      end
    end

    def connect(config)
      @amqp_conn = AMQP.connect(config)
      @amqp_conn.on_error do |conn, conn_close|
        puts "error in connection to rabbit mq"
      end
      @channel = AMQP::Channel.new @amqp_conn
      @channel.auto_recovery = true
      @exchange = @channel.direct ''
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
      if response.is_a? Proc
        Thread.new do
          publish response.call, routing_key: delivery_info.reply_to, correlation_id: delivery_info.correlation_id
        end
      else
        publish response, routing_key: delivery_info.reply_to, correlation_id: delivery_info.correlation_id
      end
    end

    def create_rpc_queue
      @rpc_queue.unsubscribe unless @rpc_queue.nil?
      @rpc_responses = {}
      @rpc_queue = queue('', exclusive: true, auto_delete: true) do |rpc_queue|
        rpc_queue.subscribe do |header, response|
          @rpc_responses[header.correlation_id] = [response, header]
        end
      end
    end

    def call(kind, message, options = {routing_key: 'rcalls_queue'}, &block)
      raise "RPC is not enabled or reply_to is not included" if @rpc_queue.nil? && options[:reply_to].nil?
      reply_to = options[:reply_to] || @rpc_queue.name
      options[:timeout] ||= RPC_DEFAULT_TIMEOUT
      correlation_id = rand(10_000_000).to_s
      request = {
        kind: kind,
        payload: message,
        options: {}
      }
      publish(request, routing_key: options[:routing_key], reply_to: reply_to, correlation_id: correlation_id)
      return if block.nil?
      elapsed = 0
      args = @rpc_responses[correlation_id]
      while(args.nil? && elapsed < options[:timeout]) do
        sleep(RPC_WAIT_PERIOD)
        elapsed += RPC_WAIT_PERIOD
        args = @rpc_responses[correlation_id]
      end
      args ||= [nil, {error: 'timeout'}]
      block.call(*args)
    end
  end
end
