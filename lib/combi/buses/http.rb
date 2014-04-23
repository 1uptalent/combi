require 'combi/buses/bus'
require "net/http"
require "uri"

module Combi
  class Http < Bus

    class Server

      def initialize(bus)
        @bus = bus
      end

      def start!
      end

      def stop!
      end

      def on_message(request)
        path = request.path.split('/')
        message = {
          "service" => path[1],
          "kind" => path[2],
          "payload" => JSON.parse(request.params['message'])
        }
        response_message = @bus.on_message(message)
        response = Rack::Response.new
        response.status = response_message.nil? ? 201 : 200
        response.body = [response_message.to_json]
        response.finish
      end

    end

    class Client

      def initialize(remote_api, handler, bus)
        @handler = handler
        @remote_api = remote_api
        @bus = bus
      end

      def start!
      end

      def stop!
      end

      def restart!
        stop!
        start!
      end

    end

    def post_initialize
      @rpc_responses = {}
      if @options[:remote_api]
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

    def manage_request(env)
      @machine.on_message Rack::Request.new(env)
    end

    def on_message(message)
      if message['correlation_id']
        @rpc_responses[message['correlation_id']] = message
      end
      service_name = message['service']
      handler = handlers[service_name.to_s]
      if handler
        service_instance = handler[:service_instance]
        kind = message['kind']
        if service_instance.respond_to? kind
          message['payload'] ||= {}
          response = service_instance.send(kind, message['payload'])
          {result: 'ok', correlation_id: message['correlation_id'], response: response}
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
        message: message.to_json
      }
      unless block.nil?
        correlation_id = rand(10_000_000).to_s
        msg[:correlation_id] = correlation_id
      end
      raise "Server is not specified" unless @options[:remote_api]
      server_address = "#{@options[:remote_api]}#{name}/#{kind}"
      uri = URI.parse(server_address)
      http = Net::HTTP.new(uri.host, uri.port)
      request = Net::HTTP::Post.new(uri.request_uri)
      request.set_form_data(msg)
      Timeout.timeout(options[:timeout]) do
        response = http.request(request)
        if block && response.code == "200"
          block.call JSON.parse(response.body)['response']
        end
      end

    end

  end
end
