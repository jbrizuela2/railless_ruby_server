require "socket"
require "date"

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

class Response
  attr_reader :status, :headers, :response

  DEFAULT_HEADERS = {
    "Content-Type": "text/plain",
    "Connection": "close"
  }.freeze

  def initialize(status: 200, headers: {}, response: "")
    @status = status
    @headers = DEFAULT_HEADERS.merge(headers)
    @headers["Content-Length"] = response.bytesize
    @response = response
  end

  def render
    data = ["HTTP/1.1 #{status} OK"]
    data = (data + headers.map{|header, value| "#{headers}: #{value }"}).uniq
    data.push("")
    data.push(response)

    data.join("\r\n")
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

  data = "Hola desde Ruby"
  
  response = Response.new(response: data)
  session.print(response.render)

  session.close
end
