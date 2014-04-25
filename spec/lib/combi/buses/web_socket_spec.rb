require 'spec_helper'

require 'combi/service_bus'
require 'combi/buses/web_socket'

describe 'Combi::WebSocket' do
  context 'can be instanitated via ServiceBus' do
    When(:bus) { Combi::ServiceBus.init_for(:web_socket, {}) }
    Then { Combi::WebSocket === bus }
  end
  Given(:handler) do
    Class.new do
      def on_open; end
    end.new
  end
  # Workaround to random errors because the port is in use
  # My guess (amuino): Tests are too fast/closing the servers is slow
  Given(:server_port) { 9292 + rand(30000) }
  Given(:client_options) do
    { remote_api: "ws://localhost:#{server_port}/",
      handler: handler }
  end
  Given(:provider) { Combi::ServiceBus.init_for(:web_socket, {} )}
  Given(:consumer) { Combi::ServiceBus.init_for(:web_socket, client_options) }

  it_behaves_like 'standard_bus' do
    before(:each) do
      puts "------- before :each, the reactor is running: #{EM::reactor_running?}"
      puts "------- before :each : starting EM reactor"
      EM::error_handler do |error|
        STDERR << "ERROR IN EM\n"
        STDERR << "\t#{error.inspect}"
        STDERR << error.backtrace << "\n"
      end
      sleep 0.1 if EM::reactor_running? # wait one quantum
      raise "EM did not shut down" if EM::reactor_running?
      Thread.new { EM::run; puts "EM STOPPED" }
    end
    Given(:webserver) { start_em_websocket_server provider, server_port }

    Given!("consumer started") do
      provider_started && webserver && consumer_started
    end

    after(:each) do
      consumer.stop!
      puts "------- after :each, the reactor is running: #{EM::reactor_running?}"
      EM::stop_event_loop if EM::reactor_running?
    end

  end

end
