require 'timeout'

module Combi

  def self.wait_for(defer, options = {}, &block)
    options[:timeout] ||= 2
    poll_time = options[:timeout] / 10
    resolved = false
    defer.callback { |response|
      resolved = true
      block.call response
    }
    Timeout::timeout(options[:timeout]) do
      sleep poll_time while !resolved
    end
  end

end
