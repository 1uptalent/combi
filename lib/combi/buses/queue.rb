require 'combi/buses/bus'
require 'combi/queue_service'

module Combi
  class Queue < Bus
    attr_reader :queue_service

    def initialize(options)
      super
      @queue_service = nil
    end

    def log(message)
      puts "#{object_id} #{self.class.name} #{message}"
    end

    def start!
      @queue_service = Combi::QueueService.new(@options[:amqp_config], rpc: :enabled)
      100.times do
        return if queue_service.ready?
        sleep 0.1
      end
      raise "Queue service didn't get to a ready state"
    end

    def request(name, kind, message, options = {timeout: 0.1}, &block)
      options[:routing_key] = name
      options[:timeout] ||= RPC_DEFAULT_TIMEOUT
      if block.nil? || options[:async] == false
        queue_service.call(kind, message, options, &block)
      else
        request_sync(kind, message, options, &block)
        #queue_service.call(kind, message, options, &block)
      end
    end

    def request_sync(kind, message, options, &block)
      raw_response = nil
      EM::run do
        elapsed = 0
        queue_service.call(kind, message, options) do |async_response|
          raw_response = async_response
        end
        poll_time = options[:timeout].fdiv RPC_MAX_POLLS
        while(raw_response.nil? && elapsed < options[:timeout]) do
          puts "."
          sleep(poll_time)
          elapsed += poll_time
        end
        if raw_response == nil && elapsed >= options[:timeout]
          raise Timeout::Error
        else
          puts "RESPONSE!!"
          block.call(raw_response['response'])
        end
      end
    end

    def respond_to(service_instance, handler, options = {})
      EventMachine::run do
        queue_options = {}
        subscription_options = {}
        if options[:fast] == true
          queue_options[:auto_delete] = false
        else
          subscription_options[:ack] = true
        end
        queue_service.queue(handler.to_s, queue_options).subscribe(subscription_options) do |delivery_info, payload|
          puts "--->"
          puts payload
          puts "----"
          respond service_instance, payload, delivery_info
          queue_service.acknowledge delivery_info unless options[:fast] == true
        end
      end
    end

    def respond(service_instance, request, delivery_info)
      message = JSON.parse request
      kind = message['kind']
      payload = message['payload']
      options = message['options']
      return unless service_instance.respond_to?(kind)
      response = service_instance.send(kind, payload)
      puts "<---"
      puts response
      puts "----"

      queue_service.respond(response, delivery_info) unless response.nil?
    end

  end
end
