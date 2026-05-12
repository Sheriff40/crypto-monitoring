namespace :seed do
  desc "Generate subscription rules from a trace file that are guaranteed to trigger"
  task :from_trace, [:trace_file, :rule_count] => :environment do |_t, args|
    trace_file = args[:trace_file] || Dir.glob(Rails.root.join("traces", "*.jsonl")).max
    rule_count = (args[:rule_count] || 100).to_i

    abort "No trace file found." unless trace_file && File.exist?(trace_file)

    puts "Analyzing trace: #{trace_file}"

    symbol_prices = Hash.new { |h, k| h[k] = [] }

    File.foreach(trace_file) do |line|
      record = JSON.parse(line)
      tickers = JSON.parse(record["data"])
      tickers.each do |t|
        symbol_prices[t["s"]] << BigDecimal(t["c"])
      end
    end

    puts "Found #{symbol_prices.size} symbols in trace"

    # only create rules for symbols which have price movements
    # Reason: A symbol without any movement in the market will never trigger any rule
    triggerable_symbols = symbol_prices.select { |_sym, prices| prices.uniq.size > 1 }

    puts "#{triggerable_symbols.size} symbols have price movement"
    abort "No price movement found in trace. Record a longer trace." if triggerable_symbols.empty?

    SubscriptionRule.delete_all

    rules = []
    symbols = triggerable_symbols.keys.sort
    rule_id = 0

    while rules.size < rule_count
      symbols.each do |symbol|
        break if rules.size >= rule_count

        prices = symbol_prices[symbol]
        min_price = prices.min
        max_price = prices.max
        range = max_price - min_price
        offset = rand(0.2..0.8)
        threshold = min_price + (range * offset)
        direction = rule_id.even? ? "above" : "below"

        rules << {
          customer_id: "customer_#{rule_id + 1}",
          currency_symbol: symbol,
          threshold_value: threshold.round(8),
          direction: SubscriptionRule.directions[direction],
          created_at: Time.current,
          updated_at: Time.current
        }

        rule_id += 1
      end
    end

    SubscriptionRule.insert_all(rules)

    # setup the deterministic ground truth
    # store the expected alerts per symbol

    expected_alerts = Hash.new(0)

    rules.each do |rule|
      prices = symbol_prices[rule[:currency_symbol]]
      direction = SubscriptionRule.directions.key(rule[:direction])
      threshold = rule[:threshold_value]
      triggered = false

      prices.each do |price|
        crossed = case direction
                  when "above" then price >= threshold
                  when "below" then price <= threshold
                  else false
                  end

        if crossed && !triggered
          triggered = true
          expected_alerts["#{rule[:customer_id]}:#{rule[:currency_symbol]}"] += 1
        elsif !crossed && triggered
          triggered = false
        end
      end
    end

    expected_path = Rails.root.join("log", "expected_alerts_#{rule_count}_rules.json")
    File.write(expected_path, expected_alerts.to_json)

    above_count = rules.count { |r| r[:direction] == SubscriptionRule.directions["above"] }
    below_count = rules.count { |r| r[:direction] == SubscriptionRule.directions["below"] }

    puts ""
    puts "Seeded #{rules.size} rules:"
    puts "  Above: #{above_count}"
    puts "  Below: #{below_count}"
    puts "  Symbols covered: #{rules.map { |r| r[:currency_symbol] }.uniq.size}"
    puts "  Expected alerts written to: #{expected_path}"
  end
end
