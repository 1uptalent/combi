module Combi
  class Queue < Bus

    def post_initialize
      unless @options[:init_queue] == false
        require 'queue_service'
        EventMachine.next_tick do
          QueueService.start(ConfigProvider.for(:amqp), rpc: :enabled)
        end
      end
    end

    def start!
      @stop_requested = false
      until stop_requested?
        loop
        sleep 1 unless stop_requested?
      end
    end

    def stop!
      @stop_requested = true
      puts "stop requested"
      EM.stop_event_loop if EM.reactor_running?
    end

    def restart!
      stop!
      start!
    end

    def loop
      EventMachine.run do
        Signal.trap("INT")  { stop! }
        Signal.trap("TERM") { stop! }
      end
    end

    def stop_requested?
      @stop_requested
    end

    def request(name, kind, message, options = {timeout: 0.1}, &block)
      options[:routing_key] = name
      queue_service.call(kind, message, options, &block)
    end

    def respond_to(service_instance, handler, options)
      EventMachine.next_tick do
        queue_options = {}
        subscription_options = {}
        if options[:fast] == true
          queue_options[:auto_delete] = false
        else
          subscription_options[:ack] = true
        end
        queue_service.queue(handler.to_s, queue_options).subscribe(subscription_options) do |delivery_info, payload|
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
      queue_service.respond(response, delivery_info) unless response.nil?
    end

    def queue_service
      @@queue_service ||= QueueService.instance
    end

  end
end
