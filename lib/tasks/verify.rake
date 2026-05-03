namespace :verify do
  desc "Verify alert output against ground truth generated at seed time"
  task :ground_truth, [:expected_file, :alert_log] => :environment do |_t, args|
    expected_file = args[:expected_file] || Dir.glob(Rails.root.join("log", "expected_alerts_*_rules.json")).max
    alert_log     = args[:alert_log]     || Dir.glob(Rails.root.join("log", "alerts_*_rules.log")).max

    abort "No expected alerts file found. Run rake seed:from_trace first." unless expected_file && File.exist?(expected_file)
    abort "No alert log found." unless File.exist?(alert_log)

    expected = JSON.parse(File.read(expected_file))

    actual = Hash.new(0)

    File.foreach(alert_log) do |line|
      parsed = JSON.parse(line) rescue next
      key = "#{parsed["customer_id"]}:#{parsed["symbol"]}"
      actual[key] += 1
    end

    missed     = expected.count { |k, v| actual[k] < v }
    duplicates = actual.count  { |k, v| v > expected.fetch(k, 0) }

    expected_total = expected.values.sum
    actual_total   = actual.values.sum

    puts ""
    puts "===== Ground Truth Verification ====="
    puts "  Expected rules      : #{expected.size}"
    puts "  Expected total alerts: #{expected_total}"
    puts "  Actual total alerts : #{actual_total}"
    puts "  Missed              : #{missed}"
    puts "  Duplicates          : #{duplicates}"
    puts "  Result              : #{missed == 0 && duplicates == 0 ? 'PASS' : 'FAIL'}"
    puts "====================================="
  end
end
