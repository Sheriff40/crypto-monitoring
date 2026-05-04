namespace :benchmark do
  desc "Run replay benchmark at a given rule count label"
  task :run, [:trace_file, :label] => :environment do |_t, args|
    trace_file = args[:trace_file] || Dir.glob(Rails.root.join("traces", "*.jsonl")).max
    label      = args[:label] || "rules=#{SubscriptionRule.count}"

    abort "No trace file found." unless trace_file && File.exist?(trace_file)

    rule_count = SubscriptionRule.count
    log_path   = Rails.root.join("log", "alerts_#{rule_count}_rules.log")

    emitter  = AlertEmitter.new(log_path: log_path)
    pipeline = Pipeline.new(alert_emitter: emitter)
    pipeline.setup

    puts "[Benchmark] #{label} | rules=#{rule_count} | trace=#{File.basename(trace_file)}"
    puts "[Benchmark] Alert log: #{log_path}"

    replayer = TraceReplayer.new(pipeline: pipeline)

    cpu_before = Process.times
    wall_start = Process.clock_gettime(Process::CLOCK_MONOTONIC)

    replayer.replay(trace_file)

    wall_elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - wall_start
    cpu_after    = Process.times

    cpu_seconds     = (cpu_after.utime - cpu_before.utime) + (cpu_after.stime - cpu_before.stime)
    cpu_utilisation = (cpu_seconds / wall_elapsed * 100).round(1)

    latencies  = emitter.latencies.sort
    p50        = percentile(latencies, 50)
    p95        = percentile(latencies, 95)
    p99        = percentile(latencies, 99)
    throughput = (pipeline.messages_processed / wall_elapsed).round(2)

    puts ""
    puts "===== Benchmark Results: #{label} ====="
    puts "  Messages processed : #{pipeline.messages_processed}"
    puts "  Wall time          : #{wall_elapsed.round(2)}s"
    puts "  Throughput         : #{throughput} msg/s"
    puts "  Alerts fired       : #{emitter.alert_count}"
    puts "  Latency p50        : #{p50} ms"
    puts "  Latency p95        : #{p95} ms"
    puts "  Latency p99        : #{p99} ms"
    puts "  CPU utilisation    : #{cpu_utilisation}%"
    puts "======================================="
  end

  private

  def percentile(sorted, pct)
    return nil if sorted.empty?
    idx = ((pct / 100.0) * (sorted.size - 1)).round
    sorted[idx].round(3)
  end
end
