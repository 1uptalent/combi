require 'combi/buses/bus'
require 'combi/response_store'
require 'em-http-request'

module Combi
  class Http < Bus

    class Server

      def initialize(bus)
        @bus = bus
      end

      def on_message(request)
        path = request.path.split('/')
        message = {
          "service" => path[1],
          "kind" => path[2],
          "payload" => JSON.parse(request.body)
        }
        @bus.on_message(message)
      end

    end

    class Client

      def initialize(remote_api, handler, bus)
        @handler = handler
        @remote_api = remote_api
        @bus = bus
      end

    end

    def post_initialize
      @response_store = Combi::ResponseStore.new
      if @options[:remote_api]
        @machine = Client.new(@options[:remote_api], @options[:handler], self)
      else
        @machine = Server.new(self)
      end
    end

    def manage_request(env)
      @machine.on_message Rack::Request.new(env)
    end

    def on_message(message)
      service_name = message['service']
      handler = handlers[service_name.to_s]
      if handler
        service_instance = handler[:service_instance]
        kind = message['kind']
        if service_instance.respond_to? kind
          message['payload'] ||= {}
          begin
            response = invoke_service(service_instance, kind, message['payload'])
          rescue Exception => e
            response = {error: {message: e.message, backtrace: e.backtrace } }
          end
          {result: 'ok', response: response}
        else
          {result: 'error', response: {error: 'unknown action'}}
        end
      else
        {result: 'error', response: {error: 'unknown service'}}
      end
    end

    def respond_to(service_instance, action, options = {})
      handlers[action.to_s] = {service_instance: service_instance, options: options}
    end

    def handlers
      @handlers ||= {}
    end

    def request(name, kind, message, options = {})
      options[:timeout] ||= RPC_DEFAULT_TIMEOUT

      correlation_id = Combi::Correlation.generate
      waiter = EventedWaiter.wait_for(correlation_id, @response_store, options[:timeout])
      url = "#{@options[:remote_api]}#{name}/#{kind}"
      request_async = EventMachine::HttpRequest.new(url, connection_timeout: options[:timeout]).post(body: message.to_json)
      request_async.callback do |r|
        parsed = JSON.parse(r.response)
        waiter.succeed(parsed['response'])
      end
      request_async.errback do |x|
        waiter.fail(Timeout::Error.new)
      end
      waiter
    end

  end
end
