require "combi/service"
require_relative 'correlation'
require 'yajl'

module Combi
  class Bus
    RPC_DEFAULT_TIMEOUT = 1
    attr_reader :routes

    def initialize(options)
      @options = options
      @routes = {}
      post_initialize
    end

    def post_initialize
    end

    def add_service(service_definition, options = {})
      service_instance = make_service_instance(service_definition)
      service_instance.actions.each do |service_name|
        self.add_routes_for(service_name, service_instance)
      end
      service_instance.setup(self, options[:context])
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

        define_method :service_module do
           a_module
        end
        protected :service_module

        def remote_methods
          @_REMOTE_METHODS ||= service_module.public_instance_methods(false) - Combi::Service.public_instance_methods
        end
        def to_s
          @_TO_S ||= "#{service_module.name || 'Annonymous'}"
        end
      end
      service_class.new
    end

    def add_routes_for(service_name, service_instance)
      service_instance.remote_methods.each do |method|
        add_route_for(service_name, method, service_instance)
      end
    end

    def add_route_for(service_name, action_name, service_instance)
      path = [service_name, action_name].join('/')
      Combi.logger.info {"New route: #{path} :: #{service_instance}"}
      @routes[path] = service_instance
    end

    # Funny name of a exception used to signal that the requested
    # combination of service and method can not be found.
    #
    # Looked much funnier the first time... (@amuino)
    class UnknownStop < RuntimeError
    end

    def resolve_route(service_name, kind)
      path = [service_name, kind].join('/')
      return @routes[path] if @routes[path]
      Combi.logger.warn {"Service Path #{path} not found"}
      Combi.logger.warn {"routes: #{@routes.keys.inspect}"}
      raise UnknownStop.new(path)
    end

    def invoke_service(service_name, action, params)
      t0 = Time.now
      path = "#{service_name}/#{action}?#{params.inspect}"
      service_instance = resolve_route(service_name.to_s, action)
      # convert keys to symbols in-place
      params.keys.each {|key| params[key.to_sym] = params.delete(key) }
      deferrable = sync_to_async service_instance.send(action, params)
      deferrable.callback &log_service_invocation(true, t0, path)
      deferrable.errback &log_service_invocation(false, t0, path)
      deferrable
    rescue StandardError => e
      Combi.logger.error do
        require 'yaml'
        msg = " *** ERROR INVOKING SERVICE ***" +
              "   - #{e.inspect}" +
              "   - #{service_name} #{service_instance.class.ancestors.join ' > '}" +
              "   - #{action}" +
              "   - #{params.to_yaml.split("\n").join("\n\t")}"
      end
      return sync_to_async error: { klass: e.class.name, message: e.message, backtrace: e.backtrace }
    end

    def sync_to_async(response)
      return response if response.respond_to? :succeed # already a deferrable
      deferrable = EM::DefaultDeferrable.new
      if response.respond_to?(:keys) and response[:error]
        deferrable.fail response[:error]
      else
        deferrable.succeed response
      end
      return deferrable
    end

    def log_service_invocation(success, t0, path)
      Proc.new do |response|
        Combi.logger.info do
          result = success ? 'OK' : 'KO'
          time = '%10.6fs' % (Time.now - t0)
          base_msg = "#{result}\t#{time}\t#{path}"
          base_msg += "\t#{response.inspect}" if success == false
          base_msg
        end
      end
    end

  end
end
