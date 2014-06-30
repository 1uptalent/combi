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
      log "started waiting for #{correlation_id}"
      @started_wait_at = Time.now
      @correlation_id = correlation_id
      self.timeout(timeout, 'error' => 'Timeout::Error')
    end

    def succeed(*args)
      log "OK > #{@correlation_id}: #{Time.now.to_f - @started_wait_at.to_f}s"
      super
    end

    def fail(*args)
      log "KO > #{@correlation_id}: #{Time.now.to_f - @started_wait_at.to_f}s, #{args.inspect[0..500]}"
      super
    end

    def log(message)
      return unless @debug_mode ||= ENV['DEBUG'] == 'true'
      puts "#{Time.now.to_f} #{self.class.name} #{message}"
    end
  end
end
