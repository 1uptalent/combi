require 'spec_helper'
require 'shared_examples/standard_bus'

require 'combi/service_bus'
require 'combi/buses/in_process'

describe 'Combi::InProcess' do
  context 'can be instanitated via ServiceBus' do
    When(:bus) { Combi::ServiceBus.init_for(:in_process, {}) }
    Then { Combi::InProcess === bus }
  end

  Given(:subject) { Combi::ServiceBus.init_for(:in_process, {}) }

  it_behaves_like 'standard_bus'
end
