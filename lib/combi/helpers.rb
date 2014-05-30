require 'timeout'

module Combi

  def self.wait_for(defer, options = {}, &block)
    options[:timeout] ||= 2
    waiter_thread = Thread.current
    defer.callback { |response|
      block.call response
      waiter_thread.wakeup
    }
    Timeout::timeout(options[:timeout]) do
      Thread.stop
    end
  end

end
