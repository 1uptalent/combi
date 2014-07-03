require 'eventmachine'

class Combi::ResponseStore
  def initialize()
    @waiters = {}
  end

  # Returns an EM::Deferrable
  def wait_for(correlation_id, timeout)
    waiter = EM::DefaultDeferrable.new
    add_waiter correlation_id, waiter
    waiter.timeout timeout, error: 'Timeout::Error'
  end

  def handle_rpc_response(response)
    correlation_id = response[:correlation_id]
    waiter = @waiters[correlation_id]
    return unless waiter
    response = response[:response] #Yajl::Parser.parse response[:response], sybolize_keys: true
    if response.respond_to?(:keys) and response[:error]
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
