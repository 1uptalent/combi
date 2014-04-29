require 'spec_helper'

require 'combi/service_bus'
require 'combi/buses/in_process'

describe 'Combi::InProcess' do
  include EventedSpec::SpecHelper

  context 'can be instanitated via ServiceBus' do
    When(:bus) { Combi::ServiceBus.init_for(:in_process, {}) }
    Then { Combi::InProcess === bus }
  end

  Given(:subject) { Combi::ServiceBus.init_for(:in_process, {}) }
  Given(:provider) { subject }
  Given(:consumer) { subject }
  Given(:prepare) do
    provider.start!
    consumer.start!
  end

  it_behaves_like 'standard_bus'

end
