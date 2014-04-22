require 'spec_helper'

require 'combi/service_bus'
require 'combi/buses/in_process'

describe 'Combi::InProcess' do
  context 'can be instanitated via ServiceBus' do
    When(:bus) { Combi::ServiceBus.init_for(:in_process, {}) }
    Then { Combi::InProcess === bus }
  end

  Given(:subject) { Combi::ServiceBus.init_for(:in_process, {}) }
  Given(:boring_salutation_service) do
    Module.new do
      def actions
        [:say_hello]
      end

      def do_it(params)
        "Hello #{params['who']}"
      end
    end
  end

  context 'can invoke services' do
    When(:service) { subject.add_service boring_salutation_service }
    When(:params) { { who: 'world' } }
    Then do 
      subject.request(:say_hello, :do_it, params.to_json) do |result|
        result == "Hello world"
      end
    end
  end

  context 'raises Timeout::Error when the response is slow' do
    Given(:slow_service) do
      Module.new do
        def actions; [:sleep]; end
        def do_it(params)
          sleep params['time']
        end
      end
    end
    When(:params) { { time: 0.001 } }
    When(:service) { subject.add_service slow_service }
    Then do
      expect do
        subject.request(:sleep, :do_it, params.to_json, { timeout: params[:time]/2.0 }) do
          raise "Should never get here"
        end
      end.to raise_error Timeout::Error
    end
  end
end
