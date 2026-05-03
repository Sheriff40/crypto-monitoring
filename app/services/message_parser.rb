class MessageParser
  Tick = Struct.new(:symbol, :price, keyword_init: true)

  def parse(raw_json)
    tickers = JSON.parse(raw_json)
    tickers.map do |t|
      Tick.new(symbol: t["s"], price: BigDecimal(t["c"]))
    end
  rescue JSON::ParserError => e
    Rails.logger.error "[Parser] Failed to parse message: #{e.message}"
    []
  end
end
