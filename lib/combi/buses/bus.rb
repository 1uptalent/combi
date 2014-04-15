module Combi
  class Bus

    def initialize(options)
      @options = options
      post_initialize
    end

    def post_initialize
    end

    def add_service(name, options = {})
      require "combi/service"
      require "service/#{name}"
      class_name = name.split('_').map {|w| w.capitalize}.join
      Object.const_get("Service::#{class_name}").new(self, options[:context])
    end

    def start!
    end

    def loop
    end

    def stop!
    end

    def restart!
    end

    def enable(services)
      services.each do |service|
        case service
        when :queue
          require 'queue_service'
          EventMachine.next_tick do
            QueueService.start ConfigProvider.for(:amqp)
          end
        when :redis
          require 'redis'
          $redis = Redis.new ConfigProvider.for(:redis)
        when :active_record
          require 'active_record'
          ActiveRecord::Base.establish_connection ConfigProvider.for(:database)
        end
      end
    end

  end
end
