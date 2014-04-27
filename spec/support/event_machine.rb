require 'combi/reactor'

def start_background_reactor
  Combi::Reactor.start do
    EM::add_timer(10) do
      puts "xxxxxx forcing stop of EM reactor"
      EM::stop_event_loop
    end
  end
end

def stop_background_reactor
  Combi::Reactor.stop
end
