require 'logger'

module Combi
  def self.logger
    @logger ||= create_logger
  end

  def self.logger=(logger)
    @logger = logger
  end

  protected

  def self.create_logger
    if ENV['LOG_LEVEL'] and Logger::Severity.const_defined?(ENV['LOG_LEVEL'])
      severity = Logger::Severity.const_get(ENV['LOG_LEVEL'])
    elsif ENV['LOG_LEVEL'] == 'NONE'
      severity = Logger::Severity::UNKNOWN
    elsif ENV['DEBUG'] == 'true'
      severity = Logger::Severity::DEBUG
    else
      severity = Logger::Severity::INFO
    end
    logger = Logger.new(STDOUT)
    logger.level = severity
    return logger
  end
end
require 'combi/version'
require 'combi/service_bus'
