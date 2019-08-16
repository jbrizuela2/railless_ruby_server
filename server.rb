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
    @headers["Date"] = DateTime.now.new_offset(0).strftime("%a, %e %b %Y %k:%M:%S GMT")
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

class StaticResource
  attr_reader :base_path, :default_document, :files

  MIME_TYPES = {
    "hmtl": "text/html",
    "css": "text/css",
    "gif": "image/gif",
    "jpg": "image.jpg",
    "jpeg": "image/jpeg",
    "js": "text/javascript",
    "json": "application/json"
  }.freeze

  BINARY_TYPES = ["gif", "jpg", "jpeg", "png"].freeze

  def initialize(base_path: , default_document:)
    @base_path = base_path
    @default_document = default_document
    @files = []
  end

  def exists?(resource)
    path = resource_path(resource)
    return path true if @files.include?(path)

    if File.exists?(path)
      @files.push(path)
      return true
    end

    false
  end

  def load(resource)
    path = resource_path(resource)
    extension = File.extname(path).sub(".", "").downcase
    
    if BINARY_TYPES.include?(extension)
      File.binread(path)
    else
      File.read(path)
    end
  end
  
  def mime_type(resource)
    path = resource_path(resource)
    extension = File.extname(path).sub(".", "").downcase

    MIME_TYPES[:"#{extension}"] || "text/#{extension}"
  end

  private

  def resource_path(resource)
    clean_resource = resource.gsub("../", "").split("?")[0]
    clean_resource = default_document if clean_resource == "/"

    File.join(base_path, clean_resource)
  end
end




ROOT = __dir__
DEFAULT_DOCUMENT = "index.html"
PUBLIC_PATH = File.join(ROOT, "public")

host = ENV["BIND_ADDRESS"] || "localhost"
port = ENV["PORT"] ? ENV["PORT"].to_i : 2345

server = TCPServer.new(host, port)
STDERR.puts "Starting server at #{host}:#{port}"

static_resource = StaticResource.new(base_path: PUBLIC_PATH, default_document: DEFAULT_DOCUMENT)

loop do
  session = server.accept
  request = Request.new(session)

  STDERR.puts "#{request.verb} #{request.path}"
  request.headers.each {|header, value| STDERR.puts "#{header}: #{value}" }
  STDERR.puts "Data: #{request.data}"

  STDERR.puts "------------------"

  data = "Not found"
  status = 404
  headers = { "Server": "Ruby Server" }

  if static_resource.exists?(request.path)
    status = 200
    data = static_resource.load(request.path)
    content_type = static_resource.mime_type(request.path)
    headers[:"Content-Type"] = content_type
  end

  response = Response.new(status: status, headers: headers, response: data)
  session.print(response.render)

  session.close
end
