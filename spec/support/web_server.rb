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
  puts "starting web server '#{webserver}' at port #{port}"
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
  rack_handler = Rack::Handler.get(webserver)
  rack_handler.run app, Port: port
  puts "EM WEB STARTED"
  sleep 0.1
end
