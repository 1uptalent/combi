combi: A mini bus for micro services
====================================

![A Volkswagen Combi](http://upload.wikimedia.org/wikipedia/commons/thumb/a/af/Volkswagen-rapunzel.jpg/640px-Volkswagen-rapunzel.jpg)

###Implemented buses

- In Process: for testing or fast running implementations
- Web Sockets: for remote (may be behind proxy) clients
- Queue: for inter server communications (based on AMQP)
- HTTP: for consumer only services (not session, stateless). Probably will work in any TCP capable network

## Disclaimer

This is a work in progress. Expect serious refactors, breaking changes.

## How to use

###Server

Define a new service:
```
module Service
  module Salutation

    def actions
      [:salute]
    end

    def say_hello(params)
      "hello #{params['name']}"
    end

  end
end
```
Launch the server (web sockets):
```
require 'combi'
require 'combi/reactor'
require 'em-websocket'

Combi::Reactor.start
bus = Combi::ServiceBus.for(:web_socket)
bus.start!
bus.add_service(Service::Salutation)

ws_handler = Class.new do
  def new_session(arg); end
end.new

port = 9292
EM::next_tick do
  EM::WebSocket.start(host: '0.0.0.0', port: port) do |ws|
    bus.manage_ws_event(ws, ws_handler)
  end
end
Combi::Reactor.join_thread
```

###Client
Launch the client (web sockets):
```
require 'combi'
require 'combi/reactor'
Combi::Reactor.start

ws_handler = Class.new do
  def on_open; end
end.new

port = 9292
bus = Combi::ServiceBus.for(:web_socket, remote_api: "ws://localhost:#{port}/", handler: ws_handler)
bus.start!

request = bus.request(:salute, :say_hello, {name: 'world'}) # :salute is the name of action declared in service
request.callback do |response|
  puts "Server says: #{response}"
end

Combi::Reactor.join_thread
```

## Testing

`rspec`, the integration suite, test services requesting other services through other buses (compisition).

For AMQP buses, a RabbitMQ server is required. We provide a setup/teardown based in docker.

OSX users, you will need docker and boot2docker installed.
Linux users, you will need docker installed, and make some adjustments to spec/support/rabbitmq_server.rb (the ssh tunnel is not needed)

##Contributors

[Abel Muino](https://twitter.com/amuino)
[German DZ](https://twitter.com/GermanDZ)

## License

MIT License.
