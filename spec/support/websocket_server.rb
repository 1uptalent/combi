require 'em-websocket'

def start_em_websocket_server(websocket_bus, port)
  puts "starting webserver at port #{port} with #{websocket_bus.inspect}"
  ws_handler = Class.new do
    def new_session(arg); end
  end.new
  EM::WebSocket.run(host: '0.0.0.0', port: port) do |ws|
    websocket_bus.manage_ws_event(ws, ws_handler)
  end
  puts "EM WEBSOCKET STARTED"
  sleep 1
end
