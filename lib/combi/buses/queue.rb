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

    def respond_to(service_instance, action, options = {})
      log "registering #{action}"
      queue_options = {}
      subscription_options = {}
      if options[:fast] == true
        queue_options[:auto_delete] = false
      else
        subscription_options[:ack] = true
      end
      queue_service.ready do
        queue_service.queue(action.to_s, queue_options) do |queue|
          log "subscribing to queue #{action.to_s} with options #{queue_options}"
          queue.subscribe(subscription_options) do |delivery_info, payload|
            respond service_instance, payload, delivery_info
            queue_service.acknowledge delivery_info unless options[:fast] == true
          end
        end
      end
    end

    def request(name, kind, message, options = {})
      log "Preparing request: #{name}.#{kind} #{message.inspect[0..500]}\t|| #{options.inspect}"
      options[:timeout] ||= RPC_DEFAULT_TIMEOUT
      options[:routing_key] = name.to_s
      correlation_id = Combi::Correlation.generate
      options[:correlation_id] = correlation_id
      waiter = EventedWaiter.wait_for(correlation_id, @response_store, options[:timeout])
      queue_service.ready do
        log "Making request: #{name}.#{kind} #{message.inspect[0..500]}\t|| #{options.inspect[0..500]}"
        queue_service.call(kind, message, options)
      end
      waiter
    end

    def respond(service_instance, request, delivery_info)
      message = JSON.parse request
      kind = message['kind']
      payload = message['payload']
      options = message['options']
      if service_instance.respond_to?(kind)
        log "generating response for #{service_instance.class}#{service_instance.actions.inspect}.#{kind} #{payload.inspect[0..500]}"
        begin
          response = service_instance.send(kind, payload)
        rescue Exception => e
          response = {error: true, message: e.message}
        end
      else
        log "Service instance does not respond to #{kind}: #{service_instance.inspect}"
        response = {error: true, message: 'unknown action'}
      end
      if response.respond_to? :succeed
        log "response is deferred"
        response.callback do |service_response|
          log "responding with deferred answer: #{service_response.inspect[0..500]}"
          queue_service.respond(service_response.to_json, delivery_info)
        end
      else
        log "responding with inmediate answer: #{response.inspect[0..500]}"
        queue_service.respond(response.to_json, delivery_info) unless response.nil?
      end
    end

  end
end
