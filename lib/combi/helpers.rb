require 'timeout'

module Combi

  def self.wait_for(defer, &block)
    resolved = false
    defer.callback { |response|
      resolved = true
      puts "responding to block with"
      puts response
      block.call response
    }
    Timeout::timeout(2) do
      sleep 0.1 while !resolved
    end
  end

end
