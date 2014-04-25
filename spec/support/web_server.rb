require 'rack'
require 'thin'

def start_web_server(http_bus, port)
  puts "starting webserver at port #{port}"
  app = lambda do |env|
    http_bus.manage_request(env)
  end
  thin = Rack::Handler.get('thin')
  EM::next_tick do
    thin.run(app, :Port => port)
  end
  puts "EM THIN STARTED"
  sleep 0.1
end
