require 'eventmachine'

module Combi
  class Reactor
    def self.start(&block)
      EM::error_handler do |error|
        STDERR << "ERROR IN EM\n"
        STDERR << "\t#{error.inspect}"
        STDERR << "\t#{error.backtrace.join("\t\n")}" << "\n"
      end
      log "-EM.start- the reactor is running: #{EM::reactor_running?}"
      raise "EM did not shut down" if EM::reactor_running?
      @@reactor_thread = Thread.new do
        begin
          log "------- starting EM reactor"
          EM::run do
            log "------- reactor started"
            block.call unless block.nil?
          end
        ensure
          puts "------- reactor stopped"
        end
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
