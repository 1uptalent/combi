require 'em-websocket'

def start_websocket_server(websocket_bus)
  ws_handler = Class.new do
    def new_session(arg); end
  end.new

  pid = fork do
    EM.error_handler do |error|
      puts "\tERROR"
      puts "\t#{error.inspect}"
      puts error.backtrace
    end
    EM::WebSocket.start(host: '0.0.0.0', port: 9292) do |ws|
      websocket_bus.manage_ws_event(ws, ws_handler)
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

def start_em_websocket_server(websocket_bus, port)
  puts "starting webserver with #{websocket_bus.inspect}"
  ws_handler = Class.new do
    def new_session(arg); end
  end.new
  EM::WebSocket.run(host: '0.0.0.0', port: port) do |ws|
    websocket_bus.manage_ws_event(ws, ws_handler)
  end
  puts "EM WEBSOCKET STARTED"
  sleep 1
end
