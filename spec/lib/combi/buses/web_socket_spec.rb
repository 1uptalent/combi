require 'spec_helper'

require 'combi/service_bus'
require 'combi/buses/web_socket'

describe 'Combi::WebSocket' do
  context 'can be instanitated via ServiceBus' do
    When(:bus) { Combi::ServiceBus.init_for(:web_socket, {}) }
    Then { Combi::WebSocket === bus }
  end
end
