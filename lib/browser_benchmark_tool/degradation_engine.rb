# frozen_string_literal: true

module BrowserBenchmarkTool
  class DegradationEngine
    def initialize(config)
      @config = config
      @baseline = nil
      @degradation_detected = false
      @stop_reason = nil
    end

    def set_baseline(baseline)
      @baseline = baseline
    end

    def check_degradation(sample)
      return false if @degradation_detected
      
      # Check latency degradation
      if check_latency_degradation(sample)
        @degradation_detected = true
        @stop_reason = "p95 latency > #{@config.thresholds[:latency_multiplier_x]}× baseline"
        return true
      end
      
      # Check CPU degradation
      if check_cpu_degradation(sample)
        @degradation_detected = true
        @stop_reason = "CPU utilization > #{@config.thresholds[:cpu_utilization] * 100}%"
        return true
      end
      
      # Check memory degradation
      if check_memory_degradation(sample)
        @degradation_detected = true
        @stop_reason = "Memory utilization > #{@config.thresholds[:memory_utilization] * 100}%"
        return true
      end
      
      # Check error rate degradation
      if check_error_rate_degradation(sample)
        @degradation_detected = true
        @stop_reason = "Error rate > #{@config.thresholds[:error_rate] * 100}%"
        return true
      end
      
      false
    end

    def degradation_detected?
      @degradation_detected
    end

    def stop_reason
      @stop_reason
    end

    def get_maximum_sustainable_concurrency(samples)
      return 0 if samples.empty?
      
      if @degradation_detected
        # Find the last level before degradation
        degraded_level = samples.last[:level]
        previous_level = samples.reverse.find { |s| s[:level] < degraded_level }
        previous_level ? previous_level[:level] : 1
      else
        # No degradation detected, return the highest level tested
        samples.map { |s| s[:level] }.max
      end
    end

    private

    def check_latency_degradation(sample)
      return false unless @baseline && sample[:latency_ms][:p95]
      
      current_p95 = sample[:latency_ms][:p95]
      baseline_p95 = @baseline[:p95]
      threshold = @config.thresholds[:latency_multiplier_x]
      
      current_p95 > (baseline_p95 * threshold)
    end

    def check_cpu_degradation(sample)
      return false unless sample[:host][:cpu_usage]
      
      sample[:host][:cpu_usage] > @config.thresholds[:cpu_utilization]
    end

    def check_memory_degradation(sample)
      return false unless sample[:host][:memory_usage]
      
      sample[:host][:memory_usage] > @config.thresholds[:memory_utilization]
    end

    def check_error_rate_degradation(sample)
      return false unless sample[:tasks][:error_rate]
      
      sample[:tasks][:error_rate] > @config.thresholds[:error_rate]
    end
  end
end
