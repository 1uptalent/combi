
def start_websocket_server(websocket_bus)
  require 'eventmachine'
  require 'rack'
  require 'thin'

  Faye::WebSocket.load_adapter('thin')

  handler = Class.new do
    def new_session(arg); end
  end.new

  app = lambda do |env|
    if websocket_bus.manage_request(env, handler)
    else
      raise "HTTP not allowed"
    end
  end

  pid = fork do
    EM.error_handler do |error|
      puts "\tERROR"
      puts "\t#{error.inspect}"
      puts error.backtrace
    end
    EM.run do
      thin = Rack::Handler.get('thin')
      thin.run(app, :Port => 9292)
    end
    puts "Websocket server stopped"
  end
  puts "Started websocket server with pid: #{pid}"
  pid
end

def stop_websocket_server(pid)
  puts "Stopping websocket server with pid: #{pid}"
  Process.kill "KILL", pid
end
