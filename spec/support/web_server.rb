
def start_web_server(http_bus)
  require 'eventmachine'
  require 'rack'
  require 'thin'

  app = lambda do |env|
    http_bus.manage_request(env)
  end

  pid = fork do
    EM.error_handler do |error|
      puts "\tERROR"
      puts "\t#{error.inspect}"
      puts error.backtrace
    end
    EM.run do
      thin = Rack::Handler.get('thin')
      thin.run(app, :Port => 9292)
    end
    puts "Web server stopped"
  end
  puts "Started web server with pid: #{pid}"
  pid
end

def stop_web_server(pid)
  puts "Stopping web server with pid: #{pid}"
  Process.kill "KILL", pid
end
