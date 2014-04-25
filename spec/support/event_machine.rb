require 'eventmachine'
def start_background_reactor
  puts "------- the reactor is running: #{EM::reactor_running?}"
  EM::error_handler do |error|
    STDERR << "ERROR IN EM\n"
    STDERR << "\t#{error.inspect}"
    STDERR << error.backtrace << "\n"
  end
  sleep 0.1 if EM::reactor_running? # wait one quantum
  raise "EM did not shut down" if EM::reactor_running?
  Thread.new do
    puts "------- starting EM reactor"
    EM::run
    puts "------- reactor stopped"
  end
end

def stop_background_reactor
  puts "------- the reactor is running: #{EM::reactor_running?}"
  EM::stop_event_loop if EM::reactor_running?
end
