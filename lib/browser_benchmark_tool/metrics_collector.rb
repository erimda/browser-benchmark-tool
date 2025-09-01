# frozen_string_literal: true

require 'time'

module BrowserBenchmarkTool
  class MetricsCollector
    def initialize
      @samples = []
      @start_time = Time.now
    end

    def collect_host_metrics
      {
        timestamp: Time.now.strftime('%Y-%m-%dT%H:%M:%S.%LZ'),
        cpu_usage: collect_cpu_usage,
        memory_usage: collect_memory_usage,
        load_average: collect_load_average,
        uptime: Time.now - @start_time
      }
    end

    def collect_process_metrics(_process_names = %w[chromium chrome])
      # Simulate process metrics for now
      [
        {
          pid: rand(1000..9999),
          comm: 'chromium-simulated',
          cpu_percent: rand(5.0..25.0),
          memory_mb: rand(100.0..500.0),
          vsize_mb: rand(200.0..1000.0)
        }
      ]
    end

    def add_sample(level, results, host_metrics, process_metrics)
      successful_tasks = results.select { |r| r[:success] }
      failed_tasks = results.reject { |r| r[:success] }

      durations = successful_tasks.map { |r| r[:duration_ms] || r[:duration] || 0 }

      sample = {
        timestamp: Time.now.strftime('%Y-%m-%dT%H:%M:%S.%LZ'),
        level: level,
        tasks: {
          attempted: results.length,
          successful: successful_tasks.length,
          failed: failed_tasks.length,
          error_rate: results.length.positive? ? failed_tasks.length.to_f / results.length : 0.0
        },
        latency_ms: calculate_percentiles(durations),
        host: host_metrics,
        processes: process_metrics
      }

      @samples << sample
      sample
    end

    def get_samples
      @samples
    end

    def calculate_baseline
      return nil if @samples.empty?

      # Use the first level (concurrency = 1) as baseline
      baseline_sample = @samples.find { |s| s[:level] == 1 }
      return nil unless baseline_sample

      {
        p50: baseline_sample[:latency_ms][:p50],
        p95: baseline_sample[:latency_ms][:p95],
        p99: baseline_sample[:latency_ms][:p99]
      }
    end

    private

    def collect_cpu_usage
      # Simulate CPU usage that increases with load
      base_cpu = 0.3
      # Add some randomness to simulate real CPU usage
      base_cpu + rand(-0.1..0.2)
    end

    def collect_memory_usage
      # Simulate memory usage
      base_memory = 0.4
      base_memory + rand(-0.05..0.15)
    end

    def collect_load_average
      # Simulate load average
      [rand(0.1..2.0), rand(0.1..1.8), rand(0.1..1.5)]
    end

    def calculate_percentiles(values)
      return { p50: 0, p90: 0, p95: 0, p99: 0 } if values.empty? || values.all?(&:zero?)

      # Filter out zero values and ensure we have valid numbers
      valid_values = values.reject { |v| v.nil? || v.zero? || v.nan? }
      return { p50: 0, p90: 0, p95: 0, p99: 0 } if valid_values.empty?

      sorted = valid_values.sort
      {
        p50: sorted[(sorted.length * 0.5).floor],
        p90: sorted[(sorted.length * 0.9).floor],
        p95: sorted[(sorted.length * 0.95).floor],
        p99: sorted[(sorted.length * 0.99).floor]
      }
    end
  end
end
