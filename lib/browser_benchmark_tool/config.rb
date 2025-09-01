# frozen_string_literal: true

require 'yaml'

module BrowserBenchmarkTool
  class Config
    attr_accessor :workload, :ramp, :thresholds, :sampling, :output, :safety

    def initialize
      @workload = {}
      @ramp = {}
      @thresholds = {}
      @sampling = {}
      @output = {}
      @safety = {}
    end

    def self.default
      config = new
      config.workload = {
        mode: 'playwright',
        engine: 'chromium',
        headless: true,
        urls: ['https://httpbin.org/delay/0.5'],
        per_browser_repetitions: 3,
        min_level_seconds: 30
      }
      
      config.ramp = {
        strategy: 'exponential',
        levels: [1, 2, 4, 8, 16]
      }
      
      config.thresholds = {
        latency_threshold_x: 2.0,
        cpu_threshold: 0.8,
        mem_threshold: 0.8,
        error_rate_threshold: 0.05
      }
      
      config.sampling = {
        metrics_interval_seconds: 1
      }
      
      config.output = {
        dir: './artifacts',
        max_runtime_minutes: 20,
        generate_charts: true
      }
      
      config.safety = {
        robots_txt_respect: true,
        external_rate_limit_rps: 2,
        max_concurrent_requests: 10,
        request_timeout_seconds: 30,
        max_total_requests: 100
      }
      
      config
    end

    def self.from_hash(hash)
      config = new
      config.workload = hash['workload'] || {}
      config.ramp = hash['ramp'] || {}
      config.thresholds = hash['thresholds'] || {}
      config.sampling = hash['sampling'] || {}
      config.output = hash['output'] || {}
      config.safety = hash['safety'] || {}
      config
    end

    def self.from_cli_options(options)
      config = default
      
      # Override with CLI options
      config.workload[:mode] = options[:mode] if options[:mode]
      config.workload[:engine] = options[:engine] if options[:engine]
      config.workload[:headless] = options[:headless] if options[:headless]
      config.workload[:urls] = options[:urls] if options[:urls]
      config.workload[:per_browser_repetitions] = options[:reps_per_level] if options[:reps_per_level]
      config.workload[:min_level_seconds] = options[:level_min_seconds] if options[:level_min_seconds]
      
      config.ramp[:strategy] = options[:ramp] if options[:ramp]
      
      config.thresholds[:latency_threshold_x] = options[:latency_threshold_x] if options[:latency_threshold_x]
      config.thresholds[:cpu_threshold] = options[:cpu_threshold] if options[:cpu_threshold]
      config.thresholds[:mem_threshold] = options[:mem_threshold] if options[:mem_threshold]
      
      config.output[:dir] = options[:out_dir] if options[:out_dir]
      
      config
    end

    def merge_cli_options(options)
      # Merge CLI options with existing config
      self.workload[:mode] = options[:mode] if options[:mode]
      self.workload[:engine] = options[:engine] if options[:engine]
      self.workload[:headless] = options[:headless] if options[:headless]
      self.workload[:urls] = options[:urls] if options[:urls]
      self.workload[:per_browser_repetitions] = options[:reps_per_level] if options[:reps_per_level]
      self.workload[:min_level_seconds] = options[:level_min_seconds] if options[:level_min_seconds]
      
      self.ramp[:strategy] = options[:ramp] if options[:ramp]
      
      self.thresholds[:latency_threshold_x] = options[:latency_threshold_x] if options[:latency_threshold_x]
      self.thresholds[:cpu_threshold] = options[:cpu_threshold] if options[:cpu_threshold]
      self.thresholds[:mem_threshold] = options[:mem_threshold] if options[:mem_threshold]
      
      self.output[:dir] = options[:out_dir] if options[:out_dir]
    end

    def to_yaml
      {
        'workload' => workload,
        'ramp' => ramp,
        'thresholds' => thresholds,
        'sampling' => sampling,
        'output' => output,
        'safety' => safety
      }.to_yaml
    end

    def self.parse_ramp_strategy(strategy_str)
      case strategy_str
      when /^exp:(.+)$/
        levels = $1.split(',').map(&:to_i)
        { strategy: 'exponential', levels: levels }
      when /^lin:(.+)$/
        levels = $1.split(',').map(&:to_i)
        { strategy: 'linear', levels: levels }
      when /^custom:(.+)$/
        levels = $1.split(',').map(&:to_i)
        { strategy: 'custom', levels: levels }
      else
        { strategy: 'exponential', levels: [1, 2, 4, 8, 16] }
      end
    end
  end
end
