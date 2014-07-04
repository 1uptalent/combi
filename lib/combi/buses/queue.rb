require 'combi/buses/bus'
require 'combi/response_store'
require 'combi/queue_service'

module Combi
  class Queue < Bus
    attr_reader :queue_service

    def initialize(options)
      super
      @response_store = Combi::ResponseStore.new
      @queue_service = Combi::QueueService.new(options[:amqp_config], rpc: :enabled)
      queue_service.rpc_callback = lambda do |message|
        @response_store.handle_rpc_response(message)
      end
    end

    def start!
      queue_service.start
    end

    def stop!
      queue_service.ready do
        @queue_service.disconnect
      end
    end

    def add_routes_for(service_name, service_instance)
      create_queue_for_service(service_name)
      super
    end

    def create_queue_for_service(service_name)
      Combi.logger.debug {"creating queue #{service_name}"}
      queue_options = {}
      subscription_options = {}
      subscription_options[:ack] = true
      queue_service.ready do
        queue_service.queue(service_name.to_s, queue_options) do |queue|
          Combi.logger.debug {"subscribing to queue #{service_name.to_s}"}
          queue.subscribe(subscription_options) do |delivery_info, payload|
            process_queue_message service_name, payload, delivery_info
            queue_service.acknowledge delivery_info
          end
        end
      end
    end

    def request(name, kind, message, timeout: RPC_DEFAULT_TIMEOUT, fast: false)
      Combi.logger.debug {"Preparing request: #{name}.#{kind} #{message.inspect[0..500]}\t|| timeout: #{timeout} fast: #{fast}"}
      options = {
        timeout: timeout,
        routing_key: name.to_s
      }
      if fast
        waiter = nil
      else
        correlation_id = Combi::Correlation.generate
        options[:correlation_id] = correlation_id
        waiter = @response_store.wait_for correlation_id, timeout
      end
      queue_service.next_ready_only do
        Combi.logger.debug {"Making request: #{name}.#{kind} #{message.inspect[0..500]}\t|| #{options.inspect[0..500]}"}
        queue_service.publish_request(kind, message, options)
      end
      waiter
    end

    def process_queue_message(service_name, request, delivery_info)
      message = Yajl::Parser.parse request, symbolize_keys: true
      kind = message[:kind]
      payload = message[:payload]
      options = message[:options]
      response = invoke_service(service_name, kind, payload)
      if delivery_info.reply_to
        response.callback do |service_response|
          queue_service.respond service_response, delivery_info
        end
        response.errback do |service_response|
          failure_response = { error: service_response }
          queue_service.respond failure_response, delivery_info
        end
      end
    end

  end
end
