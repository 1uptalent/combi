require 'combi/buses/bus'
require "em-synchrony"

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
        end
      end

      def ws
        @bus.log "ws present: #{@ws != nil}"
        @ws
      end

    end

    attr_reader :handlers

    def initialize(options)
      super
      @handlers = {}
    end

    def post_initialize
      # @rpc_responses = {}
      # @rpc_callbacks = {}
      @response_store = ResponseStore.new
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
        puts "on message for #{message['correlation_id']}"
        @response_store.handle_rpc_response(message)
        log "Stored message with correlation_id #{message['correlation_id']} - #{message.inspect}"
        return
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
      result = nil
      Fiber.new do
        waiter = request_async(name, kind, message, options)
        puts "WAITER => "
        puts waiter.inspect
        result, exception = EM.synchrony.sync waiter
        if exception
          puts "exc"
          raise exception
        else
          puts "RESULT!!!!"
          puts result.inspect
          result
        end
        puts "after wait"
      end.resume
      puts "fiber done!"
    end

    def request_async(name, kind, message, options = {}, &block)
      options[:timeout] ||= RPC_DEFAULT_TIMEOUT
      msg = {
        service: name,
        kind: kind,
        payload: message
      }
      correlation_id = rand(10_000_000).to_s
      msg[:correlation_id] = correlation_id
      web_socket = @machine.ws || options[:ws]
      raise "Websocket is nil" unless web_socket
      log "sending request #{msg.inspect}"
      web_socket.send msg.to_json
      puts "SENT to server"
      if block.nil?
        puts "THIS!!"
        return EventedWaiter.wait_for(correlation_id, @response_store, options[:timeout])
      else
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


    class ResponseStore
      def initialize()
        @responses = {}
        @waiters = {}
      end

      def add_waiter(key, waiter)
        @waiters[key] = waiter
      end

      def handle_rpc_response(response)
        puts response
        puts "^"*40
        @waiters[response['correlation_id']].succeed(response['response'])
        # store response['correlation_id'],
        #       { 'response' => response,
        #         'metadata' => 'from_web_socket' }
      end

      # def store(key, value)
      #   @responses[key] = value
      # end

      # def poll(key)
      #   @responses[key]
      # end
    end

    class EventedWaiter
      include EM::Deferrable

      def self.wait_for(key, response_store, timeout, &block)
        puts "waiting for... #{key}"
        waiter = new(key, response_store, timeout, Combi::Bus::RPC_MAX_POLLS, block)
        response_store.add_waiter(key, waiter)
        f = Fiber.current
        waiter.callback{ |r| f.resume(waiter) }
        waiter.errback{|*errors| f.resume(*errors)}
        Fiber.yield
      end

      def initialize(key, response_store, timeout, max_polls, block)
        #@key = key
        #@response_store = response_store
        #@timeout = timeout
        self.timeout(timeout)
        #self.callback(&block)
        #@max_polls = max_polls
        #@block = block
        #@poll_delay = timeout.fdiv Combi::Bus::RPC_MAX_POLLS
        #@elapsed = 0.0
      end

      # def evented_wait
      #   @elapsed += @poll_delay
      #   value = @response_store.poll(@key)
      #   if value.nil? && @elapsed < @timeout
      #     puts "."
      #     EM.add_timer @poll_delay, &method(:evented_wait)
      #   elsif @elapsed < @timeout
      #     puts "returning value..."
      #     puts value
      #     succeed value
      #   else
      #     # timeout
      #   end
      # end
    end


  end
end
