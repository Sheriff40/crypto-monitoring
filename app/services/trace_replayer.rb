class TraceReplayer
  def initialize(pipeline:, rate: 1.0)
    @pipeline = pipeline
    @rate = rate.to_f
  end

  attr_reader :backpressure_events

  def replay(trace_path)
    lines = File.readlines(trace_path)
    total = lines.size
    previous_recorded_at = nil
    @backpressure_events = 0

    Rails.logger.info "[Replay] Starting replay of #{total} messages at #{@rate}x rate"

    lines.each_with_index do |line, i|
      record = JSON.parse(line)
      current_recorded_at = record["recorded_at"]

      ingested_at = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      @pipeline.process(record["data"], ingested_at: ingested_at)
      processing_time = Process.clock_gettime(Process::CLOCK_MONOTONIC) - ingested_at

      if previous_recorded_at
        delay = (current_recorded_at - previous_recorded_at) / @rate - processing_time
        if delay > 0
          sleep(delay)
        else
          @backpressure_events += 1
        end
      end

      previous_recorded_at = current_recorded_at

      print "\r[Replay] Processed #{i + 1}/#{total} messages" if (i + 1) % 10 == 0
    end

    puts "\n[Replay] Complete. #{total} messages replayed at #{@rate}x rate."
  end
end
