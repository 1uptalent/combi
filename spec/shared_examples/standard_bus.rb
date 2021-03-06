require "em-synchrony"

shared_examples_for "standard_bus" do

  Given(:slow_service) do
    Module.new do
      def actions; [:sleep]; end
      def do_it(params)
        sleep params[:time]
      end
    end
  end

  Given(:boring_salutation_service) do
    Module.new do
      def actions; [:say_hello]; end
      def do_it(params)
        "Hello #{params[:who]}"
      end
    end
  end

  Given(:echo_service) do
    Module.new do
      def actions; [:echo_this]; end
      def do_it(params)
        params[:data]
      end
    end
  end

  Given(:broken_service) do
    Module.new do
      def actions; [:shout_error]; end
      def do_it(params)
        raise params[:message]
      end
    end
  end

  Given(:calculator_service) do
    Module.new do
      def actions; [:calculator]; end
      def incr(params)
        @counter += 1
      end
      def initialize
        @counter = 0
      end
      def counter
        @counter
      end
    end
  end

  Given(:finalize) do
    provider.stop!
    consumer.stop!
  end

  context 'fire and forget' do
    context 'can invoke services' do
      When(:service) { provider.add_service calculator_service }
      When(:params) { { who: 'world' } }
      When(:service_response) do
        srv_resp = "UNSET"
        em do
          prepare
          EM.synchrony do
            srv_resp = consumer.request(:calculator, :incr, {}, {fast: true})
            spec_waiter = EM::DefaultDeferrable.new
            EM.add_periodic_timer 0.1 do
              spec_waiter.succeed service.counter if service.counter == 1
            end
            EM::Synchrony.sync spec_waiter
            done
            finalize
          end
        end
        srv_resp
      end
      Then { service_response.should_not be_a EM::Deferrable }
      And { service_response.should be_nil }
      And { service.counter.should eq 1 }
    end

    context 'ignores service errors' do
      Given(:error_message) { 'service is broken' }
      When(:service) { provider.add_service broken_service }
      Then do
        em do
          prepare
          EM.synchrony do
            service_result = consumer.request(:shout_error, :do_it, {message: error_message}, { fast: true })
            service_result.should be_nil
            done
            finalize
          end
        end
      end
    end

    context 'ignores unknown services' do
      Then do
        em do
          prepare
          EM.synchrony do
            service_result = consumer.request(:mssing_service, :do_it, {}, { fast: true })
            service_result.should be_nil
            done
            finalize
          end
        end
      end
    end
  end

  context 'ignores service errors' do
      When(:service) { provider.add_service boring_salutation_service }
      Then do
        em do
          prepare
          EM.synchrony do
            service_result = consumer.request(:say_hello, :to_no_one, {}, { fast: true })
            service_result.should be_nil
            done
            finalize
          end
        end
      end
    end

  context 'expecting response' do
    context 'can invoke services' do
      When(:service) { provider.add_service boring_salutation_service }
      When(:params) { { who: 'world' } }
      Then do
        em do
          prepare
          EM.synchrony do
            service_result = EM::Synchrony.sync consumer.request(:say_hello, :do_it, params, { timeout: 2 })
            service_result.should eq "Hello world"
            done
            finalize
          end
        end
      end
    end

    context 'fails with error => Timeout::Error when the response is slow' do
      Given(:time_base) { 0.01 }
      When(:params) { { time: time_base*4 } }
      When(:service) { provider.add_service slow_service }
      Then do
        em do
          prepare
          EM.synchrony do
            service_result = EM::Synchrony.sync consumer.request(:sleep, :do_it, params, { timeout: time_base/2.0 })
            service_result.should be_a Hash
            service_result.should have_key :error
            service_result[:error].should eq 'Timeout::Error'
            done(time_base) #timeout response must came before this timeout
          end
          finalize
        end
      end
    end

    context 'return the same data type returned by service' do
      Given(:result_container) { {} }
      Given(:params) { { data: data } }
      When(:service) { provider.add_service echo_service }
      When('service is called') do
        em do
          prepare
          EM.synchrony do
            result_container[:result] = EM::Synchrony.sync consumer.request(:echo_this, :do_it, params)
            done
            finalize
          end
        end
      end

      context 'for string' do
        Given(:data) { "a simple string" }
        Then { result_container[:result].should eq data}
      end

      context 'for numbers' do
        Given(:data) { 237.324 }
        Then { result_container[:result].should eq data}
      end

      context 'for arrays' do
        Given(:data) { [1, 2, 3.0, "4", "cinco"]}
        Then { result_container[:result].should eq data}
      end

      context 'for symbols always return a string' do
        Given(:data) { :some_symbol }
        Then { result_container[:result].should eq data.to_s}
      end

      context 'for maps' do
        context 'with string keys' do
          Given(:data) { {'a' => 1, 'b' => 'dos'} }
          Then { result_container[:result].keys.should eq data.keys.map(&:to_sym)}
          And  { result_container[:result].values.should eq data.values }
        end
        context 'with symbol keys' do
          Given(:data) { {a: 1, b: 'dos'} }
          Then { result_container[:result].should eq data}
        end
      end

      context 'for objects returns their json version' do
        Given(:custom_json) { {val: 'value'} }
        Given(:custom_class) do
          Class.new do
            def initialize(custom_json)
              @custom_json = custom_json
            end
            def to_json
              @custom_json
            end
          end
        end
        Given(:data) { custom_class.new(custom_json).to_json}
        Then { result_container[:result].should eq custom_json}
      end
    end

    context 'return something when service raise an error' do
      Given(:error_message) { 'service is broken' }
      When(:service) { provider.add_service broken_service }
      Then do
        em do
          prepare
          EM.synchrony do
            service_result = EM::Synchrony.sync consumer.request(:shout_error, :do_it, {message: error_message}, { timeout: 0.1 })
            service_result[:error].should be_a Hash
            service_result[:error][:message].should eq error_message
            service_result[:error][:backtrace].should_not be_nil
            service_result[:error][:backtrace].should be_an Array
            done
            finalize
          end
        end
      end
    end

    context 'return an error when requesting an unknown service' do
      Given(:error_message) { Combi::Bus::UnknownStop.name }
      When(:service) { provider.add_service broken_service }
      Then do
        em do
          prepare
          EM.synchrony do
            begin
              service_result = EM::Synchrony.sync consumer.request(:some_not_service, :do_it, {}, { timeout: 0.1 })
              if defined?(Combi::Queue) and consumer.class == Combi::Queue
                service_result[:error].should eq "Timeout::Error"
              else
                service_result[:error][:klass].should eq error_message
                service_result[:error][:message].should eq 'some_not_service/do_it'
              end
              done
              finalize
            end
          end
        end
      end
    end

    context 'return an error when requesting an unknown action for the service' do
      Given(:error_message) { Combi::Bus::UnknownStop.name }
      When(:service) { provider.add_service echo_service }
      Then do
        em do
          prepare
          EM.synchrony do
            begin
              service_result = EM::Synchrony.sync consumer.request(:echo_this, :do_other, {}, { timeout: 0.1 })
              service_result[:error][:klass].should eq error_message
              service_result[:error][:message].should eq 'echo_this/do_other'
              done
              finalize
            end
          end
        end
      end
    end
  end
end
