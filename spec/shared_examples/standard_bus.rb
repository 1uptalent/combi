require "em-synchrony"

shared_examples_for "standard_bus" do

  Given(:slow_service) do
    Module.new do
      def actions; [:sleep]; end
      def do_it(params)
        sleep params['time']
      end
    end
  end

  Given(:boring_salutation_service) do
    Module.new do
      def actions; [:say_hello]; end
      def do_it(params)
        "Hello #{params['who']}"
      end
    end
  end

  Given(:echo_service) do
    Module.new do
      def actions; [:echo_this]; end
      def do_it(params)
        params['data']
      end
    end
  end

  Given(:finalize) do
    provider.stop!
    consumer.stop!
  end

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

  context 'raises Timeout::Error when the response is slow' do
    Given(:time_base) { 0.01 }
    When(:params) { { time: time_base*4 } }
    When(:service) { provider.add_service slow_service }
    Then do
      em do
        prepare
        EM.synchrony do
          expect do
            service_result = EM::Synchrony.sync consumer.request(:sleep, :do_it, params, { timeout: time_base/2.0 })
            raise Kernel.const_get(service_result.message) if service_result.is_a? Exception
          end.to raise_error Timeout::Error
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

    context 'for symbols' do
      Given(:data) { :some_symbol }
      Then { result_container[:result].should eq data}
    end

    context 'for maps' do
      Given(:data) { {'a' => 1, 'b' => 'dos'} }
      Then { result_container[:result].should eq data}
    end

    context 'for objects' do
      Given(:custom_class) {Class.new do def initialize(val); @val=val;end;end;}
      Given(:data) { custom_class.new('value') }
      Then { result_container[:result].should eq data}
    end

  end

end
