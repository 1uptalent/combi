require 'em-websocket'

def start_em_websocket_server(websocket_bus, port)
  ws_handler = Class.new do
    def new_session(arg); end
  end.new
  EM::WebSocket.start(host: '0.0.0.0', port: port) do |ws|
    websocket_bus.manage_ws_event(ws, ws_handler)
  end
  sleep 0.1
end
