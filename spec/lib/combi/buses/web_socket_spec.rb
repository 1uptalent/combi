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
      attr_reader :status
      def on_open
        @status = 'open'
      end
      def on_close
        @status = 'close'
      end
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
          expect(provider).not_to receive(:send_response)
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

  context 'it notify when the connection is opened' do
    Then do
      em do
        provider.start!
        start_em_websocket_server provider, server_port
        consumer.start!
        EM::add_timer(0.1) do
          handler.status.should eq 'open'
          done
          provider.stop!
          consumer.stop!
        end
      end
    end
  end

  context 'it notify when the connection is closed' do
    Then do
      em do
        provider.start!
        start_em_websocket_server provider, server_port
        consumer.start!
        EM::add_timer(0.1) do
          provider.stop!
          consumer.stop!
        end
        EM::add_timer(0.3) do
          handler.status.should eq 'close'
          done
        end
      end
    end
  end

  context "it don't send messages when is not connected" do
    Then do
      em do
        provider.add_service null_service
        prepare
        EM::add_timer(0.1) do
          consumer.stop!
        end
        EM::add_timer(0.2) do
          EM.synchrony do
            provider.stop!
            service_result = EM::Synchrony.sync consumer.request(:null, :do_it, {}, { timeout: 0.3 })
            service_result.should be_a Hash
            service_result.should have_key :error
            service_result[:error].should eq 'Timeout::Error'
            done(0.3) #timeout response must came before this timeout
          end
          provider.stop!
          consumer.stop!
        end
      end
    end
  end

end
