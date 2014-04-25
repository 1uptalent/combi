require 'eventmachine'

def start_background_reactor
  EM::error_handler do |error|
    STDERR << "ERROR IN EM\n"
    STDERR << "\t#{error.inspect}"
    STDERR << error.backtrace << "\n"
  end
  puts "-EM.start- the reactor is running: #{EM::reactor_running?}"
  raise "EM did not shut down" if EM::reactor_running?
  Thread.new do
    puts "------- starting EM reactor"
    EM::run do
      puts "------- reactor started"
      EM::add_timer(10) do
        puts "xxxxxx forcing stop of EM reactor"
        EM::stop_event_loop
      end
    end
    puts "------- reactor stopped"
  end
  10.times do
    sleep 0.1 unless EM::reactor_running?
  end
end

def stop_background_reactor
  puts "-EM.stop- the reactor is running: #{EM::reactor_running?}"
  EM::stop_event_loop if EM::reactor_running?
  50.times do
    sleep 0.3 if EM::reactor_running?
  end
end
