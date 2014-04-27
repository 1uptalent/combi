require 'spec_helper'

require 'combi/service_bus'
require 'combi/buses/in_process'

describe "in a multi bus environment" do

  Given(:boring_salutation_service) do
    Module.new do
      def actions; [:say_hello]; end
      def do_it(params); "Hello #{params['who']}"; end
    end
  end

  Given(:composed_service_class) do
    Class.new do
      include Combi::Service

      def initialize(other_client)
        @other_client = other_client
      end

      def actions; [:repeat_with_me]; end

      def do_it(params)
        service_result = ""
        @other_client.request(:say_hello, :do_it, params) do |result|
          service_result = result
        end
        service_result*2
      end
    end
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

  Given(:handler) { double('handler', on_open: nil) }
  Given(:server_port_socket) { 9292 + rand(30000) }
  Given(:socket_client_options) do
    { remote_api: "ws://localhost:#{server_port_socket}/",
      handler: handler }
  end
  Given(:server_port_http) { 9292 + rand(30000) }
  Given(:http_client_options) do
    { remote_api: "http://localhost:#{server_port_http}/" }
  end

  before(:all) {
    RabbitmqServer.instance.stop! if ENV['CLEAN']
    if RabbitmqServer.instance.start!
      puts "Giving time to rabbitmq"
      sleep 1
    end
  }

  after(:all) {
    RabbitmqServer.instance.stop! if ENV['CLEAN']
  }

  Given(:options) { {timeout: 5} }

  Given(:composed_result) {
    service_result = nil
    main_bus_consumer.request(:repeat_with_me, :do_it, params, options) do |result|
      service_result = result
    end
    service_result
  }

  Given(:service_for_main_bus) { main_bus_provider.add_service composed_service_class.new(internal_bus_consumer) }
  Given(:service_for_internal_bus)   { internal_bus_provider.add_service boring_salutation_service }
  When(:params) { { who: 'world' } }
  When(:expected_result) { "Hello worldHello world" }

  Given(:in_process_provider) { Combi::ServiceBus.init_for(:in_process, {}) }
  Given(:in_process_consumer) { in_process_provider }
  Given(:http_provider)       { Combi::ServiceBus.init_for(:http, {} ) }
  Given(:http_consumer)       { Combi::ServiceBus.init_for(:http, http_client_options) }
  Given(:queue_provider)      { Combi::ServiceBus.init_for(:queue, { amqp_config: amqp_config } ) }
  Given(:queue_consumer)      { Combi::ServiceBus.init_for(:queue, { amqp_config: amqp_config } ) }
  Given(:socket_provider)     { Combi::ServiceBus.init_for(:web_socket, {} ) }
  Given(:socket_consumer)     { Combi::ServiceBus.init_for(:web_socket, socket_client_options) }

  BUSES = %w{in_process socket http queue}

  BUSES.each do |main|
    BUSES.each do |internal|
      if main != internal
        context "#{internal} inside #{main}" do
          before(:all) do
            if RabbitmqServer.instance.start!
              puts "Giving time to rabbitmq"
              sleep 1
            end
          end
          before(:each) do
            start_background_reactor
            main_bus_provider.start!
            internal_bus_provider.start!
            main_bus_consumer.start!
            internal_bus_consumer.start!
          end

          Given(:main_bus_provider)     { send "#{main}_provider" }
          Given(:main_bus_consumer)     { send "#{main}_consumer" }
          Given(:internal_bus_provider) { send "#{internal}_provider" }
          Given(:internal_bus_consumer) { send "#{internal}_consumer" }

          Given("#{main}_server".to_sym) do
            if main == 'http'
              start_web_server main_bus_provider, server_port_http
            end
            if main == 'socket'
              start_em_websocket_server main_bus_provider, server_port_socket
            end
          end
          Given("#{internal}_server".to_sym) do
            if internal == 'http'
              start_web_server internal_bus_provider, server_port_http
            end
            if internal == 'socket'
              start_em_websocket_server internal_bus_provider, server_port_socket
            end
          end
          Given!("buses started") do
            service_for_main_bus
            service_for_internal_bus
            send("#{main}_server")
            send("#{internal}_server")
            true
          end

          Then do
            puts "#{internal} inside #{main}"
            composed_result.should eq expected_result
          end

          after :each do
            main_bus_consumer.stop!
            internal_bus_consumer.stop!
            main_bus_provider.stop!
            internal_bus_provider.stop!
            stop_background_reactor
          end

        end
      end
    end
  end

end
