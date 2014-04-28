
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
      def do_it(params); "Hello #{params['who']}"; end
    end
  end

  Given(:provider_started) {
    EM.next_tick do
      provider.start!
    end
    true
  }

  Given(:consumer_started) {
    EM.run do
      consumer.start!
    end
    true
  }

  context 'can invoke services' do
    When(:service) { provider.add_service boring_salutation_service }
    When(:params) { { who: 'world' } }
    Then do
      service_result = nil
      em do
        puts ">>> TEST START"
        service_result = consumer.request(:say_hello, :do_it, params)
        puts '-->'
        puts service_result
        puts "joining reactor"
        #start_background_reactor
        #Combi::Reactor.join_thread
        puts ">>> TEST END"
        done
      end
      puts "after EM"
      service_result.should eq "Hello world"
    end
  end
  #
  # context 'raises Timeout::Error when the response is slow' do
  #   When(:params) { { time: 0.01 } }
  #   When(:service) { provider.add_service slow_service }
  #   Then do
  #     expect do
  #       consumer.request(:sleep, :do_it, params, { timeout: params[:time]/2.0 })
  #       done
  #     end.to raise_error Timeout::Error
  #     #start_background_reactor
  #     #Combi::Reactor.join_thread
  #
  #   end
  # end
end
