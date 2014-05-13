require 'combi/buses/bus'
require 'combi/response_store'

module Combi
  class WebSocket < Bus

    class Server

      def initialize(bus)
        @bus = bus
        @bus.ready.succeed
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
        open_websocket
      end

      def stop!
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
          @bus.log "HANDLER #{@handler.inspect}"
          @handler.on_open if @handler.respond_to?(:on_open)
          @bus.ready.succeed
        end

        ws.on :message do |event|
          @bus.log "ON MESSAGE: #{event.data}"
          message = JSON.parse(event.data)
          @bus.on_message(ws, message)
        end

        ws.on :close do |event|
          @bus.log  "close #{event.code}: #{event.reason}"
          @handler.on_close if @handler.respond_to?(:on_close)
          @ws = ws = nil
        end

        ws.on :error do |event|
          @bus.log  "received error: #{event.inspect}"
          stop!
        end
      end

      def ws
        @bus.log "ws present: #{@ws != nil}"
        @ws
      end

    end

    attr_reader :handlers, :ready

    def initialize(options)
      super
      @handlers = {}
    end

    def post_initialize
      @ready = EventMachine::DefaultDeferrable.new
      @response_store = Combi::ResponseStore.new
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

    def on_message(ws, message, session = nil)
      if message['correlation_id'] && message.has_key?('result')
        @response_store.handle_rpc_response(message)
        log "Stored message with correlation_id #{message['correlation_id']} - #{message.inspect}"
        return
      end
      service_name = message['service']
      kind = message['kind']
      payload = message['payload'] || {}
      payload['session'] = session
      response = invoke_service(service_name, kind, payload)

      msg = {result: 'ok', correlation_id: message['correlation_id']}

      if response.respond_to? :succeed
        response.callback do |service_response|
          msg[:response] = service_response
          ws.send(msg.to_json)
        end
      else
        msg[:response] = response
        ws.send(msg.to_json)
      end
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

    def request(name, kind, message, options = {})
      options[:timeout] ||= RPC_DEFAULT_TIMEOUT
      msg = {
        service: name,
        kind: kind,
        payload: message
      }
      correlation_id = Combi::Correlation.generate
      msg[:correlation_id] = correlation_id
      waiter = EventedWaiter.wait_for(correlation_id, @response_store, options[:timeout])
      @ready.callback do |r|
        web_socket = @machine.ws || options[:ws]
        log "sending request #{msg.inspect}"
        web_socket.send msg.to_json
      end
      waiter
    end

  end
end
