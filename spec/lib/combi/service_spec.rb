require 'spec_helper'

describe 'Combi::Service' do
  Given(:subject_class) { Class.new{include Combi::Service} }
  Given(:subject) { subject_class.new }

  describe '#setup' do
    Given(:context) { {foo: 'bar', one: 1} }
    Given!("setup methods are stubbed") do
      subject.stub(:setup_context).and_call_original
      subject.stub(:setup_services).and_call_original
    end
    Given(:the_bus) { double "the bus" }
    When { subject.setup the_bus, context }
    context 'sets up the context' do
      Then { subject.should have_received(:setup_context).with context }
    end
    context 'allows the service to setup itself' do
      Then { subject.should have_received :setup_services }
    end
    context 'always includes the service_bus in the context' do
      Then { subject.service_bus == the_bus }
    end
  end

  describe '#setup_context' do
    context 'creates accessors for keys in the context' do
      Given(:context) { {foo: 'bar', one: 1} }
      When { subject.setup_context context }
      Then { subject.respond_to? :foo }
       And { subject.respond_to? :one}
       And { subject.foo == 'bar' }
       And { subject.one == 1 }
     end
  end
end
