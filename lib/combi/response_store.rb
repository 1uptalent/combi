require 'eventmachine'

module Combi
  class ResponseStore
    def initialize()
      @waiters = {}
    end

    def add_waiter(key, waiter)
      @waiters[key] = waiter
    end

    def handle_rpc_response(response)
      correlation_id = response['correlation_id']
      waiter = @waiters[correlation_id]
      response = response['response']
      waiter.succeed(JSON.parse response)
      @waiters.delete correlation_id
    end
  end

  class EventedWaiter
    include EM::Deferrable
    def self.log(message)
      return unless @debug_mode ||= ENV['DEBUG'] == 'true'
      puts "#{Time.now.to_f} #{self.name} #{message}"
    end

    def self.wait_for(key, response_store, timeout)
      t1 = Time.now
      log "started waiting for #{key}"
      waiter = new(key, response_store, timeout)
      response_store.add_waiter(key, waiter)
      waiter.callback {|r| log "success waiting for #{key}: #{Time.now.to_f - t1.to_f}s" }
      waiter.errback {|r| log "failed waiting for #{key}: #{Time.now.to_f - t1.to_f}s, #{r.inspect}" }
      waiter
    end

    def initialize(key, response_store, timeout)
      self.timeout(timeout, RuntimeError.new(Timeout::Error))
    end

  end
end
