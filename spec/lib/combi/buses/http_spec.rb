require 'spec_helper'

require 'combi/service_bus'
require 'combi/buses/http'

describe 'Combi::Http' do
  context 'can be instantiated via ServiceBus' do
    When(:bus) { Combi::ServiceBus.init_for(:http, {}) }
    Then { Combi::Http === bus }
  end
  Given(:server_port) { 9292 + rand(30000) }
  Given(:client_options) { { remote_api: "http://localhost:#{server_port}/" } }
  Given(:provider) { Combi::ServiceBus.init_for(:http, {} )}
  Given(:consumer) { Combi::ServiceBus.init_for(:http, client_options) }

  it_behaves_like 'standard_bus' do
    before(:each) { start_background_reactor }

    Given(:webserver) { start_web_server provider, server_port }
    Given!("consumer started") do
      webserver && provider_started && consumer_started
    end
    after :each do
      consumer.stop!
      stop_background_reactor
    end
  end

end
