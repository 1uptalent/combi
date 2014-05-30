require 'timeout'

module Combi

  class ServiceError < StandardError
  end

  def self.wait_for(defer, options = {}, &block)
    options[:timeout] ||= 2
    waiter_thread = Thread.current
    success_response, error_response = nil
    defer.callback { |response|
      success_response = response
      waiter_thread.wakeup
    }
    defer.errback { |response|
      STDERR << "waiting for result, received an error: #{response.inspect}\n"
      error_response = response
      waiter_thread.wakeup
    }
    Timeout::timeout(options[:timeout]) do
      Thread.stop
      puts "\t AFTER STOP"
      raise ServiceError.new(error_response) if error_response
      block.call success_response
    end
  end

end
