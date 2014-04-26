def start_web_server(http_bus, port, webserver = 'thin')
  require webserver
  puts "starting web server '#{webserver}' at port #{port}"
  app = lambda do |env|
    http_bus.manage_request(env)
  end
  rack_handler = Rack::Handler.get(webserver)
  EM::next_tick do
    rack_handler.run app, Port: port
  end
  puts "EM WEB STARTED"
  sleep 0.1
end
