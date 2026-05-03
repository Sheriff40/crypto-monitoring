class RuleEvaluator
  def initialize(alert_emitter:)
    @alert_emitter = alert_emitter
  end

  def evaluate(tick, rules, ingested_at:)
    rules.each do |rule|
      triggered_now = threshold_crossed?(tick.price, rule.threshold_value, rule.direction)

      if triggered_now && !rule.triggered
        rule.triggered = true
        @alert_emitter.emit(rule:, tick:, ingested_at:)
      elsif !triggered_now && rule.triggered
        rule.triggered = false
      end
    end
  end

  private

  def threshold_crossed?(price, threshold, direction)
    case direction
    when "below" then price <= threshold
    when "above" then price >= threshold
    else false
    end
  end
end
