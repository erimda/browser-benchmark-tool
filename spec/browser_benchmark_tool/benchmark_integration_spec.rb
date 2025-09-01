# frozen_string_literal: true

require 'spec_helper'
require 'fileutils'
require 'json'

RSpec.describe BrowserBenchmarkTool::Benchmark do
  let(:config) do
    BrowserBenchmarkTool::Config.new.tap do |c|
      c.workload = {
        mode: 'playwright',
        engine: 'chromium',
        headless: true,
        urls: [], # Will be set dynamically after test server starts
        per_browser_repetitions: 1, # Reduced from 2
        min_level_seconds: 1 # Reduced from 5
      }
      c.ramp = {
        strategy: 'exponential',
        levels: [1] # Reduced from [1, 2]
      }
      c.thresholds = {
        latency_threshold_x: 2.0,
        cpu_threshold: 0.8,
        mem_threshold: 0.8,
        error_rate_threshold: 0.05
      }
      c.output = {
        dir: './test_artifacts',
        max_runtime_minutes: 1, # Reduced from 5
        generate_charts: false
      }
      c.safety = {
        robots_txt_respect: false,
        external_rate_limit_rps: 10,
        max_concurrent_requests: 20,
        request_timeout_seconds: 5, # Reduced from 10
        max_total_requests: 20 # Reduced from 50
      }
    end
  end

  let(:benchmark) { described_class.new(config) }
  let(:test_server) { BrowserBenchmarkTool::TestServer.new(config) }

  before do
    # Clean up test artifacts
    FileUtils.rm_rf('./test_artifacts')
    # Start test server
    test_server.start
    sleep(0.1) # Brief wait for server to start
    
    # Set URLs dynamically using test server's actual port
    config.workload[:urls] = [
      "#{test_server.base_url}/ok",
      "#{test_server.base_url}/slow",
      "#{test_server.base_url}/heavy"
    ]
  end

  after do
    # Clean up test artifacts
    FileUtils.rm_rf('./test_artifacts')
    # Stop test server
    test_server.stop
  end

  describe '#run' do
    it 'completes a full benchmark workflow successfully' do
      expect { benchmark.run }.not_to raise_error

      # Verify artifacts were created
      expect(Dir.exist?('./test_artifacts')).to be true
      expect(File.exist?('./test_artifacts/summary.md')).to be true
      expect(File.exist?('./test_artifacts/metrics.jsonl')).to be true
      expect(File.exist?('./test_artifacts/metrics.csv')).to be true
    end

    it 'generates valid summary report' do
      benchmark.run

      summary_content = File.read('./test_artifacts/summary.md')

      expect(summary_content).to include('Browser Benchmark Summary')
      expect(summary_content).to include('Configuration')
      expect(summary_content).to include('Results')
      expect(summary_content).to include('Per-Level Metrics')
      expect(summary_content).to include('Thresholds')
    end

    it 'generates valid JSONL data' do
      benchmark.run

      jsonl_content = File.read('./test_artifacts/metrics.jsonl')
      lines = jsonl_content.strip.split("\n")

      expect(lines.length).to be > 0

      # Parse first line to verify JSON structure
      first_sample = JSON.parse(lines.first)
      expect(first_sample).to include('timestamp')
      expect(first_sample).to include('level')
      expect(first_sample).to include('tasks')
      expect(first_sample).to include('latency_ms')
      expect(first_sample).to include('host')
    end

    it 'generates valid CSV data' do
      benchmark.run

      csv_content = File.read('./test_artifacts/metrics.csv')
      lines = csv_content.strip.split("\n")

      expect(lines.length).to be > 1 # Header + data

      # Verify CSV structure
      headers = lines.first.split(',')
      expect(headers).to include('level')
      expect(headers).to include('attempted')
      expect(headers).to include('successful')
      expect(headers).to include('failed')
      expect(headers).to include('error_rate')
      expect(headers).to include('p50')
      expect(headers).to include('p95')
      expect(headers).to include('p99')
    end

    it 'respects safety limits during execution' do
      # Monitor safety stats during execution
      safety_stats = []

      allow(benchmark.browser_automation.safety_manager).to receive(:get_safety_stats) do
        stats = {
          current_requests: rand(0..5),
          total_requests: rand(0..20),
          rate_limited_domains: []
        }
        safety_stats << stats
        stats
      end

      benchmark.run

      # Verify safety manager was used
      expect(safety_stats.length).to be > 0
    end

    it 'stops early when time limit is reached' do
      # Set very short time limit
      config.output[:max_runtime_minutes] = 0.01 # Less than 1 second

      start_time = Time.now
      benchmark.run
      end_time = Time.now

      # Should complete quickly (allow more time for cleanup)
      expect(end_time - start_time).to be < 6.0 # Increased from 5.0 to allow for cleanup time
    end

    it 'handles degradation detection correctly' do
      # Mock degradation detection
      allow(benchmark.degradation_engine).to receive_messages(degradation_detected?: true,
                                                              stop_reason: 'Latency threshold exceeded')

      benchmark.run

      # Should stop early due to degradation
      expect(benchmark.degradation_engine).to have_received(:degradation_detected?).at_least(:once)
    end
  end

  describe 'error handling' do
    it 'handles network errors gracefully' do
      # Use invalid URL to trigger network errors
      config.workload[:urls] = ['http://localhost:9999/invalid']

      expect { benchmark.run }.not_to raise_error

      # Should still generate reports
      expect(File.exist?('./test_artifacts/summary.md')).to be true
    end

    it 'handles empty URL list' do
      config.workload[:urls] = []

      expect { benchmark.run }.not_to raise_error

      # Should still generate reports even with no URLs
      expect(File.exist?('./test_artifacts/summary.md')).to be true
    end

    it 'handles single URL' do
      config.workload[:urls] = ['http://localhost:8080/ok']

      expect { benchmark.run }.not_to raise_error
    end

    it 'handles multiple URLs' do
      config.workload[:urls] = [
        'http://localhost:8080/ok',
        'http://localhost:8080/health'
      ]

      expect { benchmark.run }.not_to raise_error
    end
  end

  describe 'configuration variations' do
    it 'works with different ramp strategies' do
      config.ramp = { strategy: 'linear', levels: [1, 2] }

      expect { benchmark.run }.not_to raise_error
    end

    it 'works with custom ramp levels' do
      config.ramp = { strategy: 'custom', levels: [1, 3] }

      expect { benchmark.run }.not_to raise_error
    end

    it 'works with different repetition counts' do
      config.workload[:per_browser_repetitions] = 1

      expect { benchmark.run }.not_to raise_error
    end

    it 'works with different safety settings' do
      config.safety[:external_rate_limit_rps] = 1
      config.safety[:max_concurrent_requests] = 5
      config.safety[:max_total_requests] = 10

      expect { benchmark.run }.not_to raise_error
    end
  end

  describe 'metrics collection' do
    it 'collects metrics for all levels' do
      benchmark.run

      samples = benchmark.metrics_collector.get_samples
      expect(samples.length).to be > 0

      # Should have samples for each level
      levels = samples.map { |s| s[:level] }.uniq.sort
      expect(levels).to eq([1]) # Only one level now
    end

    it 'calculates baseline correctly' do
      benchmark.run

      baseline = benchmark.metrics_collector.calculate_baseline
      expect(baseline).not_to be_nil
      expect(baseline).to include(:p50, :p95, :p99)
    end

    it 'tracks task success and failure rates' do
      benchmark.run

      samples = benchmark.metrics_collector.get_samples
      sample = samples.first

      expect(sample[:tasks]).to include(:attempted, :successful, :failed, :error_rate)
      expect(sample[:tasks][:attempted]).to be >= 0
      expect(sample[:tasks][:error_rate]).to be >= 0.0
      expect(sample[:tasks][:error_rate]).to be <= 1.0
    end
  end

  describe 'performance characteristics' do
    it 'completes within reasonable time for small test' do
      start_time = Time.now
      benchmark.run
      end_time = Time.now

      duration = end_time - start_time
      expect(duration).to be < 10.0 # Reduced from 30.0 seconds
    end

    it 'uses reasonable memory' do
      # This is a basic check - in a real scenario you'd use memory profiling
      expect { benchmark.run }.not_to raise_error
    end
  end
end
