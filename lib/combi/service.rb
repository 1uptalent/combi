module Combi
  class Service

    @@actions = {}

    def initialize(service_bus, context = {})
      @service_bus = service_bus
      @context = context
      setup_services
      register_actions
    end

    def setup_services
    end

    def register_actions
      @@actions.each do |handler, options|
        service_bus.respond_to self, handler, options
      end
    end

    def no_response
      nil
    end

    def async_response(&block)
      lambda &block
    end

    def self.respond_to(handler, options = {})
      @@actions[handler] = options
    end

    def service_bus
      @service_bus
    end

    def enable(*services, &block)
      service_bus.enable(services)
      yield block if block_given?
    end

    def context
      @context
    end

  end
end
