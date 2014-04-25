require 'spec_helper'

require 'combi/service_bus'
require 'combi/buses/http'

describe 'Combi::Http' do
  context 'can be instantiated via ServiceBus' do
    When(:bus) { Combi::ServiceBus.init_for(:http, {}) }
    Then { Combi::Http === bus }
  end
  Given(:client_options) do
    { remote_api: 'http://localhost:9292/' }
  end
  Given(:http_server) { Combi::ServiceBus.init_for(:http, {} )}
  Given(:subject) { Combi::ServiceBus.init_for(:http, client_options) }

  it_behaves_like 'standard_bus' do
    Given(:provider) { http_server }
    Given(:consumer) { subject }
    Given(:webserver) do
      puts "Running webserver with #{service.map(&:actions).join ','} registered"
      start_web_server http_server
    end
    Given!("consumer started") do
      webserver && provider_started && consumer_started
    end
    after :each do
      stop_web_server(webserver)
    end
  end

end
