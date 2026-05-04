class TraceReplayer
  def initialize(pipeline:)
    @pipeline = pipeline
  end

  def replay(trace_path)
    lines = File.readlines(trace_path)
    total = lines.size
    previous_recorded_at = nil

    Rails.logger.info "[Replay] Starting replay of #{total} messages"

    lines.each_with_index do |line, i|
      record = JSON.parse(line)
      current_recorded_at = record["recorded_at"]

      ingested_at = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      @pipeline.process(record["data"], ingested_at: ingested_at)
      processing_time = Process.clock_gettime(Process::CLOCK_MONOTONIC) - ingested_at

      if previous_recorded_at
        delay = (current_recorded_at - previous_recorded_at) - processing_time
        sleep(delay) if delay > 0
      end

      previous_recorded_at = current_recorded_at

      print "\r[Replay] Processed #{i + 1}/#{total} messages" if (i + 1) % 10 == 0
    end

    puts "\n[Replay] Complete. #{total} messages replayed."
  end
end
