require 'eventmachine'

AsyncResponse = [-1, {}, []].freeze

class DeferrableBody
  include EventMachine::Deferrable

  def initialize(defer)
    @defer = defer
    @defer.callback do |service_response|
      json_response = Yajl::Encoder.encode service_response
      EM::next_tick do
        self.call [json_response]
        self.succeed
      end
    end
    @defer.errback do |service_response|
      error_response = { error: service_response }
      json_response = Yajl::Encoder.encode error_response
      EM::next_tick do
        self.call [json_response]
        self.fail
      end
    end
  end

  def each(&block)
    @body_callback = block
  end

  def call(chunks)
    chunks.each do |chunk|
      @body_callback.call chunk
    end
  end

end

def start_web_server(http_bus, port, webserver = 'thin')
  require webserver
  app = lambda do |env|
    response_message = http_bus.manage_request(env)
    env['async.callback'].call [200, {}, DeferrableBody.new(response_message)]
    AsyncResponse
  end
  Thin::Logging.silent = true if webserver == 'thin'
  rack_handler = Rack::Handler.get(webserver)
  rack_handler.run app, Port: port
  sleep 0.1
end
