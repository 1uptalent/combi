require "combi/service"

module Combi
  class Bus

    def initialize(options)
      @options = options
      post_initialize
    end

    def post_initialize
    end

    def add_service(service_definition, options = {})
      service = if service_definition.is_a?(Module)
        service = Object.new
        service.extend Combi::Service
        service.extend service_definition
      else
        require "service/#{service_definition}"
        class_name = service_definition.split('_').map {|w| w.capitalize}.join
        Object.const_get("Service::#{class_name}").new
      end
      service.setup(self, options[:context])
    end

    def start!
    end

    def stop!
    end

    def restart!
      stop!
      start!
    end

    def enable(services)
      services.each do |service|
        case service
        when :queue
          require 'queue_service'
          EventMachine.next_tick do
            Combi::QueueService.start ConfigProvider.for(:amqp)
          end
        when :redis
          require 'redis'
          $redis = Redis.new ConfigProvider.for(:redis)
        when :active_record
          require 'active_record'
          ActiveRecord::Base.establish_connection ConfigProvider.for(:database)
        when :bus
          $service_bus = Combi::ServiceBus.for(:queue)
        end
      end
    end

  end
end
