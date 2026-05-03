namespace :pipeline do
  desc "Run live pipeline against real Binance stream"
  task live: :environment do
    pipeline = Pipeline.new
    pipeline.setup

    puts "Starting live pipeline with #{pipeline.index.total_rules} rules..."
    puts "Press Ctrl+C to stop."

    ingestion = MarketIngestion.new(pipeline: pipeline)

    trap("INT") do
      puts "\nShutting down..."
      ingestion.stop
    end

    ingestion.start
  end
end
