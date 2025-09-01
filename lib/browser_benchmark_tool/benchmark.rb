# frozen_string_literal: true

require_relative 'browser_automation'
require_relative 'metrics_collector'
require_relative 'degradation_engine'
require_relative 'report_generator'

module BrowserBenchmarkTool
  class Benchmark
    def initialize(config)
      @config = config
      @automation = BrowserAutomation.new(config)
      @metrics = MetricsCollector.new
      @degradation_engine = DegradationEngine.new(config)
      @results = []
    end

    def run
      puts "Starting browser benchmark..."
      puts "Configuration: #{@config.workload[:mode]} mode, #{@config.workload[:engine]} engine"
      puts "Ramp strategy: #{@config.ramp[:strategy]} with levels: #{@config.ramp[:levels].join(', ')}"
      puts "Target URLs: #{@config.workload[:urls].join(', ')}"
      
      begin
        setup_browser
        run_benchmark_ramp
        generate_reports
        generate_summary
      ensure
        cleanup_browser
      end
    end

    private

    def setup_browser
      puts "Setting up browser automation..."
      @automation.setup
    end

    def run_benchmark_ramp
      @config.ramp[:levels].each do |level|
        puts "\n--- Testing concurrency level: #{level} ---"
        
        # Run the level
        results = run_level(level)
        
        # Collect metrics
        host_metrics = @metrics.collect_host_metrics
        process_metrics = @metrics.collect_process_metrics
        
        # Add sample
        sample = @metrics.add_sample(level, results, host_metrics, process_metrics)
        @results << sample
        
        # Set baseline after first level
        if level == 1
          baseline = @metrics.calculate_baseline
          @degradation_engine.set_baseline(baseline)
          puts "Baseline established: p95=#{baseline[:p95].round(2)}ms"
        end
        
        # Print level results
        print_level_results(sample)
        
        # Check for degradation
        if @degradation_engine.check_degradation(sample)
          puts "⚠️  Degradation detected: #{@degradation_engine.stop_reason}"
          break
        end
        
        # Wait minimum time per level
        sleep(@config.ramp[:min_level_seconds])
      end
    end

    def run_level(level)
      urls = @config.workload[:urls]
      actions = @config.workload[:actions] || []
      repetitions = @config.workload[:per_browser_repetitions]
      
      @automation.run_concurrent_tasks(level, urls, actions, repetitions)
    end

    def print_level_results(sample)
      latency = sample[:latency_ms]
      tasks = sample[:tasks]
      host = sample[:host]
      
      puts "  Tasks: #{tasks[:attempted]} attempted, #{tasks[:successful]} successful, #{tasks[:failed]} failed (#{(tasks[:error_rate] * 100).round(1)}% error rate)"
      puts "  Latency: p50=#{latency[:p50].round(2)}ms, p95=#{latency[:p95].round(2)}ms, p99=#{latency[:p99].round(2)}ms"
      puts "  Host: CPU=#{(host[:cpu_usage] * 100).round(1)}%, Memory=#{(host[:memory_usage] * 100).round(1)}%"
    end

    def generate_reports
      puts "\nGenerating reports..."
      report_generator = ReportGenerator.new(@config, @results, @degradation_engine)
      report_generator.save_reports
    end

    def generate_summary
      puts "\n" + "="*50
      puts "BENCHMARK SUMMARY"
      puts "="*50
      
      msc = @degradation_engine.get_maximum_sustainable_concurrency(@results)
      puts "Maximum Sustainable Concurrency (MSC): #{msc}"
      
      if @degradation_engine.degradation_detected?
        puts "Stop Reason: #{@degradation_engine.stop_reason}"
      else
        puts "No degradation detected - tested all levels"
      end
      
      puts "\nPer-level results:"
      @results.each do |sample|
        level = sample[:level]
        latency = sample[:latency_ms]
        tasks = sample[:tasks]
        host = sample[:host]
        
        puts "  Level #{level}: #{tasks[:attempted]} tasks, p95=#{latency[:p95].round(2)}ms, CPU=#{(host[:cpu_usage] * 100).round(1)}%, Mem=#{(host[:memory_usage] * 100).round(1)}%"
      end
    end

    def cleanup_browser
      puts "\nCleaning up browser resources..."
      @automation.cleanup
    end
  end
end
