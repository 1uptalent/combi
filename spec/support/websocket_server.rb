
def start_websocket_server(websocket_bus)
  require 'em-websocket'

  handler = Class.new do
    def new_session(arg); end
  end.new

  pid = fork do
    EM.error_handler do |error|
      puts "\tERROR"
      puts "\t#{error.inspect}"
      puts error.backtrace
    end
    EM::WebSocket.start(host: '0.0.0.0', port: 9292) do |ws|
      websocket_bus.manage_ws_event(ws, handler)
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
