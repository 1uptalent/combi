require 'spec_helper'

require 'combi/service_bus'
require 'combi/buses/queue'

describe 'Combi::Queue' do
  context 'can be instanitated via ServiceBus' do
    When(:bus) { Combi::ServiceBus.init_for(:queue, {}) }
    Then { Combi::Queue === bus }
  end
end
