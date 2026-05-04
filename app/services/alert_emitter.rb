class AlertEmitter
  attr_reader :alert_count, :latencies

  def initialize(log_path: nil)
    @log_path = log_path || Rails.root.join("log", "alerts.log")
    file      = File.open(@log_path, "w")
    file.sync = true
    @logger   = Logger.new(file)
    @logger.formatter = proc { |_sev, _time, _prog, msg| "#{msg}\n" }
    @alert_count = 0
    @latencies = []
  end

  def emit(rule:, tick:, ingested_at:)
    emitted_at = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    latency_ms = ((emitted_at - ingested_at) * 1000).round(3)
    @alert_count += 1
    @latencies << latency_ms

    @logger.info({
      alert_id: @alert_count,
      customer_id: rule.customer_id,
      symbol: tick.symbol,
      price: tick.price.to_f,
      threshold: rule.threshold_value.to_f,
      direction: rule.direction,
      ingested_at: ingested_at,
      emitted_at: emitted_at,
      latency_ms: latency_ms
    }.to_json)
  end

  def reset_stats
    @alert_count = 0
    @latencies = []
  end
end
