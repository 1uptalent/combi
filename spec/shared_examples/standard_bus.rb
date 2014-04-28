
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

  context 'can invoke services' do
    When(:service) { provider.add_service boring_salutation_service }
    When(:params) { { who: 'world' } }
    Then do
      em do
        provider.start!
        webserver
        consumer.start!
        EM.synchrony do
          service_result = EM::Synchrony.sync consumer.request(:say_hello, :do_it, params)
          service_result.should eq "Hello world"
          done
        end
      end
    end
  end

  context 'can invoke services async' do
    When(:service) { provider.add_service boring_salutation_service }
    When(:params) { { who: 'world' } }
    Then do
      em do
        provider.start!
        webserver
        consumer.start!
        service_result = nil
        Fiber.new do
          service_result = consumer.rrequest(:say_hello, :do_it, params)
          service_result.should eq "Hello world"
        end.resume
        done(0.1) #without a timeout, test will finalize meanwhile the service is running
      end
    end
  end

  context 'raises Timeout::Error when the response is slow' do
    Given(:time_base) { 0.01 }
    When(:params) { { time: time_base*4 } }
    When(:service) { provider.add_service slow_service }
    Then do
      em do
        provider.start!
        webserver
        consumer.start!
        Fiber.new do
          expect do
            service_result = consumer.rrequest(:sleep, :do_it, params, { time_base: time_base/2.0 })
            raise Kernel.const_get(service_result.message) if service_result.is_a? Exception
          end.to raise_error Timeout::Error
        end.resume
        done(time_base) #timeout response must came before this timeout
      end
    end
  end
end
