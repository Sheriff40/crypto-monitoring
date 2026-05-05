require "csv"

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

    accuracy = expected_total > 0 ? (actual_total.to_f / expected_total * 100).round(2) : 0
    result   = missed == 0 && duplicates == 0 ? "PASS" : "FAIL"
    rules    = File.basename(expected_file.to_s).match(/(\d+)_rules/)&.captures&.first

    puts ""
    puts "===== Ground Truth Verification ====="
    puts "  Expected rules      : #{expected.size}"
    puts "  Expected total alerts: #{expected_total}"
    puts "  Actual total alerts : #{actual_total}"
    puts "  Missed              : #{missed}"
    puts "  Duplicates          : #{duplicates}"
    puts "  Accuracy            : #{accuracy}%"
    puts "  Result              : #{result}"
    puts "====================================="

    csv_path = Rails.root.join("log", "verify_results.csv")
    write_header = !File.exist?(csv_path)
    CSV.open(csv_path, "a") do |csv|
      csv << %w[timestamp rules expected_alerts actual_alerts missed duplicates accuracy_pct result] if write_header
      csv << [Time.now.iso8601, rules, expected_total, actual_total, missed, duplicates, accuracy, result]
    end
    puts "[CSV] Verification results appended to #{csv_path}"
  end
end
