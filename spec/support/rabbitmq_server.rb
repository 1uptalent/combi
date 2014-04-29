require 'singleton'
require 'socket'
require 'timeout'
# Uses docker to start a server
class RabbitmqServer
  include Singleton

  NAME='combi_rabbit'
  PASSWORD='testpass'

  def start!
    needs_to_start = !container_running?
    if needs_to_start
      puts "Starting new Rabbitmq container"
      system "docker run -d -P -e RABBITMQ_PASS=#{PASSWORD} --name #{NAME} tutum/rabbitmq"
      puts "RABBITMQ STARTING"
    end
    start_forwarder!
    is_port_open?('localhost', port)
    return needs_to_start
  end

  def stop!
    system "docker stop --time 0 #{NAME}" if container_running?
    system "docker rm #{NAME}" if container_exists?
    stop_forwarder!
  end

  def start_forwarder!
    @forwarder_pid = Process.spawn '/usr/local/bin/boot2docker', 'ssh', '-L',  "#{port}:localhost:#{port}", '-N'
    #Process.detach @forwarder_pid
    puts "starting forwarder pid: #{@forwarder_pid}"
  end

  def stop_forwarder!
    puts "stopping forwarder pid #{@forwarder_pid}"
    Process.kill 'TERM', @forwarder_pid if @forwarder_pid
  rescue Error::ESRCH => e
    # the forwarder process has already died
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

  def is_port_open?(ip, port, timeout = 15)
    begin
      Timeout::timeout(timeout) do
        begin
          s = TCPSocket.new(ip, port)
          s.close
          return true
        rescue Errno::ECONNREFUSED, Errno::EHOSTUNREACH
          puts "conn error to rabbit @ #{ip}##{port}"
          sleep 1
          retry
        end
      end
    rescue Timeout::Error
      puts "Cannot connect to RABBIT server after #{timeout} seconds"
    end

    return false
  end

  def container_running?
    `docker ps | grep #{NAME}`.length > 0
  end

  def container_exists?
    `docker ps -a | grep #{NAME}`.length > 0
  end
end
