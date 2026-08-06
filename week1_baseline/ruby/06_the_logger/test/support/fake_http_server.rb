require "socket"

# A minimal raw HTTP/1.1 server for exercising Client's real Net::HTTP path
# end to end, without a mocking gem and without touching the network. Queue
# up raw response strings; each accepted connection gets the next one off
# the queue and the full request (line, headers, body) gets recorded so a
# test can assert on exactly what Client sent.
class FakeHttpServer
  Request = Struct.new(:request_line, :headers, :body)

  attr_reader :requests

  def initialize(responses)
    @responses = responses.dup
    @requests  = []
    @server    = TCPServer.new("127.0.0.1", 0)
    @thread    = Thread.new { run }
  end

  def port
    @server.addr[1]
  end

  def close
    @thread.kill
    @server.close
  end

  def self.response(status:, body: "")
    "HTTP/1.1 #{status} status\r\n" \
      "Content-Type: application/json\r\n" \
      "Content-Length: #{body.bytesize}\r\n" \
      "Connection: close\r\n\r\n#{body}"
  end

  private

  def run
    until @responses.empty?
      client = @server.accept
      @requests << read_request(client)
      client.write(@responses.shift)
      client.close
    end
  rescue IOError, Errno::EBADF
    # Server closed (thread killed during test teardown) while blocked in
    # accept -- expected, not a real failure.
  end

  def read_request(client)
    request_line = client.gets
    headers = {}
    while (line = client.gets) && line != "\r\n"
      key, value = line.split(":", 2)
      headers[key.strip.downcase] = value.strip
    end
    length = headers["content-length"].to_i
    body = length.positive? ? client.read(length) : ""
    Request.new(request_line, headers, body)
  end
end
