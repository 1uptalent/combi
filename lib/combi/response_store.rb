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
      waiter.succeed(response)
      @waiters.delete correlation_id
    end
  end

  class EventedWaiter
    include EM::Deferrable

    def self.wait_for(key, response_store, timeout)
      waiter = new(key, response_store, timeout, Combi::Bus::RPC_MAX_POLLS)
      response_store.add_waiter(key, waiter)
      waiter
    end

    def initialize(key, response_store, timeout, max_polls)
      self.timeout(timeout, RuntimeError.new(Timeout::Error))
    end

  end
end
