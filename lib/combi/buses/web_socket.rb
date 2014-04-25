require 'combi/buses/bus'

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

      def on_open(ws, handler)
        @bus.log "ON OPEN #{handler.inspect}"
        handler.new_session(ws)
      end

      def on_message(ws, session, raw_message)
        @bus.log "ON MESSAGE #{raw_message}"
        message = JSON.parse(raw_message)
        @bus.on_message(ws, message, session)
      end

      def on_close(session)
        session && session.close
      end

      def ws
        @ws
      end

    end

    class Client
      require 'faye/websocket'

      def initialize(remote_api, handler, bus)
        @handler = handler
        @remote_api = remote_api
        @bus = bus
      end

      def start!
        @stop_requested = false
        reset_back_off_delay!
        open_websocket
      end

      def stop!
        @stop_requested = true
        @ws && @ws.close
        @bus.log "stop requested"
      end

      def restart!
        stop!
        start!
      end

      def open_websocket
        @bus.log  @remote_api
        @ws = ws = Faye::WebSocket::Client.new(@remote_api)
        ws.on :open do |event|
          @bus.log "OPEN"
          reset_back_off_delay!
          @bus.log "HANDLER #{@handler.inspect}"
          @handler.on_open
        end

        ws.on :message do |event|
          @bus.log "ON MESSAGE: #{event.data}"
          message = JSON.parse(event.data)
          @bus.on_message(ws, message)
        end

        ws.on :close do |event|
          @bus.log  "close #{event.code}: #{event.reason}"
          @ws = ws = nil
        end

        ws.on :error do |event|
          @bus.log  "received error: #{event.inspect}"
          stop!
          back_off!
        end
      end

      def ws
        @bus.log "ws present: #{@ws != nil}"
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
        puts "Backing off for #{@back_off_delay} seconds"
        EM::add_timer @back_off_delay do
          @back_off_delay = [@back_off_delay * 2, 300].min
          open_websocket
        end
      end

    end

    attr_reader :handlers

    def initialize(options)
      super
      @handlers = {}
    end

    def post_initialize
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
      require 'faye/websocket'

      return unless Faye::WebSocket.websocket?(env)
      @ws = ws = Faye::WebSocket.new(env)
      session = nil

      ws.on :message do |event|
        @machine.on_message(ws, session, event.data)
      end

      ws.on :open do |event|
        session = @machine.on_open(ws, handler)
      end

      ws.on :close do |event|
        @machine.on_close(session)
      end
      # Return async Rack response
      ws.rack_response
    end

    def manage_ws_event(ws, handler)
      session = nil

      ws.onmessage do |raw_message|
        @machine.on_message(ws, session, raw_message)
      end

      ws.onopen do |handshake|
        session = @machine.on_open(ws, handler)
      end

      ws.onclose do
        @machine.on_close(session)
      end
    end

    def log(message)
      puts "#{object_id} #{@machine.class.name} #{message}"
    end

    def on_message(ws, message, session = nil)
      if message['correlation_id'] && message.has_key?('result')
        @rpc_responses[message['correlation_id']] = message
        log "Stored message with correlation_id #{message['correlation_id']} - #{message.inspect}"
      end
      service_name = message['service']
      kind = message['kind']
      payload = message['payload'] || {}
      payload['session'] = session
      response = invoke_service(service_name, kind, payload)
      ws.send({result: 'ok',
               correlation_id: message['correlation_id'],
               response: response}.to_json) if response != nil
    end

    def invoke_service(service_name, kind, payload)
      handler = handlers[service_name.to_s]
      if handler
        service_instance = handler[:service_instance]
        if service_instance.respond_to? kind
          response = service_instance.send(kind, payload)
        else
          log "[WARNING] Service #{service_name}(#{service_instance.class.name}) does not respond to message #{kind}"
        end
      else
        log "[WARNING] Service #{service_name} not found"
        log "[WARNING] handlers: #{handlers.keys.inspect}"
      end
    end

    def respond_to(service_instance, handler, options = {})
      log "registering #{handler}"
      handlers[handler.to_s] = {service_instance: service_instance, options: options}
      log "handlers: #{handlers.keys.inspect}"
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
        msg[:correlation_id] = correlation_id
      end
      web_socket = @machine.ws || options[:ws]
      raise "Websocket is nil" unless web_socket
      log "sending request #{msg.inspect}"
      web_socket.send msg.to_json
      return if block.nil?
      elapsed = 0
      raw_response = @rpc_responses[correlation_id]
      poll_time = options[:timeout].fdiv RPC_MAX_POLLS
      while(raw_response.nil? && elapsed < options[:timeout]) do
        sleep(poll_time)
        elapsed += poll_time
        raw_response = @rpc_responses[correlation_id]
      end
      if raw_response == nil && elapsed >= options[:timeout]
        raise Timeout::Error
      else
        block.call(raw_response['response'])
      end
    end

  end
end
