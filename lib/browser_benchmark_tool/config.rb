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
        urls: ['https://example.org/'],
        actions: [
          { wait_for: 'h1' },
          { screenshot: false }
        ],
        per_browser_repetitions: 5
      }
      config.ramp = {
        strategy: 'exponential',
        levels: [1, 2, 4, 8, 16, 32],
        min_level_seconds: 45
      }
      config.thresholds = {
        latency_multiplier_x: 2.0,
        cpu_utilization: 0.90,
        memory_utilization: 0.80,
        error_rate: 0.01
      }
      config.sampling = {
        host_interval_seconds: 2,
        aggregation_window_seconds: 10
      }
      config.output = {
        dir: './artifacts',
        formats: ['jsonl', 'csv', 'md'],
        charts: true
      }
      config.safety = {
        robots_txt_respect: true,
        external_rate_limit_rps: 2
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
      config = new
      config.workload = {
        mode: options[:mode],
        engine: options[:engine],
        headless: options[:headless],
        urls: options[:urls],
        per_browser_repetitions: options[:reps_per_level]
      }
      config.ramp = parse_ramp_strategy(options[:ramp])
      config.thresholds = {
        latency_multiplier_x: options[:latency_threshold_x],
        cpu_utilization: options[:cpu_threshold],
        memory_utilization: options[:mem_threshold],
        error_rate: 0.01
      }
      config.sampling = {
        host_interval_seconds: 2,
        aggregation_window_seconds: 10
      }
      config.output = {
        dir: options[:out_dir],
        formats: ['jsonl', 'csv', 'md'],
        charts: true
      }
      config.safety = {
        robots_txt_respect: true,
        external_rate_limit_rps: 2
      }
      config
    end

    def merge_cli_options(options)
      # Override config with CLI options if provided
      @workload[:mode] = options[:mode] if options[:mode]
      @workload[:engine] = options[:engine] if options[:engine]
      @workload[:headless] = options[:headless] if options.key?(:headless)
      @workload[:urls] = options[:urls] if options[:urls]
      @workload[:per_browser_repetitions] = options[:reps_per_level] if options[:reps_per_level]
      
      @ramp = self.class.parse_ramp_strategy(options[:ramp]) if options[:ramp]
      
      @thresholds[:latency_multiplier_x] = options[:latency_threshold_x] if options[:latency_threshold_x]
      @thresholds[:cpu_utilization] = options[:cpu_threshold] if options[:cpu_threshold]
      @thresholds[:memory_utilization] = options[:mem_threshold] if options[:mem_threshold]
      
      @output[:dir] = options[:out_dir] if options[:out_dir]
      
      self
    end

    def to_yaml
      {
        'workload' => @workload,
        'ramp' => @ramp,
        'thresholds' => @thresholds,
        'sampling' => @sampling,
        'output' => @output,
        'safety' => @safety
      }.to_yaml
    end

    private

    def self.parse_ramp_strategy(ramp_str)
      return { strategy: 'exponential', levels: [1, 2, 4, 8, 16, 32] } unless ramp_str

      case ramp_str
      when /^exp:(.+)$/
        levels = $1.split(',').map(&:to_i)
        { strategy: 'exponential', levels: levels }
      when /^linear:(\d+)$/
        max = $1.to_i
        levels = (1..max).to_a
        { strategy: 'linear', levels: levels }
      when /^custom:(.+)$/
        levels = $1.split(',').map(&:to_i)
        { strategy: 'custom', levels: levels }
      else
        { strategy: 'exponential', levels: [1, 2, 4, 8, 16, 32] }
      end
    end
  end
end
