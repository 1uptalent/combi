require 'spec_helper'

require 'combi/service_bus'
require 'combi/buses/http'

describe 'Combi::Http' do
  include EventedSpec::SpecHelper

  context 'can be instantiated via ServiceBus' do
    When(:bus) { Combi::ServiceBus.init_for(:http, {}) }
    Then { Combi::Http === bus }
  end
  Given(:server_port) { 9292 + rand(30000) }
  Given(:client_options) { { remote_api: "http://localhost:#{server_port}/" } }
  Given(:provider) { Combi::ServiceBus.init_for(:http, {} ) }
  Given(:consumer) { Combi::ServiceBus.init_for(:http, client_options) }
  Given(:prepare) do
    provider.start!
    start_web_server provider, server_port
    consumer.start!
  end

  it_behaves_like 'standard_bus'

end
