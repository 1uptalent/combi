require 'spec_helper'

require 'combi/service_bus'
require 'combi/buses/queue'

describe 'Combi::Queue' do
  include EventedSpec::SpecHelper

  before(:all) do
    RabbitmqServer.instance.stop! if ENV['CLEAN']
    RabbitmqServer.instance.start!
  end
  after(:all) { RabbitmqServer.instance.stop! if ENV['CLEAN'] }

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
      :frame_max => 131072,
      :reconnect_period => 0.5
    }
  end
  Given(:provider) { Combi::ServiceBus.init_for(:queue, { amqp_config: amqp_config.merge(role: 'provider') } ) }
  Given(:consumer) { Combi::ServiceBus.init_for(:queue, { amqp_config: amqp_config.merge(role: 'consumer') } ) }
  Given(:prepare) do
    provider.start!
    consumer.start!
    true
  end

  it_behaves_like 'standard_bus'

  Given(:null_service) do
    Module.new do
      def actions; [:null]; end
      def do_it(params)
        "null"
      end
    end
  end

  context 'fire and forget' do
    describe 'does not send a response' do
      When(:service) { provider.add_service null_service }
      Then do
        em do
          expect(provider.queue_service).not_to receive(:respond)
          expect(service).to receive(:do_it) do
            done
            provider.stop!
            consumer.stop!
          end
          prepare
          consumer.request :null, :do_it, {}, fast: true
        end
      end
    end
  end

  context "it resist a reconnection" do
    Given!("notice") { puts "VERY UNSTABLE TEST" }
    When(:service) { provider.add_service null_service }
    Then do
      em do
        prepare
        EM::add_timer(0.1) do
          `killall ssh`
        end
        EM::add_timer(0.2) do
          RabbitmqServer.instance.start_forwarder!
        end
        EM::add_timer(2) do
          EM.synchrony do
            service_result = EM::Synchrony.sync consumer.request(:null, :do_it, {}, { timeout: 2 })
            service_result.should eq "null"
            done
            provider.stop!
            consumer.stop!
          end
        end
      end
    end
  end

end
