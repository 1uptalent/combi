module Combi
  class WebSocket < Bus

    def post_initialize
      require 'faye/websocket'
      @remote_api = @options[:remote_api]
      if @remote_api
        @handler = @options[:handler]
        require 'eventmachine'
      end
    end

    def start!
      @stop_requested = false
      until stop_requested?
        loop
        back_off! unless stop_requested?
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
      EM.run do
        @ws = Faye::WebSocket::Client.new(@remote_api)
        @ws.on :open do |event|
          reset_back_off_delay!
          @handler.on_open
        end

        @ws.on :message do |event|
          message = JSON.parse(event.data)
          if is_response?(message)
            @handler.handle_response(message)
          else
            @handler.handle_command(message)
          end
        end

        @ws.on :close do |event|
          puts "close client web socket"
          @ws = nil
          EM::stop_event_loop
        end
      end
    end

    def stop_requested?
      @stop_requested
    end

    def send(payload)
      return unless @ws
      @ws.send payload
    end

    def request(env, handler)
      return unless Faye::WebSocket.websocket?(env)
      ws = Faye::WebSocket.new(env)
      session = nil

      ws.on :message do |event|
        session.process JSON.parse(event.data)
      end

      ws.on :open do |event|
        session = handler.new_session(ws)
      end

      ws.on :close do |event|
        session.close
      end

      # Return async Rack response
      ws.rack_response
    end

    def request_x(name, kind, message, options = {timeout: 0.1}, &block)
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

    protected

    def reset_back_off_delay!
      @back_off_delay = 1
    end

    def back_off!
      sleep @back_off_delay
      @back_off_delay = [@back_off_delay * 2, 300].min
    end

    def is_response?(data)
      data.has_key? 'success'
    end

  end
end
