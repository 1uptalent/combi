require 'combi/buses/bus'

module Combi
  class InProcess < Bus

    def request(handler_name, kind, message, options = {})
      options[:timeout] ||= RPC_DEFAULT_TIMEOUT
      handler = memory_handlers[handler_name.to_s]
      waiter = EventMachine::DefaultDeferrable.new
      if handler.nil?
        waiter.fail('error' => 'unknown service')
      else
        service_instance = handler[:service_instance]
        message = JSON.parse(message.to_json)
        if service_instance.respond_to?(kind)
          waiter.timeout(options[:timeout], 'error' => 'Timeout::Error')
          begin
            Timeout.timeout(options[:timeout]) do
              response = invoke_service(service_instance, kind, message)
              if response.respond_to? :succeed
                response.callback do |service_response|
                  log "responding with deferred response: #{service_response.inspect[0..500]}"
                  waiter.succeed service_response
                end
                response.errback do |service_response|
                  failure_response = { 'error' => service_response }
                  log "responding with deferred failure: #{service_response.inspect[0..500]}"
                  waiter.fail(failure_response)
                end
              else
                waiter.succeed response
              end
            end
          rescue Timeout::Error => e
            waiter.fail 'error' => 'Timeout::Error'
          rescue RuntimeError => e
            waiter.fail 'error' => {'klass' => e.class.name, 'message' => e.message, 'backtrace' => e.backtrace}
          end
        else
          waiter.fail('error' => { 'klass' => 'unknown action', 'message' => kind.to_s })
        end
      end
      waiter
    end

    def respond_to(service_instance, action, options = {})
      memory_handlers[action.to_s] = {service_instance: service_instance, options: options}
    end

    def memory_handlers
      @memory_handlers ||= {}
    end

  end
end
