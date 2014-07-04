require 'eventmachine'

class Combi::Reactor
  def self.start(&block)
    EM::error_handler do |error|
      STDERR << "ERROR IN EM\n"
      STDERR << "\t#{error.inspect}"
      STDERR << "\t#{error.backtrace.join("\t\n")}" << "\n"
    end
    Combi.logger.info {"-EM.start- the reactor is running: #{EM::reactor_running?}"}
    raise "EM did not shut down" if EM::reactor_running?
    @@reactor_thread = Thread.new do
      begin
        Combi.logger.debug {"------- starting EM reactor"}
        EM::run do
          Combi.logger.debug {"------- reactor started"}
          block.call unless block.nil?
        end
      ensure
        Combi.logger.info {"------- reactor stopped"}
      end
    end
    30.times do
      sleep 0.1 unless EM::reactor_running?
    end
  end

  def self.stop
    Combi.logger.debug {"-EM.stop- the reactor is running: #{EM::reactor_running?}"}
    EM::stop_event_loop if EM::reactor_running?
    50.times do
      sleep 0.3 if EM::reactor_running?
    end
  end

  def self.join_thread
    @@reactor_thread.join if @@reactor_thread
  end

end
