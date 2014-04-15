module Combi
  class Service

    def initialize(service_bus, context, service_definition = nil)
      context ||= {}
      context[:service_bus] = service_bus
      extend service_definition if service_definition.is_a?(Module)
      setup_context(context)
      setup_services
      register_actions
    end

    def setup_context(context)
      @context = context
      @context.keys.each do |context_var|
        define_singleton_method context_var do
          @context[context_var]
        end
      end
    end

    def setup_services
    end

    def register_actions
      actions.each do |handler|
        service_bus.respond_to(self, handler)
      end
      fast_actions.each do |handler|
        service_bus.respond_to(self, handler, fast: true)
      end
    end

    def no_response
      nil
    end

    def async_response(&block)
      lambda &block
    end

    def actions
      []
    end

    def fast_actions
      []
    end

    def service_bus
      @service_bus
    end

    def enable(*services, &block)
      service_bus.enable(services)
      yield block if block_given?
    end

  end
end
