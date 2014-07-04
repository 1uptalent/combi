require 'spec_helper'
require 'combi/buses/bus'

describe 'Combi::Bus' do
  context 'registers services' do
    Given(:bus) { Combi::Bus.new({}) }

    context 'via instances' do
      Given(:service_class) do
        Class.new do
          include Combi::Service
          def actions; ['class']; end
          def remote; end
        end
      end
      Given(:service_definition) { service_class.new }
      Given(:path) { 'class/remote' }
      When { bus.add_service service_definition }
      Then { bus.routes.keys.length == 1 }
      And  { bus.routes[path] == service_definition }
    end

    context 'via modules' do
      Given(:service_definition) do
        Module.new do
          def actions; ['module']; end
          def remote; end
        end
      end
      Given(:path) { 'module/remote' }
      When { bus.add_service service_definition }
      Then { bus.routes.keys.length == 1 }
      And  { bus.routes[path].is_a? service_definition }
    end
  end
end
