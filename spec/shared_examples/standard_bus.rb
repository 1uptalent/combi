
shared_examples_for "standard_bus" do

  Given(:slow_service) do
    Module.new do
      def actions; [:sleep]; end
      def do_it(params)
        puts "slooooow service"
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
        puts ">>> TEST START"
        provider.start!
        webserver
        consumer.start!
        EM.synchrony do
          service_result = EM::Synchrony.sync consumer.request(:say_hello, :do_it, params)
          puts "after SYNC"
          puts "RESULT IS:"
          puts service_result
          puts "-"*40
          service_result.should eq "Hello world"
          done
        end
        puts ">>> TEST END"
      end
      puts "after EM"
    end
  end

  context 'can invoke services async' do
    When(:service) { provider.add_service boring_salutation_service }
    When(:params) { { who: 'world' } }
    Then do
      em do
        puts ">>> TEST START ASYNC"
        provider.start!
        webserver
        consumer.start!
        service_result = consumer.rrequest(:say_hello, :do_it, params)
        puts "after ASYNC"
        puts "RESULT IS:"
        puts service_result
        puts "-"*40
        service_result.should eq "Hello world"
        done
        puts ">>> TEST END"
      end
      puts "after EM"
    end
  end

  # context 'raises Timeout::Error when the response is slow' do
  #   When(:params) { { time: 0.01 } }
  #   When(:service) { provider.add_service slow_service }
  #   Then do
  #     em do
  #       provider.start!
  #       webserver
  #       consumer.start!
  #       expect do
  #         puts "1"*40
  #         EM.synchrony do
  #           res = EM::Synchrony.sync consumer.request(:sleep, :do_it, params, { timeout: params[:time]/2.0 })
  #           puts "-"*30
  #           puts res.inspect
  #           puts "2"*40
  #         end
  #       end.to raise_error Timeout::Error
  #       done
  #     end
  #     #start_background_reactor
  #     #Combi::Reactor.join_thread
  #
  #   end
  # end
end
