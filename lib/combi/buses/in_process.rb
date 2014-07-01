require 'combi/buses/bus'

module Combi
  class InProcess < Bus

    def request(service_name, kind, message, options = {})
      options[:timeout] ||= RPC_DEFAULT_TIMEOUT
      waiter = EventMachine::DefaultDeferrable.new
      begin
        Timeout.timeout(options[:timeout]) do
          message = Yajl::Parser.parse(Yajl::Encoder.encode(message), symbolize_keys: true)
          response = invoke_service(service_name, kind, message)
          response.callback do |service_response|
            waiter.succeed service_response
          end
          response.errback do |service_response|
            waiter.fail error: service_response
          end
        end
      rescue Timeout::Error => e
        waiter.fail error: 'Timeout::Error'
      end
      waiter
    end
  end
end
