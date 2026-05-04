class TraceReplayer
  def initialize(pipeline:, burst_at: [], burst_size: 0)
    @pipeline   = pipeline
    @burst_at   = burst_at
    @burst_size = burst_size
  end

  attr_reader :schedule_misses

  def replay(trace_path)
    lines = File.readlines(trace_path)
    total = lines.size
    previous_recorded_at = nil
    burst_start_time     = nil
    @schedule_misses     = 0

    Rails.logger.info "[Replay] Starting replay of #{total} messages"

    lines.each_with_index do |line, i|
      record = JSON.parse(line)
      current_recorded_at = record["recorded_at"]

      if burst_window_start?(i)
        burst_start_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      end

      ingested_at = in_burst?(i) ? burst_start_time : Process.clock_gettime(Process::CLOCK_MONOTONIC)

      @pipeline.process(record["data"], ingested_at: ingested_at)
      processing_time = Process.clock_gettime(Process::CLOCK_MONOTONIC) - ingested_at

      if previous_recorded_at && !in_burst?(i)
        delay = (current_recorded_at - previous_recorded_at) - processing_time
        if delay > 0
          sleep(delay)
        else
          @schedule_misses += 1
        end
      end

      previous_recorded_at = current_recorded_at

      print "\r[Replay] Processed #{i + 1}/#{total} messages" if (i + 1) % 10 == 0
    end

    puts "\n[Replay] Complete. #{total} messages replayed."
  end

  private

  def in_burst?(index)
    @burst_at.any? { |start| index >= start && index < start + @burst_size }
  end

  def burst_window_start?(index)
    @burst_at.include?(index)
  end
end
