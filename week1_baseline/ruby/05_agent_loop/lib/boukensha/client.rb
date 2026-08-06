require "net/http"
require "json"
require "openssl"

module Boukensha
  # The only thing this class does is make the HTTP call: build the request
  # from what the builder already assembled, send it, retry on transient
  # failure, parse the JSON body. It has no idea what a tool or a message is.
  class Client
    RETRYABLE_STATUS_CODES = [408, 409, 429, 500, 502, 503, 504].freeze
    TRANSIENT_ERRORS = [
      EOFError,
      Errno::ECONNRESET,
      Errno::ECONNREFUSED,
      Net::OpenTimeout,
      Net::ReadTimeout,
      OpenSSL::SSL::SSLError,
      SocketError,
      Timeout::Error
    ].freeze
    MAX_RETRIES = 3
    BASE_RETRY_DELAY = 0.5

    # base_retry_delay is only a constructor arg so tests can run the retry
    # path without real sleeps. Production call sites never pass it.
    def initialize(builder, base_retry_delay: BASE_RETRY_DELAY)
      @builder = builder
      @base_retry_delay = base_retry_delay
    end

    def call(max_output_tokens: 1024, tools: nil)
      uri  = URI(@builder.url)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = uri.scheme == "https"
      http.verify_mode = OpenSSL::SSL::VERIFY_PEER

      request = Net::HTTP::Post.new(uri, @builder.headers)
      request.body = @builder.to_api_payload(max_output_tokens: max_output_tokens, tools: tools).to_json

      response = request_with_retries(http, request)

      unless response.is_a?(Net::HTTPSuccess)
        raise ApiError, "API request failed (#{response.code}): #{response.body}"
      end

      JSON.parse(response.body)
    end

    private

    def request_with_retries(http, request)
      attempts = 0

      loop do
        attempts += 1
        begin
          response = http.request(request)
        rescue *TRANSIENT_ERRORS => e
          raise ApiError, "API request failed after #{attempts} attempts: #{e.class}: #{e.message}" if attempts > MAX_RETRIES

          sleep(retry_delay(attempts))
          next
        end

        return response unless retryable_response?(response) && attempts <= MAX_RETRIES

        sleep(retry_delay(attempts))
      end
    end

    def retryable_response?(response)
      RETRYABLE_STATUS_CODES.include?(response.code.to_i)
    end

    def retry_delay(attempt)
      @base_retry_delay * (2**(attempt - 1))
    end
  end
end
