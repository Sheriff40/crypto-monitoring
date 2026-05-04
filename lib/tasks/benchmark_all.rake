namespace :benchmark do
  desc "Run full benchmark suite across rule scaling scenarios"
  task :all, [:trace_file] => :environment do |_t, args|
    trace_file = args[:trace_file] || Dir.glob(Rails.root.join("traces", "*.jsonl")).max
    abort "No trace file found." unless trace_file && File.exist?(trace_file)

    [100, 500, 1000, 2500, 5000].each do |rule_count|
      expected_file = Rails.root.join("log", "expected_alerts_#{rule_count}_rules.json")
      alert_log     = Rails.root.join("log", "alerts_#{rule_count}_rules.log")

      puts ""
      puts "##################################################"
      puts "# SCENARIO: #{rule_count} rules"
      puts "##################################################"

      ActiveRecord::Base.connection.clear_query_cache

      Rake::Task["seed:from_trace"].reenable
      Rake::Task["seed:from_trace"].invoke(trace_file, rule_count)

      Rake::Task["benchmark:run"].reenable
      Rake::Task["benchmark:run"].invoke(trace_file, "rules=#{rule_count}")

      Rake::Task["verify:ground_truth"].reenable
      Rake::Task["verify:ground_truth"].invoke(expected_file, alert_log)
    end

    puts ""
    puts "##################################################"
    puts "# ALL SCENARIOS COMPLETE"
    puts "##################################################"
  end
end
