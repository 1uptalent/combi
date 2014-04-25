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
      :port      => RabbitmqServer.instance.port,
      :user      => "admin",
      :pass      => RabbitmqServer::PASSWORD,
      :vhost     => "/",
      :ssl       => false,
      :heartbeat => 0,
      :frame_max => 131072
    }
  end
  it_behaves_like 'standard_bus' do
    before(:all) do
      RabbitmqServer.instance.stop! if ENV['CLEAN']
      if RabbitmqServer.instance.start!
        puts "Giving time to rabbitmq"
        sleep 1
      end
    end
    after(:all) { RabbitmqServer.instance.stop! if ENV['CLEAN'] }
    before(:each) { start_background_reactor }

    Given(:provider) { Combi::ServiceBus.init_for(:queue, { amqp_config: amqp_config } ) }
    Given(:consumer) { Combi::ServiceBus.init_for(:queue, { amqp_config: amqp_config } ) }
    Given!("consumer started") do
      provider_started ; puts("provider started")
      consumer_started ; puts("consumer started")
    end
    after(:each)  { provider.stop! }
    after(:each)  { consumer.stop! }
    after(:each)  { stop_background_reactor }
  end
end
