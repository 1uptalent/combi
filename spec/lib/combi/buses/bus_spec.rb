require 'spec_helper'

describe 'Combi::Bus' do
  context 'registers services' do
    Given(:subject) { Combi::Bus.new({}) }

    context 'via instances' do
      Given(:service_class) { Class.new{include Combi::Service} }
      Given(:service_definition) { service_class.new }
      When { subject.add_service service_definition }
      Then { subject.services == [service_definition] }
    end

    context 'via modules' do
      Given(:service_definition) { Module.new }
      When { subject.add_service service_definition }
      Then { subject.services.length == 1 }
       And { Combi::Service === subject.services[0] }
       And { service_definition === subject.services[0] }
    end
  end
end
