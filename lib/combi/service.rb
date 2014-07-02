module Combi
  module Service

    def setup(service_bus, context)
      context ||= {}
      context[:service_bus] = service_bus
      setup_context(context)
      setup_services
      self
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

    def no_response
      nil
    end

    def async_response(&block)
      lambda &block
    end

    def actions
      []
    end

    def remote_methods
      @_REMOTE_METHODS ||= public_methods(false) - Combi::Service.public_instance_methods
    end

    def service_bus
      @service_bus
    end

    def enable(*services, &block)
      service_bus.enable(services)
      yield block if block_given?
    end

    def to_s
      @_TO_S ||= "#{self.class.name}"
    end

  end
end
