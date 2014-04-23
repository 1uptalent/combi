module Combi
  class ServiceBus
    class << self
      @@buses = {}

      def for(kind, options = {})
        @@buses[kind] ||= init_for(kind, options)
      end

      def init_for(kind, options)
        require 'combi/buses/bus'

        case kind
        when :in_process
          require 'combi/buses/in_process'
          Combi::InProcess.new(options)
        when :queue
          require 'combi/buses/queue'
          Combi::Queue.new(options)
        when :web_socket
          require 'combi/buses/web_socket'
          Combi::WebSocket.new(options)
        when :http
          require 'combi/buses/http'
          Combi::Http.new(options)
        end
      end
    end

  end
end
