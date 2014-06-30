require 'combi/buses/bus'

module Combi
  class InProcess < Bus

    def request(service_name, kind, message, options = {})
      options[:timeout] ||= RPC_DEFAULT_TIMEOUT
      waiter = EventMachine::DefaultDeferrable.new
      begin
        Timeout.timeout(options[:timeout]) do
          message = JSON.parse(message.to_json)
          response = invoke_service(service_name, kind, message)
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
      rescue StandardError => e
        waiter.fail 'error' => {'klass' => e.class.name, 'message' => e.message, 'backtrace' => e.backtrace}
      end
      waiter
    end
  end
end
