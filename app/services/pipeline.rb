class Pipeline
  def initialize(alert_emitter: nil)
    @parser = MessageParser.new
    @index = SubscriptionIndex.new
    @emitter = alert_emitter || AlertEmitter.new
    @evaluator = RuleEvaluator.new(alert_emitter: @emitter)
    @messages_processed = 0
  end

  def setup
    @index.load_from_db
  end

  def process(raw_json, ingested_at:)
    ticks = @parser.parse(raw_json)
    @messages_processed += 1

    ticks.each do |tick|
      rules = @index.rules_for(tick.symbol)
      next if rules.empty?

      @evaluator.evaluate(tick, rules, ingested_at: ingested_at)
    end
  end
end
