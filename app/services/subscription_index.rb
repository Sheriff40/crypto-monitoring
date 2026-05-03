class SubscriptionIndex
  Rule = Struct.new(:id, :customer_id, :threshold_value, :direction, :triggered, keyword_init: true)

  attr_reader :index

  def initialize
    @index = {}
  end

  def load_from_db
    @index.clear

    SubscriptionRule.find_each do |rule|
      symbol = rule.currency_symbol.upcase
      @index[symbol] ||= []
      @index[symbol] << Rule.new(
        id: rule.id,
        customer_id: rule.customer_id,
        threshold_value: rule.threshold_value,
        direction: rule.direction,
        triggered: false
      )
    end

    Rails.logger.info "[Index] Loaded #{total_rules} rules across #{@index.size} symbols"
  end

  def rules_for(symbol)
    @index[symbol] || []
  end

  def total_rules
    @index.values.sum(&:size)
  end
end
