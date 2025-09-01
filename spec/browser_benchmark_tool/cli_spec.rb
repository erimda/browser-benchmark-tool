# frozen_string_literal: true

require 'spec_helper'
require 'fileutils'

RSpec.describe BrowserBenchmarkTool::CLI do
  before do
    # Clean up any test files
    FileUtils.rm_f('benchmark.yml')
    FileUtils.rm_f('test_config.yml')
  end

  after do
    # Clean up test files
    FileUtils.rm_f('benchmark.yml')
    FileUtils.rm_f('test_config.yml')
  end

  describe '#init' do
    it 'creates a default configuration file' do
      expect(File.exist?('benchmark.yml')).to be false
      
      cli = described_class.new
      cli.init
      
      expect(File.exist?('benchmark.yml')).to be true
      
      content = File.read('benchmark.yml')
      expect(content).to include('workload:')
      expect(content).to include('ramp:')
      expect(content).to include('thresholds:')
      expect(content).to include('safety:')
    end

    it 'creates configuration with custom filename' do
      cli = described_class.new
      # Use Thor's invoke method to set options
      cli.invoke(:init, [], { config: 'test_config.yml' })
      
      expect(File.exist?('test_config.yml')).to be true
      expect(File.exist?('benchmark.yml')).to be false
    end
  end

  describe '#benchmark' do
    it 'runs benchmark with default configuration' do
      # Create a minimal config for testing
      config = BrowserBenchmarkTool::Config.new
      config.workload = { mode: 'playwright', engine: 'chromium', headless: true, urls: ['http://localhost:8080/ok'], per_browser_repetitions: 1, min_level_seconds: 1 }
      config.ramp = { strategy: 'exponential', levels: [1] }
      config.thresholds = { latency_threshold_x: 2.0, cpu_threshold: 0.8, mem_threshold: 0.8, error_rate_threshold: 0.05 }
      config.output = { dir: './test_artifacts', max_runtime_minutes: 1, generate_charts: false }
      config.safety = { robots_txt_respect: false, external_rate_limit_rps: 10, max_concurrent_requests: 20, request_timeout_seconds: 5, max_total_requests: 20 }
      
      File.write('benchmark.yml', config.to_yaml)
      
      cli = described_class.new
      expect { cli.benchmark }.not_to raise_error
      
      # Clean up
      FileUtils.rm_rf('./test_artifacts')
    end

    it 'runs benchmark with CLI options' do
      cli = described_class.new
      # Use Thor's invoke method to set options
      expect { cli.invoke(:benchmark, [], { urls: ['http://localhost:8080/ok'], ramp: 'exp:1', reps_per_level: 1, level_min_seconds: 1, out_dir: './test_artifacts' }) }.not_to raise_error
      
      # Clean up
      FileUtils.rm_rf('./test_artifacts')
    end

    it 'handles missing configuration file gracefully' do
      expect(File.exist?('benchmark.yml')).to be false
      
      cli = described_class.new
      expect { cli.invoke(:benchmark, [], { urls: ['http://localhost:8080/ok'], ramp: 'exp:1' }) }.not_to raise_error
      
      # Clean up
      FileUtils.rm_rf('./artifacts')
    end
  end

  describe '#load_config' do
    it 'loads configuration from YAML file' do
      config = BrowserBenchmarkTool::Config.new
      config.workload = { mode: 'playwright', engine: 'chromium', headless: true, urls: ['http://localhost:8080/ok'], per_browser_repetitions: 1, min_level_seconds: 1 }
      config.ramp = { strategy: 'exponential', levels: [1, 2] }
      config.thresholds = { latency_threshold_x: 2.0, cpu_threshold: 0.8, mem_threshold: 0.8, error_rate_threshold: 0.05 }
      config.output = { dir: './artifacts', max_runtime_minutes: 1, generate_charts: false }
      config.safety = { robots_txt_respect: false, external_rate_limit_rps: 2, max_concurrent_requests: 10, request_timeout_seconds: 5, max_total_requests: 20 }
      
      File.write('benchmark.yml', config.to_yaml)
      
      cli = described_class.new
      loaded_config = cli.send(:load_config)
      
      expect(loaded_config.workload[:urls]).to eq(['http://localhost:8080/ok'])
      expect(loaded_config.ramp[:levels]).to eq([1, 2])
      expect(loaded_config.thresholds[:latency_threshold_x]).to eq(2.0)
    end

    it 'merges CLI options with YAML configuration' do
      config = BrowserBenchmarkTool::Config.new
      config.workload = { mode: 'playwright', engine: 'chromium', headless: true, urls: ['http://localhost:8080/ok'], per_browser_repetitions: 1, min_level_seconds: 1 }
      config.ramp = { strategy: 'exponential', levels: [1, 2] }
      config.thresholds = { latency_threshold_x: 2.0, cpu_threshold: 0.8, mem_threshold: 0.8, error_rate_threshold: 0.05 }
      config.output = { dir: './artifacts', max_runtime_minutes: 1, generate_charts: false }
      config.safety = { robots_txt_respect: false, external_rate_limit_rps: 2, max_concurrent_requests: 10, request_timeout_seconds: 5, max_total_requests: 20 }
      
      File.write('benchmark.yml', config.to_yaml)
      
      cli = described_class.new
      # Set options using Thor's internal mechanism
      cli.instance_variable_set(:@options, { config: 'benchmark.yml', urls: ['http://localhost:8080/health'], ramp: 'exp:1,2' })
      
      loaded_config = cli.send(:load_config)
      
      expect(loaded_config.workload[:urls]).to eq(['http://localhost:8080/health'])
      expect(loaded_config.ramp[:levels]).to eq([1, 2])
    end

    it 'creates default config when YAML file does not exist' do
      expect(File.exist?('benchmark.yml')).to be false
      
      cli = described_class.new
      cli.instance_variable_set(:@options, { config: 'benchmark.yml', urls: ['http://localhost:8080/ok'], ramp: 'exp:1,2' })
      
      loaded_config = cli.send(:load_config)
      
      expect(loaded_config.workload[:urls]).to eq(['http://localhost:8080/ok'])
      expect(loaded_config.ramp[:levels]).to eq([1, 2]) # Should use the CLI option, not the default
    end
  end

  describe 'CLI options' do
    it 'supports all benchmark options' do
      expect(described_class.class_options.keys).to include(:config)
      
      benchmark_options = described_class.commands['benchmark'].options.keys
      expect(benchmark_options).to include(:mode, :urls, :ramp, :engine, :headless, :reps_per_level, :latency_threshold_x, :cpu_threshold, :mem_threshold, :level_min_seconds, :out_dir)
    end

    it 'has proper option descriptions' do
      benchmark_command = described_class.commands['benchmark']
      
      expect(benchmark_command.options[:mode].description).to include('Benchmark mode')
      expect(benchmark_command.options[:urls].description).to include('URLs to benchmark')
      expect(benchmark_command.options[:ramp].description).to include('Ramp strategy')
    end
  end
end
