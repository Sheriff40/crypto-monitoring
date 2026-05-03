require "faye/websocket"
require "eventmachine"

namespace :trace do
  desc "Record live Binance miniTicker messages to a trace file"
  task :record, [:duration] => :environment do |_t, args|
    duration = (args[:duration] || 60).to_i
    timestamp = Time.now.strftime("%Y%m%d_%H%M%S")
    trace_path = Rails.root.join("traces", "trace_#{timestamp}.jsonl")

    puts "Recording Binance miniTicker stream for #{duration}s..."
    puts "Output: #{trace_path}"

    FileUtils.mkdir_p(Rails.root.join("traces"))
    message_count = 0

    EM.run do
      ws = Faye::WebSocket::Client.new(MarketIngestion::BINANCE_WS_URL)
      file = File.open(trace_path, "w")

      ws.on :open do |_event|
        puts "Connected to Binance. Recording..."
      end

      ws.on :message do |event|
        recorded_at = Process.clock_gettime(Process::CLOCK_MONOTONIC)
        file.puts({ recorded_at:, data: event.data }.to_json)
        message_count += 1
        print "\rMessages recorded: #{message_count}" if message_count % 10 == 0
      end

      ws.on :close do |event|
        puts "\nConnection closed (code: #{event.code})"
      end

      EM.add_timer(duration) do
        file.close
        puts "\nRecording complete. #{message_count} messages saved to #{trace_path}"
        EM.stop
      end
    end
  end
end
