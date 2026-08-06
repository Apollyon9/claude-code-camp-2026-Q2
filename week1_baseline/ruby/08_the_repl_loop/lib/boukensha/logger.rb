require "json"
require "fileutils"
require "securerandom"
require "time"

module Boukensha
  # Writes one JSONL file per session: dir/<session_id>.jsonl. Every public
  # method appends exactly one line -- a phase name plus whatever belongs to
  # that phase, plus session_id and a timestamp on every line. Meant to be
  # grepped and tailed, not read as a document; log_viz (the provided
  # Sinatra app) is what turns this into something human-readable.
  #
  # dir: is required rather than defaulted from Config, so constructing a
  # Logger never has the hidden side effect of loading .env / settings.yaml
  # just to find out where to write. The caller already knows its config
  # dir by the time it needs a Logger.
  class Logger
    attr_reader :session_id, :path

    def initialize(dir:, session_id: nil, snapshot: {})
      @session_id = session_id || generate_session_id
      @path       = File.join(dir, "#{@session_id}.jsonl")
      FileUtils.mkdir_p(dir)
      @log_io = File.open(@path, "a")
      write_log({phase: "session_start"}.merge(snapshot))
    end

    def iteration(n:, max:)
      write_log(phase: "iteration", n: n, max: max)
    end

    def tool_call(name:, args:)
      write_log(phase: "tool_call", name: name, args: args)
    end

    def tool_result(name:, result:, ok: true, error: nil)
      write_log(phase: "tool_result", name: name, result: result.to_s, ok: ok, error: error)
    end

    def response(text:, stop_reason: nil)
      write_log(phase: "response", text: text.to_s.strip, stop_reason: stop_reason)
    end

    def limit_reached(kind:, n:, max:)
      write_log(phase: "limit_reached", kind: kind, n: n, max: max)
    end

    def turn_end(reason:, iterations:)
      write_log(phase: "turn_end", reason: reason, iterations: iterations)
    end

    def close
      @log_io&.close
    end

    private

    def write_log(event)
      @log_io.puts JSON.generate(event.merge(session_id: @session_id, at: Time.now.iso8601))
      @log_io.flush
    end

    def generate_session_id
      "#{Time.now.utc.strftime('%Y%m%dT%H%M%SZ')}-#{SecureRandom.hex(4)}"
    end
  end
end
