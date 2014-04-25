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
  Given(:socket_client_options) do
    { remote_api: 'ws://localhost:9292/',
      handler: handler }
  end

  Given(:http_client_options) do
    { remote_api: 'http://localhost:9292/' }
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

  Given!(:buses_are_started) {
    Thread.new { internal_bus_provider.start! }
    Thread.new { internal_bus_consumer.start! }
    Thread.new { main_bus_consumer.start! }
    Thread.new { main_bus_provider.start! }
    sleep 0.1
    true
  }

  Given(:options) { {timeout: 5} }

  Given(:composed_result) {
    service_result = nil
    main_bus_consumer.request(:repeat_with_me, :do_it, params, options) do |result|
      service_result = result
    end
    service_result
  }

  When(:service_in_process) { main_bus_provider.add_service composed_service_class.new(internal_bus_consumer) }
  When(:service_in_queue)   { internal_bus_provider.add_service boring_salutation_service }
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

  BUSES = %w{in_process http queue socket}

  BUSES.each do |main|
    BUSES.each do |internal|
      context "#{internal} inside #{main}" do

        Given(:main_bus_provider)     { send "#{main}_provider" }
        Given(:main_bus_consumer)     { send "#{main}_consumer" }
        Given(:internal_bus_provider) { send "#{internal}_provider" }
        Given(:internal_bus_consumer) { send "#{internal}_consumer" }

        Then do
          composed_result.should eq expected_result
        end

      end
    end
  end

end
