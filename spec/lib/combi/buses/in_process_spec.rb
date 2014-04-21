require 'spec_helper'

require 'combi/service_bus'
require 'combi/buses/in_process'

describe 'Combi::InProcess' do
  context 'can be instanitated via ServiceBus' do
    When(:bus) { Combi::ServiceBus.init_for(:in_process, {}) }
    Then { Combi::InProcess === bus }
  end

  Given(:subject) { Combi::ServiceBus.init_for(:in_process, {}) }

  context 'can register services' do
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
    When(:service) { subject.add_service boring_salutation_service }
    When(:params) { { who: 'world' } }
    Then do 
      subject.request(:say_hello, :do_it, params.to_json) {|x| x} == "Hello world"
    end
  end
end
