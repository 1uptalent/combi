require 'combi/buses/bus'

module Combi
  class InProcess < Bus

    def request(handler, kind, message, options = {timeout: 0.1}, &block)
      handler = memory_handlers[handler.to_s]
      return if handler.nil?
      service_instance = handler[:service_instance]
      message = JSON.parse(message) if message.is_a?(String)
      return unless service_instance.respond_to?(kind)
      response = service_instance.send(kind, message)
      response = response.call if response.is_a?(Proc)
      block.call response
    end

    def respond_to(service_instance, handler, options = {})
      memory_handlers[handler.to_s] = {service_instance: service_instance, options: options}
    end

    def memory_handlers
      @memory_handlers ||= {}
    end

  end
end
