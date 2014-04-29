require 'spec_helper'

require 'combi/service_bus'
require 'combi/buses/queue'

describe 'Combi::Queue' do
  include EventedSpec::SpecHelper

  context 'can be instanitated via ServiceBus' do
    When(:bus) { Combi::ServiceBus.init_for(:queue, {init_queue: false}) }
    Then { Combi::Queue === bus }
  end

  Given(:amqp_config) do
    {
      :host      => "127.0.0.1",
      :port      => RabbitmqServer.instance.port,
      :user      => "admin",
      :pass      => RabbitmqServer::PASSWORD,
      :vhost     => "/",
      :ssl       => false,
      :heartbeat => 0,
      :frame_max => 131072
    }
  end
  Given(:provider) { Combi::ServiceBus.init_for(:queue, { amqp_config: amqp_config } ) }
  Given(:consumer) { Combi::ServiceBus.init_for(:queue, { amqp_config: amqp_config } ) }
  Given(:prepare) do
    provider.start!
    consumer.start!
    true
  end

  it_behaves_like 'standard_bus' do
    before(:all) do
      RabbitmqServer.instance.stop! if ENV['CLEAN']
      RabbitmqServer.instance.start!
    end
    after(:all) { RabbitmqServer.instance.stop! if ENV['CLEAN'] }
  end
end
