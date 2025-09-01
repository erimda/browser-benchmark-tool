# frozen_string_literal: true

require 'json'
require 'fileutils'
require_relative 'chart_generator'

module BrowserBenchmarkTool
  class ReportGenerator
    attr_reader :config, :samples, :degradation_engine

    def initialize(config, samples, degradation_engine)
      @config = config
      @samples = samples
      @degradation_engine = degradation_engine
      @chart_generator = ChartGenerator.new(config, samples) if config.output[:generate_charts]
    end

    def generate_summary
      msc = get_maximum_sustainable_concurrency
      stop_reason = degradation_engine.degradation_detected? ? degradation_engine.stop_reason : 'No degradation detected'
      
      <<~MARKDOWN
        # Browser Benchmark Summary
        
        ## Configuration
        - **Mode:** #{config.workload[:mode]}
        - **Engine:** #{config.workload[:engine]}
        - **Headless:** #{config.workload[:headless]}
        - **Ramp Strategy:** #{config.ramp[:strategy]}
        - **Levels:** #{config.ramp[:levels]&.join(', ') || 'N/A'}
        - **URLs:** #{config.workload[:urls]&.join(', ') || 'N/A'}
        
        ## Results
        - **Maximum Sustainable Concurrency (MSC):** #{msc}
        - **Stop Reason:** #{stop_reason}
        - **Total Levels Tested:** #{samples.length}
        
        ## Per-Level Metrics
        #{generate_per_level_table}
        
        ## Thresholds
        - **Latency Multiplier:** #{config.thresholds[:latency_threshold_x]}× baseline p95
        - **CPU Threshold:** #{(config.thresholds[:cpu_threshold] * 100).round(1)}%
        - **Memory Threshold:** #{(config.thresholds[:mem_threshold] * 100).round(1)}%
        - **Error Rate Threshold:** #{(config.thresholds[:error_rate_threshold] * 100).round(1)}%
        
        ## Charts
        #{generate_charts_section}
      MARKDOWN
    end

    def export_jsonl
      samples.map { |sample| sample.to_json }.join("\n")
    end

    def export_csv
      return '' if samples.empty?
      
      headers = ['level', 'attempted', 'successful', 'failed', 'error_rate', 'p50', 'p95', 'p99', 'cpu_usage', 'memory_usage']
      
      csv_lines = [headers.join(',')]
      
      samples.each do |sample|
        row = [
          sample[:level],
          sample[:tasks][:attempted],
          sample[:tasks][:successful],
          sample[:tasks][:failed],
          (sample[:tasks][:error_rate] * 100).round(1),
          sample[:latency_ms][:p50].round(1),
          sample[:latency_ms][:p95].round(1),
          sample[:latency_ms][:p99].round(1),
          (sample[:host][:cpu_usage] * 100).round(1),
          (sample[:host][:memory_usage] * 100).round(1)
        ]
        csv_lines << row.join(',')
      end
      
      csv_lines.join("\n")
    end

    def generate_per_level_table
      return 'No data available' if samples.empty?
      
      table = []
      table << '| Level | Attempted | Successful | Failed | Error Rate | P95 (ms) | CPU % | Memory % |'
      table << '|-------|-----------|------------|--------|------------|----------|-------|----------|'
      
      samples.each do |sample|
        row = [
          sample[:level],
          sample[:tasks][:attempted],
          sample[:tasks][:successful],
          sample[:tasks][:failed],
          "#{(sample[:tasks][:error_rate] * 100).round(1)}%",
          sample[:latency_ms][:p95].round(1),
          "#{(sample[:host][:cpu_usage] * 100).round(1)}%",
          "#{(sample[:host][:memory_usage] * 100).round(1)}%"
        ]
        table << "| #{row.join(' | ')} |"
      end
      
      table.join("\n")
    end

    def save_reports
      output_dir = config.output[:dir]
      FileUtils.mkdir_p(output_dir)
      
      # Save summary markdown
      File.write(File.join(output_dir, 'summary.md'), generate_summary)
      
      # Save JSONL data
      File.write(File.join(output_dir, 'metrics.jsonl'), export_jsonl)
      
      # Save CSV data
      File.write(File.join(output_dir, 'metrics.csv'), export_csv)
      
      # Save charts if enabled
      if config.output[:generate_charts] && @chart_generator
        @chart_generator.save_charts
      end
      
      puts "Reports saved to: #{output_dir}"
    end

    def get_maximum_sustainable_concurrency
      if degradation_engine.degradation_detected?
        degradation_engine.get_maximum_sustainable_concurrency(samples)
      else
        samples.map { |s| s[:level] }.max || 0
      end
    end

    private

    def generate_charts_section
      return 'Charts disabled in configuration.' unless config.output[:generate_charts]
      
      <<~MARKDOWN
        Interactive charts have been generated:
        - [Latency Chart](latency_chart.html) - Shows p50, p95, p99 latency vs concurrency
        - [Resource Chart](resource_chart.html) - Shows CPU and memory usage vs concurrency
        - [Error Rate Chart](error_rate_chart.html) - Shows error rates vs concurrency
        - [Combined Chart](combined_chart.html) - All metrics in one comprehensive view
      MARKDOWN
    end
  end
end
