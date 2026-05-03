require "faye/websocket"
require "eventmachine"

class MarketIngestion
  BINANCE_WS_URL = "wss://stream.binance.com:9443/ws/!miniTicker@arr"

  def initialize(pipeline:)
    @pipeline = pipeline
  end

  def start
    EM.run do
      ws = Faye::WebSocket::Client.new(BINANCE_WS_URL)

      ws.on :open do |_event|
        Rails.logger.info "[Ingestion] Connected to Binance miniTicker stream"
      end

      ws.on :message do |event|
        ingested_at = Process.clock_gettime(Process::CLOCK_MONOTONIC)
        @pipeline.process(event.data, ingested_at: ingested_at)
      end

      ws.on :close do |event|
        Rails.logger.warn "[Ingestion] Connection closed (code: #{event.code})"
      end

      ws.on :error do |event|
        Rails.logger.error "[Ingestion] WebSocket error: #{event.message}"
      end
    end
  end

  def stop
    EM.stop if EM.reactor_running?
  end
end
