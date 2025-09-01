# frozen_string_literal: true

require_relative 'browser_automation'
require_relative 'metrics_collector'
require_relative 'degradation_engine'
require_relative 'report_generator'

module BrowserBenchmarkTool
  class Benchmark
    attr_reader :config, :browser_automation, :metrics_collector, :degradation_engine

    def initialize(config)
      @config = config
      @browser_automation = BrowserAutomation.new(config)
      @metrics_collector = MetricsCollector.new
      @degradation_engine = DegradationEngine.new(config)
      @start_time = nil
      @max_runtime_minutes = config.output[:max_runtime_minutes] || 20
    end

    def run
      puts 'Starting browser benchmark...'
      puts "Configuration: #{@config.workload[:mode]} mode, #{@config.workload[:engine]} engine"
      puts "Max runtime: #{@max_runtime_minutes} minutes"

      @start_time = Time.now

      begin
        run_benchmark_ramp
        generate_summary
      ensure
        cleanup_browser
      end
    end

    private

    def run_benchmark_ramp
      puts "\nRunning benchmark ramp strategy: #{@config.ramp[:strategy]}"

      @config.ramp[:levels].each do |level|
        break if should_stop_early?

        puts "\n--- Level #{level} (Concurrency: #{level}) ---"

        level_start_time = Time.now
        level_results = run_level(level)
        level_duration = Time.now - level_start_time

        print_level_results(level, level_results, level_duration)

        # Check for degradation
        if @degradation_engine.degradation_detected?
          puts '⚠️  Degradation detected! Stopping benchmark.'
          puts "Reason: #{@degradation_engine.stop_reason}"
          break
        end

        # Adaptive wait time between levels
        wait_time = calculate_adaptive_wait_time(level_duration)
        if wait_time.positive?
          puts "Waiting #{wait_time.round(1)}s before next level..."
          sleep(wait_time)
        end
      end
    end

    def run_level(concurrency_level)
      urls = @config.workload[:urls]
      repetitions = @config.workload[:per_browser_repetitions] || 3

      puts "Running #{concurrency_level} concurrent tasks with #{repetitions} repetitions each..."

      all_results = []

      repetitions.times do |rep|
        break if should_stop_early?

        puts "  Repetition #{rep + 1}/#{repetitions}..."

        # Run concurrent tasks
        results = @browser_automation.run_concurrent_tasks(urls, concurrency_level)

        # Collect host and process metrics
        host_metrics = @metrics_collector.collect_host_metrics
        process_metrics = @metrics_collector.collect_process_metrics

        # Collect metrics
        @metrics_collector.add_sample(concurrency_level, results, host_metrics, process_metrics)

        all_results.concat(results)

        # Check for degradation after each repetition for faster detection
        if @degradation_engine.degradation_detected?
          puts '⚠️  Degradation detected during level! Stopping benchmark.'
          puts "Reason: #{@degradation_engine.stop_reason}"
          break
        end

        # Much shorter delay between repetitions for better performance
        sleep(0.01) unless rep == repetitions - 1
      end

      # Set baseline after first level
      if concurrency_level == @config.ramp[:levels].first
        @degradation_engine.set_baseline(@metrics_collector.calculate_baseline)
        # Check for immediate degradation after baseline is set
        if @degradation_engine.degradation_detected?
          puts '⚠️  Degradation detected immediately after baseline! Stopping benchmark.'
          puts "Reason: #{@degradation_engine.stop_reason}"
          return all_results
        end
      end

      all_results
    end

    def print_level_results(_level, results, duration)
      successful = results.count { |r| r[:success] }
      failed = results.length - successful

      avg_duration = results.sum { |r| r[:duration_ms] || 0 } / results.length.to_f

      puts "  Results: #{successful} successful, #{failed} failed"
      puts "  Average duration: #{avg_duration.round(2)}ms"
      puts "  Level duration: #{duration.round(2)}s"

      # Print safety stats
      safety_stats = @browser_automation.safety_manager.get_safety_stats
      puts "  Safety: #{safety_stats[:current_requests]}/#{@config.safety[:max_concurrent_requests]} concurrent, #{safety_stats[:total_requests]} total"
    end

    def generate_summary
      puts "\n--- Benchmark Summary ---"

      runtime = Time.now - @start_time
      puts "Total runtime: #{runtime.round(2)}s (#{(runtime / 60).round(2)} minutes)"

      puts '⚠️  Benchmark stopped early due to time limit' if should_stop_early?

      # Generate reports
      generate_reports
    end

    def generate_reports
      puts "\nGenerating reports..."

      report_generator = ReportGenerator.new(@config, @metrics_collector.get_samples, @degradation_engine)
      report_generator.save_reports

      puts "Reports saved to: #{@config.output[:dir]}"
    end

    def cleanup_browser
      puts "\nCleaning up..."
      # Clean up browser automation resources
      @browser_automation.cleanup
    end

    def should_stop_early?
      return false unless @start_time

      elapsed_minutes = (Time.now - @start_time) / 60
      elapsed_minutes >= @max_runtime_minutes
    end

    def calculate_adaptive_wait_time(level_duration)
      min_level_seconds = @config.workload[:min_level_seconds] || 30

      if level_duration < min_level_seconds
        # If level ran too fast, wait a bit longer but not too long
        wait_time = min_level_seconds - level_duration
        [wait_time, 0.1].max # Very aggressive: minimum 0.1 seconds
      else
        # If level took longer than minimum, shorter wait
        [level_duration * 0.01, 0.1].max # Very aggressive: 1% of level time, minimum 0.1 seconds
      end
    end
  end
end
