require "socket"

class Request
  attr_reader :headers, :verb, :path, :data

  def initialize(session)
    metadata = []
    while (request = session.gets) && (request.chomp.length > 0)
      metadata << request
    end

    build_resource(metadata.shift)
    build_headers(metadata)
    read_data(session)

  end
  
  private
  
  def read_data(session)
    data_length = headers["Content-Length"].to_i
    if data_length > 0
      @data = session.read(data_length)
    end
  end
  
  def build_headers(lines)
    headers = lines.map{|line| line.split(": ")}
    @headers = headers.to_h
  end
  
  def build_resource(line)
    @verb, @path, _ = line.split(" ")
  end
end

host = ENV["BIND_ADDRESS"] || "localhost"
port = ENV["PORT"] ? ENV["PORT"].to_i : 2345

server = TCPServer.new(host, port)
STDERR.puts "Starting server at #{host}:#{port}"

loop do
  session = server.accept
  request = Request.new(session)

  STDERR.puts "#{request.verb} #{request.path}"
  request.headers.each {|header, value| STDERR.puts "#{header}: #{value}" }
  STDERR.puts "Data: #{request.data}"

  STDERR.puts "------------------"

  response = "Hola desde Ruby\n"
  session.print <<~RESPONSE
  HTTP/1.1 200 OK
  Content-Type: text/plain
  Content-Length: #{response.bytesize}
  Connection: close
  RESPONSE

  session.print "\r\n"
  session.print response

  session.close
end
