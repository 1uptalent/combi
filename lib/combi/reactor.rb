require 'eventmachine'

module Combi
  class Reactor
    def self.start(&block)
      EM::error_handler do |error|
        STDERR << "ERROR IN EM\n"
        STDERR << "\t#{error.inspect}"
        STDERR << error.backtrace << "\n"
      end
      log "-EM.start- the reactor is running: #{EM::reactor_running?}"
      raise "EM did not shut down" if EM::reactor_running?
      @@reactor_thread = Thread.new do
        log "------- starting EM reactor"
        EM::run do
          log "------- reactor started"
          Signal.trap("INT")  { EM::stop_event_loop }
          Signal.trap("TERM") { EM::stop_event_loop }
          block.call unless block.nil?
        end
        log "------- reactor stopped"
      end
      30.times do
        sleep 0.1 unless EM::reactor_running?
      end
    end

    def self.stop
      log "-EM.stop- the reactor is running: #{EM::reactor_running?}"
      EM::stop_event_loop if EM::reactor_running?
      50.times do
        sleep 0.3 if EM::reactor_running?
      end
    end

    def self.join_thread
      @@reactor_thread.join if @@reactor_thread
    end

    def self.log(message)
      return unless @debug_mode ||= ENV['DEBUG'] == 'true'
      puts "#{object_id} #{self.class.name} #{message}"
    end

  end
end
