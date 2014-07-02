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
          service_name: path[1],
          kind: path[2],
          payload: Yajl::Parser.parse(request.body, symbolize_keys: true)
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

    def on_message(service_name:, kind:, payload: {})
      invoke_service(service_name, kind, payload)
    end

    def request(name, kind, message, options = {})
      options[:timeout] ||= RPC_DEFAULT_TIMEOUT

      url = "#{@options[:remote_api]}#{name}/#{kind}"
      message_json = Yajl::Encoder.encode(message)
      request_async = EventMachine::HttpRequest.new(url, connection_timeout: options[:timeout]).post(body: message_json)
      if options[:fast]
        waiter = nil
      else
        correlation_id = Combi::Correlation.generate
        waiter = @response_store.wait_for(correlation_id, options[:timeout])
        request_async.callback do |r|
          parsed = Yajl::Parser.parse(r.response, symbolize_keys: true)
          waiter.succeed(parsed)
        end
        request_async.errback do |x|
          waiter.fail(Timeout::Error.new)
        end
      end
      waiter
    end

  end
end
