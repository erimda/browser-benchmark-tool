# frozen_string_literal: true

require 'time'

module BrowserBenchmarkTool
  class MemoryLeakDetector
    attr_reader :config, :memory_history, :request_count

    def initialize(config)
      @config = config
      @memory_history = []
      @request_count = 0
      @baseline_memory = nil
      @enabled = config.memory_leak&.dig(:enabled) || false
    end

    def enabled?
      @enabled
    end

    def threshold_mb
      config.memory_leak&.dig(:threshold_mb) || 100
    end

    def check_interval_requests
      config.memory_leak&.dig(:check_interval_requests) || 10
    end

    def max_memory_growth_percent
      config.memory_leak&.dig(:max_memory_growth_percent) || 20
    end

    def record_memory_usage(memory_mb)
      return unless enabled?

      timestamp = Time.now.strftime('%Y-%m-%dT%H:%M:%S.%LZ')
      
      # Set baseline on first recording
      @baseline_memory = memory_mb if @baseline_memory.nil?
      
      entry = {
        timestamp: timestamp,
        memory_mb: memory_mb,
        request_count: @request_count
      }
      
      @memory_history << entry
      
      # Check for memory leaks
      check_for_leaks
    end

    def check_for_leaks
      return false unless enabled?
      return false if @memory_history.length < 2

      current_memory = @memory_history.last[:memory_mb]
      
      # Check absolute threshold
      if current_memory > threshold_mb
        return true
      end
      
      # Check percentage growth
      growth_percent = calculate_growth_percent
      if growth_percent > max_memory_growth_percent
        return true
      end
      
      false
    end

    def get_memory_stats
      return {} unless enabled?

      current_memory = @memory_history.last&.dig(:memory_mb) || 0
      peak_memory = @memory_history.map { |entry| entry[:memory_mb] }.max || 0
      baseline = @baseline_memory || current_memory
      growth_percent = calculate_growth_percent
      leak_detected = check_for_leaks

      {
        current_mb: current_memory,
        peak_mb: peak_memory,
        baseline_mb: baseline,
        growth_percent: growth_percent,
        leak_detected: leak_detected,
        history_length: @memory_history.length,
        request_count: @request_count
      }
    end

    def reset_baseline
      return unless enabled?
      
      current_memory = @memory_history.last&.dig(:memory_mb) || 0
      @baseline_memory = current_memory
      
      # Clear history to start fresh with new baseline
      @memory_history.clear
      @memory_history << {
        timestamp: Time.now.strftime('%Y-%m-%dT%H:%M:%S.%LZ'),
        memory_mb: current_memory,
        request_count: @request_count
      }
    end

    def should_check_memory
      return false unless enabled?
      
      @request_count % check_interval_requests == 0
    end

    def increment_request_count
      @request_count += 1
    end

    def get_current_memory_usage
      # Get current memory usage from system
      if system_metrics_available?
        collect_real_memory_usage
      else
        # Fallback to simulated memory usage
        collect_simulated_memory_usage
      end
    end

    def get_leak_recommendations
      return [] unless enabled?

      recommendations = []
      
      if check_for_leaks
        recommendations << "Memory usage has exceeded threshold (#{threshold_mb}MB)"
        recommendations << "Memory growth is #{calculate_growth_percent.round(1)}% (limit: #{max_memory_growth_percent}%)"
        recommendations << "Consider reducing context pool size"
        recommendations << "Check for unclosed browser resources"
        recommendations << "Monitor for memory leaks in browser automation"
      else
        recommendations << "Memory usage is within normal limits"
        recommendations << "Current memory: #{@memory_history.last&.dig(:memory_mb) || 0}MB"
        recommendations << "Baseline memory: #{@baseline_memory || 0}MB"
      end
      
      recommendations
    end

    def clear_history
      @memory_history.clear
      @baseline_memory = nil
      @request_count = 0
    end

    private

    def calculate_growth_percent
      return 0.0 if @baseline_memory.nil? || @baseline_memory.zero?
      
      current_memory = @memory_history.last&.dig(:memory_mb) || @baseline_memory
      growth = current_memory - @baseline_memory
      (growth / @baseline_memory) * 100
    end

    def system_metrics_available?
      # Check if we can collect real system metrics
      begin
        require 'sys-proctable'
        true
      rescue LoadError
        false
      end
    end

    def collect_real_memory_usage
      # Use the same method as MetricsCollector for consistency
      case RUBY_PLATFORM
      when /darwin/ # macOS
        collect_macos_memory_usage
      when /linux/ # Linux
        collect_linux_memory_usage
      else
        collect_fallback_memory_usage
      end
    rescue StandardError => e
      puts "Failed to collect real memory usage: #{e.message}" if ENV['DEBUG']
      collect_simulated_memory_usage
    end

    def collect_macos_memory_usage
      # Use 'vm_stat' command to get memory usage on macOS
      output = `vm_stat 2>/dev/null`
      if output
        # Parse vm_stat output to calculate memory usage
        lines = output.lines
        total_pages = 0
        free_pages = 0
        
        lines.each do |line|
          if line.match(/Pages free:\s+(\d+)\./)
            free_pages = $1.to_i
          elsif line.match(/Pages active:\s+(\d+)\./)
            total_pages += $1.to_i
          elsif line.match(/Pages inactive:\s+(\d+)\./)
            total_pages += $1.to_i
          elsif line.match(/Pages wired down:\s+(\d+)\./)
            total_pages += $1.to_i
          elsif line.match(/Pages speculative:\s+(\d+)\./)
            total_pages += $1.to_i
          end
        end
        
        if total_pages > 0
          used_pages = total_pages - free_pages
          # Convert pages to MB (assuming 16KB pages on macOS)
          (used_pages * 16) / 1024.0
        else
          collect_simulated_memory_usage
        end
      else
        collect_simulated_memory_usage
      end
    end

    def collect_linux_memory_usage
      # Read memory usage from /proc/meminfo on Linux
      if File.exist?('/proc/meminfo')
        meminfo = File.read('/proc/meminfo')
        total = meminfo.match(/MemTotal:\s+(\d+)/)&.[](1)&.to_i || 1
        available = meminfo.match(/MemAvailable:\s+(\d+)/)&.[](1)&.to_i || 0
        used = total - available
        # Convert KB to MB
        used / 1024.0
      else
        collect_fallback_memory_usage
      end
    end

    def collect_fallback_memory_usage
      # Fallback to simulated memory usage
      collect_simulated_memory_usage
    end

    def collect_simulated_memory_usage
      # Simulate memory usage for testing
      base_memory = 100.0 # 100MB base
      base_memory + rand(-10.0..20.0) # Add some variation
    end
  end
end
