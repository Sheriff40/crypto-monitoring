require "csv"

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
    throughput = (pipeline.ticks_processed / wall_elapsed).round(2)

    puts ""
    puts "===== Benchmark Results: #{label} ====="
    puts "  Messages processed : #{pipeline.messages_processed}"
    puts "  Wall time          : #{wall_elapsed.round(2)}s"
    puts "  Throughput         : #{throughput} ticks/s"
    puts "  Alerts fired       : #{emitter.alert_count}"
    puts "  Latency p50        : #{p50} ms"
    puts "  Latency p95        : #{p95} ms"
    puts "  Latency p99        : #{p99} ms"
    puts "  CPU utilisation    : #{cpu_utilisation}%"
    puts "======================================="

    csv_path = Rails.root.join("log", "benchmark_results.csv")
    write_header = !File.exist?(csv_path)
    CSV.open(csv_path, "a") do |csv|
      csv << %w[timestamp type rules messages throughput_ticks_s alerts p50_ms p95_ms p99_ms cpu_pct trace] if write_header
      csv << [Time.now.iso8601, "steady", rule_count, pipeline.messages_processed, throughput, emitter.alert_count, p50, p95, p99, cpu_utilisation, File.basename(trace_file)]
    end
    puts "[CSV] Results appended to #{csv_path}"
  end

  desc "Run burst injection benchmark at a fixed rule count"
  task :burst, [:trace_file, :burst_size, :label] => :environment do |_t, args|
    trace_file = args[:trace_file] || Dir.glob(Rails.root.join("traces", "*.jsonl")).max
    burst_size = (args[:burst_size] || 20).to_i
    label      = args[:label] || "burst_rules=#{SubscriptionRule.count}"

    abort "No trace file found." unless trace_file && File.exist?(trace_file)

    total_messages = File.readlines(trace_file).size
    burst_at = [0, total_messages / 2]

    rule_count = SubscriptionRule.count
    log_path   = Rails.root.join("log", "alerts_burst_#{rule_count}_rules.log")

    emitter  = AlertEmitter.new(log_path: log_path)
    pipeline = Pipeline.new(alert_emitter: emitter)
    pipeline.setup

    puts "[Benchmark] #{label} | rules=#{rule_count} | burst_size=#{burst_size} | burst_at=#{burst_at.inspect}"
    puts "[Benchmark] Alert log: #{log_path}"

    replayer = TraceReplayer.new(pipeline: pipeline, burst_at: burst_at, burst_size: burst_size)

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
    throughput = (pipeline.ticks_processed / wall_elapsed).round(2)

    puts ""
    puts "===== Burst Benchmark Results: #{label} ====="
    puts "  Messages processed : #{pipeline.messages_processed}"
    puts "  Burst windows      : #{burst_at.map { |s| "#{s}–#{s + burst_size - 1}" }.join(', ')}"
    puts "  Burst size         : #{burst_size} messages per window"
    puts "  Schedule misses    : #{replayer.schedule_misses}"
    puts "  Wall time          : #{wall_elapsed.round(2)}s"
    puts "  Throughput         : #{throughput} ticks/s"
    puts "  Alerts fired       : #{emitter.alert_count}"
    puts "  Latency p50        : #{p50} ms"
    puts "  Latency p95        : #{p95} ms"
    puts "  Latency p99        : #{p99} ms"
    puts "  CPU utilisation    : #{cpu_utilisation}%"
    puts "============================================="

    csv_path = Rails.root.join("log", "benchmark_results.csv")
    write_header = !File.exist?(csv_path)
    CSV.open(csv_path, "a") do |csv|
      csv << %w[timestamp type rules messages throughput_ticks_s alerts p50_ms p95_ms p99_ms cpu_pct trace] if write_header
      csv << [Time.now.iso8601, "burst", rule_count, pipeline.messages_processed, throughput, emitter.alert_count, p50, p95, p99, cpu_utilisation, File.basename(trace_file)]
    end
    puts "[CSV] Results appended to #{csv_path}"
  end

  private

  def percentile(sorted, pct)
    return nil if sorted.empty?
    idx = ((pct / 100.0) * (sorted.size - 1)).round
    sorted[idx].round(3)
  end
end
