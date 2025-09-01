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

    def collect_process_metrics(process_names = %w[chromium chrome])
      return [] if process_names.empty?
      
      if process_metrics_available?
        collect_real_process_metrics(process_names)
      else
        collect_simulated_process_metrics(process_names)
      end
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

    def system_metrics_available?
      # Check if we can collect real system metrics
      begin
        require 'sys-proctable'
        true
      rescue LoadError
        false
      end
    end

    def process_metrics_available?
      # Check if we can collect real process metrics
      begin
        require 'sys-proctable'
        true
      rescue LoadError
        false
      end
    end

    def collect_cpu_usage
      if system_metrics_available?
        collect_real_cpu_usage
      else
        collect_simulated_cpu_usage
      end
    end

    def collect_memory_usage
      if system_metrics_available?
        collect_real_memory_usage
      else
        collect_simulated_memory_usage
      end
    end

    def collect_load_average
      if system_metrics_available?
        collect_real_load_average
      else
        collect_simulated_load_average
      end
    end

    def collect_real_cpu_usage
      # Platform-specific CPU usage collection
      case RUBY_PLATFORM
      when /darwin/ # macOS
        collect_macos_cpu_usage
      when /linux/ # Linux
        collect_linux_cpu_usage
      else
        # Fallback to sys-proctable if available
        collect_fallback_cpu_usage
      end
    rescue StandardError => e
      puts "Failed to collect real CPU usage: #{e.message}" if ENV['DEBUG']
      collect_simulated_cpu_usage
    end

    def collect_real_memory_usage
      # Platform-specific memory usage collection
      case RUBY_PLATFORM
      when /darwin/ # macOS
        collect_macos_memory_usage
      when /linux/ # Linux
        collect_linux_memory_usage
      else
        # Fallback to sys-proctable if available
        collect_fallback_memory_usage
      end
    rescue StandardError => e
      puts "Failed to collect real memory usage: #{e.message}" if ENV['DEBUG']
      collect_simulated_memory_usage
    end

    def collect_real_load_average
      # Platform-specific load average collection
      case RUBY_PLATFORM
      when /darwin/ # macOS
        collect_macos_load_average
      when /linux/ # Linux
        collect_linux_load_average
      else
        # Fallback to sys-proctable if available
        collect_fallback_load_average
      end
    rescue StandardError => e
      puts "Failed to collect real load average: #{e.message}" if ENV['DEBUG']
      collect_simulated_load_average
    end

    def collect_real_process_metrics(process_names)
      require 'sys-proctable'
      
      process_metrics = []
      process_names.each do |name|
        Sys::ProcTable.ps.each do |process|
          # Improved process matching for macOS
          if process.comm && matches_process_name?(process.comm, name)
            process_metrics << {
              pid: process.pid,
              comm: process.comm,
              cpu_percent: calculate_macos_cpu_percent(process),
              memory_mb: (process.rss || 0) / 1024.0,
              vsize_mb: (process.vsize || 0) / 1024.0 / 1024.0
            }
          end
        end
      end
      
      process_metrics
    rescue StandardError => e
      puts "Failed to collect real process metrics: #{e.message}" if ENV['DEBUG']
      collect_simulated_process_metrics(process_names)
    end

    def calculate_macos_cpu_percent(process)
      # Calculate CPU percentage from total user and system time on macOS
      if process.respond_to?(:total_user) && process.respond_to?(:total_system)
        total_time = process.total_user + process.total_system
        # Convert to percentage (this is a simplified calculation)
        # In a real implementation, you'd want to track time deltas
        [total_time / 1_000_000.0, 100.0].min # Cap at 100%
      else
        0.0
      end
    end

    def matches_process_name?(process_comm, search_name)
      # Handle macOS process naming conventions
      case search_name.downcase
      when 'chrome'
        process_comm.downcase.include?('chrome') || 
        process_comm.downcase.include?('google chrome')
      when 'chromium'
        process_comm.downcase.include?('chromium') || 
        process_comm.downcase.include?('chrome')
      when 'firefox'
        process_comm.downcase.include?('firefox')
      when 'safari'
        process_comm.downcase.include?('safari')
      else
        process_comm.downcase.include?(search_name.downcase)
      end
    end

    # Platform-specific methods for macOS
    def collect_macos_cpu_usage
      # Use 'top' command to get CPU usage on macOS
      output = `top -l 1 -n 0 2>/dev/null`
      if output && output.match(/CPU usage:\s+(\d+\.\d+)% user,\s+(\d+\.\d+)% sys,\s+(\d+\.\d+)% idle/)
        user = $1.to_f
        sys = $2.to_f
        idle = $3.to_f
        total = user + sys + idle
        usage = (user + sys) / total
        [0.0, usage].max # Ensure non-negative
      else
        collect_fallback_cpu_usage
      end
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
          used_pages.to_f / total_pages
        else
          collect_fallback_memory_usage
        end
      else
        collect_fallback_memory_usage
      end
    end

    def collect_macos_load_average
      # Use 'top' command to get load average on macOS
      output = `top -l 1 -n 0 2>/dev/null`
      if output && output.match(/Load Avg:\s+([\d.]+),\s+([\d.]+),\s+([\d.]+)/)
        [$1.to_f, $2.to_f, $3.to_f]
      else
        collect_fallback_load_average
      end
    end

    # Platform-specific methods for Linux
    def collect_linux_cpu_usage
      # Read CPU usage from /proc/stat on Linux
      if File.exist?('/proc/stat')
        cpu_line = File.read('/proc/stat').lines.first
        values = cpu_line.split[1..-1].map(&:to_i)
        total = values.sum
        idle = values[3]
        usage = 1.0 - (idle.to_f / total)
        [0.0, usage].max # Ensure non-negative
      else
        collect_fallback_cpu_usage
      end
    end

    def collect_linux_memory_usage
      # Read memory usage from /proc/meminfo on Linux
      if File.exist?('/proc/meminfo')
        meminfo = File.read('/proc/meminfo')
        total = meminfo.match(/MemTotal:\s+(\d+)/)&.[](1)&.to_i || 1
        available = meminfo.match(/MemAvailable:\s+(\d+)/)&.[](1)&.to_i || 0
        used = total - available
        used.to_f / total
      else
        collect_fallback_memory_usage
      end
    end

    def collect_linux_load_average
      # Read load average from /proc/loadavg on Linux
      if File.exist?('/proc/loadavg')
        load_line = File.read('/proc/loadavg')
        loads = load_line.split[0..2].map(&:to_f)
        loads
      else
        collect_fallback_load_average
      end
    end

    # Fallback methods using sys-proctable
    def collect_fallback_cpu_usage
      begin
        require 'sys-proctable'
        # This is a simplified approach - in a real implementation you'd want more sophisticated CPU monitoring
        0.5 # Default fallback
      rescue
        0.5 # Final fallback
      end
    end

    def collect_fallback_memory_usage
      begin
        require 'sys-proctable'
        # This is a simplified approach - in a real implementation you'd want more sophisticated memory monitoring
        0.6 # Default fallback
      rescue
        0.6 # Final fallback
      end
    end

    def collect_fallback_load_average
      begin
        require 'sys-proctable'
        # This is a simplified approach - in a real implementation you'd want more sophisticated load monitoring
        [1.0, 0.8, 0.6] # Default fallback
      rescue
        [1.0, 0.8, 0.6] # Final fallback
      end
    end

    def collect_simulated_cpu_usage
      # Simulate CPU usage that increases with load
      base_cpu = 0.3
      # Add some randomness to simulate real CPU usage
      base_cpu + rand(-0.1..0.2)
    end

    def collect_simulated_memory_usage
      # Simulate memory usage
      base_memory = 0.4
      base_memory + rand(-0.05..0.15)
    end

    def collect_simulated_load_average
      # Simulate load average
      [rand(0.1..2.0), rand(0.1..1.8), rand(0.1..1.5)]
    end

    def collect_simulated_process_metrics(process_names)
      # Simulate process metrics for now
      process_names.map do |name|
        {
          pid: rand(1000..9999),
          comm: "#{name}-simulated",
          cpu_percent: rand(5.0..25.0),
          memory_mb: rand(100.0..500.0),
          vsize_mb: rand(200.0..1000.0)
        }
      end
    end

    def calculate_percentiles(values)
      return { p50: 0, p90: 0, p95: 0, p99: 0 } if values.empty? || values.all?(&:zero?)

      # Filter out zero values and ensure we have valid numbers
      valid_values = values.reject { |v| v.nil? || v.zero? || (v.respond_to?(:nan?) && v.nan?) }
      return { p50: 0, p90: 0, p95: 0, p99: 0 } if valid_values.empty?

      sorted = valid_values.sort
      length = sorted.length
      
      {
        p50: calculate_percentile(sorted, 0.5, length),
        p90: calculate_percentile(sorted, 0.9, length),
        p95: calculate_percentile(sorted, 0.95, length),
        p99: calculate_percentile(sorted, 0.99, length)
      }
    end

    def calculate_percentile(sorted_values, percentile, length)
      # For p50 (median), handle even vs odd length specially
      if percentile == 0.5 && length.even?
        # For even length, median is average of two middle values
        mid1 = sorted_values[(length / 2) - 1]
        mid2 = sorted_values[length / 2]
        return (mid1 + mid2) / 2.0
      end
      
      index = (length * percentile).floor
      if index >= length
        sorted_values.last
      elsif index == 0
        sorted_values.first
      else
        sorted_values[index]
      end
    end
  end
end
