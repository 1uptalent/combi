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
      waiter = EventMachine::DefaultDeferrable.new
      waiter.timeout(options[:timeout], RuntimeError.new(Timeout::Error))
      begin
        Timeout.timeout(options[:timeout]) do
          response = service_instance.send(kind, message)
          if response.respond_to? :succeed
            response.callback do |service_response|
              waiter.succeed service_response
            end
          else
            waiter.succeed response
          end
        end
      rescue Timeout::Error => e
        log "ERROR"
        waiter.fail RuntimeError.new(Timeout::Error)
      rescue e
        log "other ERROR"
        log e.inspect
      end

      waiter
    end

    def respond_to(service_instance, handler, options = {})
      memory_handlers[handler.to_s] = {service_instance: service_instance, options: options}
    end

    def memory_handlers
      @memory_handlers ||= {}
    end

  end
end
