require 'spec_helper'

require 'combi/service_bus'
require 'combi/buses/web_socket'

describe 'Combi::WebSocket' do
  include EventedSpec::SpecHelper

  context 'can be instanitated via ServiceBus' do
    When(:bus) { Combi::ServiceBus.init_for(:web_socket, {}) }
    Then { Combi::WebSocket === bus }
  end
  Given(:handler) do
    Class.new do
      def on_open; end
    end.new
  end

  Given(:server_port) { 9292 + rand(30000) }
  Given(:client_options) do
    { remote_api: "ws://localhost:#{server_port}/",
      handler: handler }
  end
  Given(:provider) { Combi::ServiceBus.init_for(:web_socket, {} )}
  Given(:consumer) { Combi::ServiceBus.init_for(:web_socket, client_options) }
  Given(:prepare) do
    provider.start!
    start_em_websocket_server provider, server_port
    consumer.start!
  end

  it_behaves_like 'standard_bus'

end
