module Combi
  class WebSocket < Bus

    class Server

      def initialize(bus)
        @bus = bus
      end

      def start!
      end

      def stop!
      end

      def manage_request(env, handler)
        return unless Faye::WebSocket.websocket?(env)
        ws = Faye::WebSocket.new(env)
        session = nil

        ws.on :message do |event|
          message = JSON.parse(event.data)
          @bus.on_message(ws, message, session)
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

      def ws
      end

    end

    class Client

      def initialize(remote_api, handler, bus)
        @handler = handler
        @remote_api = remote_api
        @bus = bus
      end

      def start!
        @stop_requested = false
        reset_back_off_delay!
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
            @bus.on_message(@ws, message)
          end

          @ws.on :close do |event|
            puts "close client web socket"
            @ws = nil
            EM::stop_event_loop
          end
        end
      end

      def ws
        @ws
      end

      protected

      def stop_requested?
        @stop_requested
      end

      def reset_back_off_delay!
        @back_off_delay = 1
      end

      def back_off!
        sleep @back_off_delay
        @back_off_delay = [@back_off_delay * 2, 300].min
      end

    end

    RPC_DEFAULT_TIMEOUT = 1
    RPC_WAIT_PERIOD = 0.1

    def post_initialize
      require 'faye/websocket'
      @rpc_responses = {}
      if @options[:remote_api]
        require 'eventmachine'
        @machine = Client.new(@options[:remote_api], @options[:handler], self)
      else
        @machine = Server.new(self)
      end
    end

    def start!
      @machine.start!
    end

    def stop!
      @machine.stop!
    end

    def manage_request(env, handler)
      @machine.manage_request(env, handler)
    end

    def on_message(ws, message, session = nil)
      if message['correlation_id']
        @rpc_responses[message['correlation_id']] = [message]
      end
      service_name = message['service']
      handler = handlers[service_name.to_s]
      if handler
        service_instance = handler[:service_instance]
        kind = message['kind']
        if service_instance.respond_to? kind
          message['payload'] ||= {}
          message['payload']['session'] = session
          response = service_instance.send(kind, message['payload'])
          unless response.nil?
            msg = if session
              {success: true, status: 200, message: 'ok'}
            else
              message
            end
            msg[:result] = response
            ws.send msg.to_json
          end
        end
      end
    end

    def respond_to(service_instance, handler, options = {})
      handlers[handler.to_s] = {service_instance: service_instance, options: options}
    end

    def handlers
      @handlers ||= {}
    end

    def request(name, kind, message, options = {}, &block)
      options[:timeout] ||= RPC_DEFAULT_TIMEOUT
      msg = {
        service: name,
        kind: kind,
        payload: message
      }
      unless block.nil?
        correlation_id = rand(10_000_000).to_s
        msg[:correlation_id] = correlation_id unless block.nil?
      end
      web_socket = @machine.ws || options[:ws]
      Thread.new do
        begin
          web_socket.send msg.to_json
        rescue => e
          puts e.message
          puts e.backtrace
          retry
        end
      end
      return if block.nil?
      elapsed = 0
      args = @rpc_responses[correlation_id]
      while(args.nil? && elapsed < options[:timeout]) do
        sleep(RPC_WAIT_PERIOD)
        elapsed += RPC_WAIT_PERIOD
        args = @rpc_responses[correlation_id]
      end
      args ||= [nil, {error: 'timeout'}]
      block.call(*args) unless block.nil?
    end

  end
end
