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
  Given(:client_options) do
    { remote_api: 'ws://localhost:9292/',
      handler: handler }
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
  Given(:queue_provider)      { Combi::ServiceBus.init_for(:queue, { amqp_config: amqp_config } ) }
  Given(:queue_consumer)      { Combi::ServiceBus.init_for(:queue, { amqp_config: amqp_config } ) }
  Given(:socket_provider)     { Combi::ServiceBus.init_for(:web_socket, {} ) }
  Given(:socket_consumer)     { Combi::ServiceBus.init_for(:web_socket, client_options) }

  context "queue inside in process" do

    Given(:main_bus_provider)     { in_process_provider }
    Given(:main_bus_consumer)     { in_process_consumer }
    Given(:internal_bus_provider) { queue_provider }
    Given(:internal_bus_consumer) { queue_consumer }

    Then do
      composed_result.should eq expected_result
    end

  end

  context "in process inside queue" do

    Given(:main_bus_provider)     { queue_provider }
    Given(:main_bus_consumer)     { queue_consumer }
    Given(:internal_bus_provider) { in_process_provider }
    Given(:internal_bus_consumer) { in_process_provider }

    Then do
      composed_result.should eq expected_result
    end

  end

  context "socket inside queue" do

    Given(:main_bus_provider)     { queue_provider }
    Given(:main_bus_consumer)     { queue_consumer }
    Given(:internal_bus_provider) { socket_provider }
    Given(:internal_bus_consumer) { socket_consumer }

    Then do
      composed_result.should eq expected_result
    end

  end

  context "queue inside socket" do

    Given(:main_bus_provider)     { socket_provider }
    Given(:main_bus_consumer)     { socket_consumer }
    Given(:internal_bus_provider) { queue_provider }
    Given(:internal_bus_consumer) { queue_consumer }

    Then do
      composed_result.should eq expected_result
    end

  end

  context "in process inside socket" do

    Given(:main_bus_provider)     { socket_provider }
    Given(:main_bus_consumer)     { socket_consumer }
    Given(:internal_bus_provider) { in_process_provider }
    Given(:internal_bus_consumer) { in_process_provider }

    Then do
      composed_result.should eq expected_result
    end

  end

  context "socket inside in process" do

    Given(:main_bus_provider)     { in_process_provider }
    Given(:main_bus_consumer)     { in_process_consumer }
    Given(:internal_bus_provider) { socket_provider }
    Given(:internal_bus_consumer) { socket_consumer }

    Then do
      composed_result.should eq expected_result
    end

  end



end
