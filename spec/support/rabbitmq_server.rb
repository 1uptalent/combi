require 'singleton'
# Uses docker to start a server
class RabbitmqServer
  include Singleton

  NAME='combi_rabbit'
  PASSWORD='testpass'

  def start!
    stop! # make sure
    system "docker run -d -P -e RABBITMQ_PASS=#{PASSWORD} -name #{NAME} tutum/rabbitmq"
  end

  def port
    container_line = `docker ps | grep #{NAME}`
    port_match = container_line.match(/:([0-9]+)->5672/)
    if port_match
      return port_match[1]
    else
      puts "Container not running yet, sleeping"
      sleep 0.2
      port
    end
  end

  def stop!
    system "docker stop --time 0 #{NAME}" if `docker ps | grep #{NAME}`.length > 0
    system "docker rm #{NAME}" if `docker ps -a | grep #{NAME}`.length > 0
  end
end
