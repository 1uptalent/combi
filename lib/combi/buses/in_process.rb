require 'combi/buses/bus'

module Combi
  class InProcess < Bus

    def request(handler_name, kind, message, options = {}, &block)
      options[:timeout] ||= RPC_DEFAULT_TIMEOUT
      handler = memory_handlers[handler_name.to_s]
      return if handler.nil?
      service_instance = handler[:service_instance]
      message = JSON.parse(message.to_json)
      return unless service_instance.respond_to?(kind)
      Timeout.timeout(options[:timeout]) do
        response = service_instance.send(kind, message)
        response = response.call if response.is_a?(Proc)
        block.call response
      end
    end

    def respond_to(service_instance, handler, options = {})
      memory_handlers[handler.to_s] = {service_instance: service_instance, options: options}
    end

    def memory_handlers
      @memory_handlers ||= {}
    end

  end
end
