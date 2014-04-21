$:.push File.expand_path('../lib', __FILE__)
require 'combi/version'

Gem::Specification.new do |s|
  s.name        = 'combi'
  s.version     = Combi::VERSION
  s.summary     = "Mini Bus for microservices"
  s.description = "Provides implementation for in process, amqp or web socket service bus"
  s.authors     = ["German Del Zotto"]
  s.email       = 'germ@ndz.com.ar'
  s.files       = ["lib/combi.rb"]
  s.homepage    = 'http://rubygems.org/gems/combi'
  s.license     = 'MIT'
  s.add_dependency 'yajl-ruby', '~> 1.2.0'
  s.add_development_dependency 'rspec-given', '~> 3.5.4'
  s.add_development_dependency 'amqp', '~> 1.3.0'
  s.add_development_dependency 'faye-websocket', '~> 0.7.2'
end
