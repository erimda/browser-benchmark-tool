# frozen_string_literal: true

require 'thor'
require 'yaml'
require_relative 'config'
require_relative 'benchmark'

module BrowserBenchmarkTool
  class CLI < Thor
    class_option :config, type: :string, default: 'benchmark.yml',
                          desc: 'Path to configuration file'

    desc 'benchmark', 'Run browser benchmark with configuration'
    option :mode, type: :string, default: 'playwright',
                  desc: 'Benchmark mode (playwright)'
    option :urls, type: :array, default: ['https://example.org'],
                  desc: 'URLs to benchmark'
    option :ramp, type: :string, default: 'exp:1,2,4,8,16,32',
                  desc: 'Ramp strategy (exp:levels or linear:max or custom:1,3,5)'
    option :engine, type: :string, default: 'chromium',
                    desc: 'Browser engine (chromium, firefox, webkit)'
    option :headless, type: :boolean, default: true,
                      desc: 'Run browsers in headless mode'
    option :reps_per_level, type: :numeric, default: 5,
                            desc: 'Repetitions per concurrency level'
    option :latency_threshold_x, type: :numeric, default: 2.0,
                                 desc: 'Latency degradation multiplier'
    option :cpu_threshold, type: :numeric, default: 0.9,
                           desc: 'CPU utilization threshold'
    option :mem_threshold, type: :numeric, default: 0.8,
                           desc: 'Memory utilization threshold'
    option :level_min_seconds, type: :numeric, default: 45,
                               desc: 'Minimum seconds per level'
    option :out_dir, type: :string, default: './artifacts',
                     desc: 'Output directory for results'
    def benchmark
      config = load_config
      benchmark = Benchmark.new(config)
      benchmark.run
    end

    desc 'init', 'Initialize a default configuration file'
    def init
      config = Config.default
      File.write(options[:config], config.to_yaml)
      puts "Created default configuration: #{options[:config]}"
    end

    private

    def load_config
      if File.exist?(options[:config])
        yaml_config = YAML.load_file(options[:config])
        config = Config.from_hash(yaml_config)
        config.merge_cli_options(options)
        config
      else
        Config.from_cli_options(options)
      end
    end
  end
end
