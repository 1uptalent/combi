require "combi/service"
require 'yajl'
require 'yajl/json_gem' # for object.to_json, JSON.parse, etc...

module Combi
  class Bus
    attr_reader :services

    RPC_DEFAULT_TIMEOUT = 1

    def initialize(options)
      @options = options
      @services = []
      post_initialize
    end

    def post_initialize
    end

    def add_service(service_definition, options = {})
      service = make_service_instance(service_definition)
      service.setup(self, options[:context])
      @services << service
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
          EventMachine.run do
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

    def log(message)
      return unless @debug_mode ||= ENV['DEBUG'] == 'true'
      puts "#{Time.now.to_f} #{self.class.name} #{message}"
    end

    protected

    def make_service_instance(service_definition)
      if Combi::Service === service_definition
        service = service_definition
      else
        service = create_service_from_module(service_definition)
      end
    end

    def create_service_from_module(a_module)
      service_class = Class.new do
        include Combi::Service
        include a_module
      end
      service = service_class.new
    end

  end
end
