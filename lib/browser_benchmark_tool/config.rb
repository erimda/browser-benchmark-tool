# frozen_string_literal: true

require 'yaml'

module BrowserBenchmarkTool
  class Config
    attr_accessor :workload, :ramp, :thresholds, :sampling, :output, :safety, :memory_leak, :crawl4ai, :distributed, :custom_scripts, :browser_mode

    def initialize
      @workload = {}
      @ramp = {}
      @thresholds = {}
      @sampling = {}
      @output = {}
      @safety = {}
      @memory_leak = {}
      @crawl4ai = {}
      @distributed = {}
      @custom_scripts = {}
      @browser_mode = {}
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

      config.memory_leak = {
        enabled: true,
        threshold_mb: 100,
        check_interval_requests: 10,
        max_memory_growth_percent: 20
      }

      config.crawl4ai = {
        enabled: false,
        api_key: nil,
        max_pages_per_site: 10,
        follow_links: true,
        extract_content: true,
        respect_robots_txt: true,
        api_endpoint: 'https://api.crawl4ai.com'
      }

      config.distributed = {
        enabled: false,
        nodes: [],
        coordinator_port: 9000,
        load_balancing: 'round_robin',
        health_check_interval: 30,
        failover_enabled: false,
        node_weights: {}
      }

      config.custom_scripts = {
        enabled: false,
        script_path: './scripts/custom_workload.rb',
        script_timeout: 30,
        allow_external_scripts: false,
        script_parameters: {},
        validation_rules: ['url_format', 'safety_checks']
      }

      config.browser_mode = {
        mode: 'context', # 'context' or 'process'
        context_pool_size: 5,
        process_limit: 3,
        context_reuse: true,
        process_isolation: false,
        memory_per_context: 100,
        memory_per_process: 500,
        context_timeout: 30,
        process_timeout: 60,
        enable_context_pooling: true,
        enable_process_pooling: false
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
      config.memory_leak = hash['memory_leak'] || {}
      config.crawl4ai = hash['crawl4ai'] || {}
      config.distributed = hash['distributed'] || {}
      config.custom_scripts = hash['custom_scripts'] || {}
      config.browser_mode = hash['browser_mode'] || {}
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

      # Parse ramp strategy if provided
      if options[:ramp]
        ramp_config = parse_ramp_strategy(options[:ramp])
        config.ramp[:strategy] = ramp_config[:strategy]
        config.ramp[:levels] = ramp_config[:levels]
      end

      config.thresholds[:latency_threshold_x] = options[:latency_threshold_x] if options[:latency_threshold_x]
      config.thresholds[:cpu_threshold] = options[:cpu_threshold] if options[:cpu_threshold]
      config.thresholds[:mem_threshold] = options[:mem_threshold] if options[:mem_threshold]

      config.output[:dir] = options[:out_dir] if options[:out_dir]

      config
    end

    def merge_cli_options(options)
      # Merge CLI options with existing config
      workload[:mode] = options[:mode] if options[:mode]
      workload[:engine] = options[:engine] if options[:engine]
      workload[:headless] = options[:headless] if options[:headless]
      workload[:urls] = options[:urls] if options[:urls]
      workload[:per_browser_repetitions] = options[:reps_per_level] if options[:reps_per_level]
      workload[:min_level_seconds] = options[:level_min_seconds] if options[:level_min_seconds]

      # Parse ramp strategy if provided
      if options[:ramp]
        ramp_config = self.class.parse_ramp_strategy(options[:ramp])
        ramp[:strategy] = ramp_config[:strategy]
        ramp[:levels] = ramp_config[:levels]
      end

      thresholds[:latency_threshold_x] = options[:latency_threshold_x] if options[:latency_threshold_x]
      thresholds[:cpu_threshold] = options[:cpu_threshold] if options[:cpu_threshold]
      thresholds[:mem_threshold] = options[:mem_threshold] if options[:mem_threshold]

      output[:dir] = options[:out_dir] if options[:out_dir]
    end

    def to_yaml
      {
        'workload' => workload,
        'ramp' => ramp,
        'thresholds' => thresholds,
        'sampling' => sampling,
        'output' => output,
        'safety' => safety,
        'memory_leak' => memory_leak,
        'crawl4ai' => crawl4ai,
        'distributed' => distributed,
        'custom_scripts' => custom_scripts,
        'browser_mode' => browser_mode
      }.to_yaml
    end

    def self.parse_ramp_strategy(strategy_str)
      case strategy_str
      when /^exp:(.+)$/
        levels = ::Regexp.last_match(1).split(',').map(&:to_i)
        { strategy: 'exponential', levels: levels }
      when /^lin:(.+)$/
        levels = ::Regexp.last_match(1).split(',').map(&:to_i)
        { strategy: 'linear', levels: levels }
      when /^custom:(.+)$/
        levels = ::Regexp.last_match(1).split(',').map(&:to_i)
        { strategy: 'custom', levels: levels }
      else
        { strategy: 'exponential', levels: [1, 2, 4, 8, 16] }
      end
    end
  end
end
