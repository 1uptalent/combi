require 'spec_helper'

require 'combi/service_bus'
require 'combi/buses/queue'

describe 'Combi::Queue' do
  context 'can be instanitated via ServiceBus' do
    When(:bus) { Combi::ServiceBus.init_for(:queue, {init_queue: false}) }
    Then { Combi::Queue === bus }
  end

  Given(:amqp_config) do
    {
      :host      => "127.0.0.1",
      :port      => 5672,
      :user      => "admin",
      :pass      => "testpass",
      :vhost     => "/",
      :ssl       => false,
      :heartbeat => 0,
      :frame_max => 131072
    }
  end
  Given(:rabbit_server) { RabbitmqServer.instance }
  Given(:provider) { Combi::ServiceBus.init_for(:queue, { amqp_config: amqp_config } ) }
  Given(:consumer) { Combi::ServiceBus.init_for(:queue, { amqp_config: amqp_config }) }
  it_behaves_like 'standard_bus' do
    before(:all) { rabbit_server.start! }
    after(:all) { rabbit_server.stop! }
  end
end
