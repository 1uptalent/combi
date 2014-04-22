require 'spec_helper'

require 'combi/service_bus'
require 'combi/buses/web_socket'

describe 'Combi::WebSocket' do
  context 'can be instanitated via ServiceBus' do
    When(:bus) { Combi::ServiceBus.init_for(:web_socket, {}) }
    Then { Combi::WebSocket === bus }
  end
  Given(:handler) { double('handler', on_open: nil) }
  Given(:client_options) do
    { remote_api: 'ws://localhost:9292/',
      handler: handler }
  end
  Given(:ws_server) { Combi::ServiceBus.init_for(:web_socket, {} )}
  Given(:subject) { Combi::ServiceBus.init_for(:web_socket, client_options) }
  Given!("webserver is running") do
    # TODO: poll the server
    sleep 1
  end

  it_behaves_like 'standard_bus' do
    Given(:provider) { ws_server }
    Given(:consumer) { subject }
    Given(:webserver) do
      puts "Running webserver with #{service.map(&:actions).join ','} registered"
      start_websocket_server ws_server
    end
    Given!("consumer started") do
      webserver && provider_started && sleep(1) && consumer_started
    end
    after :each do
      stop_websocket_server(webserver)
    end
  end

end
