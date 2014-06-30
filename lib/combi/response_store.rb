require 'eventmachine'

module Combi
  class ResponseStore
    def initialize()
      @waiters = {}
    end

    # Returns an EM::Deferrable
    def wait_for(correlation_id, timeout)
      waiter = EventedWaiter.new(correlation_id, timeout)
      add_waiter correlation_id, waiter
    end

    def handle_rpc_response(response)
      correlation_id = response['correlation_id']
      waiter = @waiters[correlation_id]
      return unless waiter
      response = JSON.parse response['response']
      if response.respond_to?(:keys) and response['error']
        waiter.fail response
      else
        waiter.succeed response
      end
    end

    protected

    def add_waiter(correlation_id, waiter)
      @waiters[correlation_id] = waiter
      waiter.callback { |r| remove_waiter correlation_id }
      waiter.errback  { |r| remove_waiter correlation_id }
      waiter
    end

    def remove_waiter(correlation_id)
      @waiters.delete correlation_id
    end
  end

  protected

  class EventedWaiter
    include EM::Deferrable

    def initialize(correlation_id, timeout)
      @started_wait_at = Time.now
      @correlation_id = correlation_id
      self.timeout(timeout, 'error' => 'Timeout::Error')
    end
  end
end
