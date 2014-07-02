require 'spec_helper'

require 'combi/service_bus'
require 'combi/buses/in_process'

describe "in a multi bus environment" do
  include EventedSpec::SpecHelper

  Given(:boring_salutation_service) do
    Module.new do
      def actions; [:say_hello]; end
      def do_it(params); "Hello #{params[:who]}"; end
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
        defer = EventMachine::DefaultDeferrable.new
        EM.synchrony do
          service_name = params[:service_name] || :say_hello
          req = @other_client.request(service_name, :do_it, params, timeout: 0.1)
          service_result = EM::Synchrony.sync req
          if service_result.is_a? RuntimeError
            if @other_client.is_a?(Combi::Queue) && service_result.message == "Timeout::Error"
              defer.fail('other service failed')
            else
              defer.fail('unknown error')
            end
          else
            if service_result.respond_to?(:keys) && service_result[:error]
              defer.fail('other service failed')
            else
              defer.succeed(service_result*2)
            end
          end
        end
        defer
      end
    end
  end

  Given(:broken_service) do
    Module.new do
      def actions; [:say_hello_if_you_can]; end
      def do_it(params); raise "I can't talk" ; end
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
    RabbitmqServer.instance.start!
  }

  after(:all) {
    RabbitmqServer.instance.stop! if ENV['CLEAN']
  }

  Given(:options) { {timeout: 0.5} }

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
      context "#{internal} inside #{main}" do
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

        Given(:prepare) do
          service_for_main_bus
          start_internal = service_for_internal_bus
          main_bus_provider.start!
          internal_bus_provider.start! if start_internal
          send("#{main}_server")
          send("#{internal}_server")
          main_bus_consumer.start!
          internal_bus_consumer.start! if start_internal
        end

        Given(:finalize) do
          main_bus_provider.stop!
          internal_bus_provider.stop!
          main_bus_consumer.stop!
          internal_bus_consumer.stop!
        end

        context "both services are working ok" do
          Given(:service_for_main_bus) { main_bus_provider.add_service composed_service_class.new(internal_bus_consumer); true }
          Given(:service_for_internal_bus) { internal_bus_provider.add_service boring_salutation_service; true }

          Then do
            em do
              prepare
              EM.synchrony do
                service_result = EM::Synchrony.sync main_bus_consumer.request(:repeat_with_me, :do_it, params, options)
                service_result.should eq expected_result
                done
                finalize
              end
            end
          end
        end

        context "the external service raise an error" do
          Given(:service_for_main_bus) { main_bus_provider.add_service broken_service; true }
          Given(:service_for_internal_bus) { false }

          Then do
            em do
              prepare
              EM.synchrony do
                service_result = EM::Synchrony.sync main_bus_consumer.request(:say_hello_if_you_can, :do_it, params, options)
                service_result[:error][:message].should eq "I can't talk"
                done
                finalize
              end
            end
          end
        end

        context "the internal service raise an error" do
          Given(:service_for_main_bus) { main_bus_provider.add_service composed_service_class.new(internal_bus_consumer); true }
          Given(:service_for_internal_bus) { main_bus_provider.add_service broken_service; true }

          Then do
            em do
              prepare
              EM.synchrony do
                params.merge!('service_name' => 'say_hello_if_you_can')
                service_result = EM::Synchrony.sync main_bus_consumer.request(:repeat_with_me, :do_it, params, options)
                service_result[:error].should eq 'other service failed'
                done
                finalize
              end
            end
          end
        end

      end
    end
  end

end
