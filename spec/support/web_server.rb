require 'eventmachine'

AsyncResponse = [-1, {}, []].freeze

class DeferrableBody
  include EventMachine::Deferrable

  def initialize(defer)
    @defer = defer
    @defer.callback do |service_response|
      EM::next_tick do
        self.call [{result: 'ok', response: service_response}.to_json]
        self.succeed
      end
    end
    @defer.errback do |service_response|
      error_response = { error: service_response }
      EM::next_tick do
        self.call [{result: 'ok', response: error_response}.to_json]
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
    if response_message[:response].respond_to? :succeed
      env['async.callback'].call [200, {}, DeferrableBody.new(response_message[:response])]
      AsyncResponse
    else
      response_rack = Rack::Response.new
      response_rack.status = response_message.nil? ? 201 : 200
      response_rack.body = [response_message.to_json]
      response_rack.finish
      response_rack
    end
  end
  Thin::Logging.silent = true if webserver == 'thin'
  rack_handler = Rack::Handler.get(webserver)
  rack_handler.run app, Port: port
  sleep 0.1
end
