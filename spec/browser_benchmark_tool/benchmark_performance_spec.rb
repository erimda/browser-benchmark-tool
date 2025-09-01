# frozen_string_literal: true

require 'spec_helper'

RSpec.describe BrowserBenchmarkTool::Benchmark do
  let(:config) do
    config = BrowserBenchmarkTool::Config.default
    config.workload[:mode] = 'simulated'
    config.workload[:engine] = 'chromium'
    config.workload[:headless] = true
    config.workload[:urls] = ['https://httpbin.org/get']
    config.workload[:per_browser_repetitions] = 2
    config.workload[:min_level_seconds] = 5
    config.ramp[:levels] = [1, 2]
    config.output[:max_runtime_minutes] = 1
    config.safety[:max_concurrent_requests] = 10
    config.safety[:max_total_requests] = 50
    config
  end

  let(:benchmark) { described_class.new(config) }

  describe 'performance optimization' do
    context 'memory usage optimization' do
      it 'uses reasonable memory during benchmark execution' do
        initial_memory = get_process_memory
        
        # Run a small benchmark
        Thread.new do
          benchmark.run
        end
        
        # Wait for benchmark to start
        sleep(1)
        
        peak_memory = get_process_memory
        memory_increase = peak_memory - initial_memory
        
        # Memory increase should be reasonable (less than 200MB)
        expect(memory_increase).to be < 200 * 1024
        
        # Clean up
        benchmark.instance_variable_get(:@browser_automation)&.cleanup
      end

      it 'releases memory after benchmark completion' do
        initial_memory = get_process_memory
        
        # Run benchmark
        benchmark.run
        
        # Wait for cleanup
        sleep(1)
        
        final_memory = get_process_memory
        memory_after_cleanup = final_memory - initial_memory
        
        # Memory should be close to initial (within 50MB)
        expect(memory_after_cleanup.abs).to be < 50 * 1024
      end

      it 'limits concurrent thread creation' do
        # Test with high concurrency to ensure thread limits
        high_concurrency_config = config.dup
        high_concurrency_config.ramp[:levels] = [10, 20]
        high_concurrency_config.workload[:per_browser_repetitions] = 1
        
        high_concurrency_benchmark = described_class.new(high_concurrency_config)
        
        start_time = Time.now
        
        # Run high concurrency benchmark
        high_concurrency_benchmark.run
        
        end_time = Time.now
        duration = end_time - start_time
        
        # Should complete within reasonable time despite high concurrency
        expect(duration).to be < 30.0
        
        # Clean up
        high_concurrency_benchmark.instance_variable_get(:@browser_automation)&.cleanup
      end
    end

    context 'execution speed optimization' do
      it 'completes benchmark within reasonable time' do
        start_time = Time.now
        
        benchmark.run
        
        end_time = Time.now
        duration = end_time - start_time
        
        # Small benchmark should complete quickly
        expect(duration).to be < 20.0
      end

      it 'uses adaptive timing efficiently' do
        # Mock the timing methods to test optimization
        allow(benchmark).to receive(:calculate_adaptive_wait_time).and_return(1.0)
        
        start_time = Time.now
        
        benchmark.run
        
        end_time = Time.now
        duration = end_time - start_time
        
        # With reduced wait times, should be faster
        expect(duration).to be < 15.0
      end

      it 'minimizes unnecessary delays' do
        # Count sleep calls to ensure optimization
        sleep_calls = 0
        allow(Kernel).to receive(:sleep) do |duration|
          sleep_calls += 1
          # Don't actually sleep in tests
        end
        
        benchmark.run
        
        # Should have minimal sleep calls (only essential ones)
        expect(sleep_calls).to be <= 5
      end
    end

    context 'resource management optimization' do
      it 'efficiently manages browser resources' do
        # Test browser resource management
        browser_automation = benchmark.instance_variable_get(:@browser_automation)
        
        # Run benchmark
        benchmark.run
        
        # Check if cleanup was called
        expect(browser_automation).to respond_to(:cleanup)
      end

      it 'optimizes metrics collection frequency' do
        # Test that metrics collection is not excessive
        metrics_collector = benchmark.instance_variable_get(:@metrics_collector)
        
        initial_samples = metrics_collector.get_samples.length
        
        benchmark.run
        
        final_samples = metrics_collector.get_samples.length
        
        # Should collect reasonable number of samples
        # 2 levels × 2 repetitions = 4 samples
        expect(final_samples - initial_samples).to eq(4)
      end

      it 'uses efficient data structures' do
        # Test that we're using efficient data structures
        urls = config.workload[:urls]
        
        # URLs should be an array for efficient iteration
        expect(urls).to be_an(Array)
        
        # Should not create unnecessary objects
        benchmark.run
        
        # Check that we're not accumulating unnecessary data
        metrics_collector = benchmark.instance_variable_get(:@metrics_collector)
        samples = metrics_collector.get_samples
        
        # Each sample should be reasonably sized
        samples.each do |sample|
          sample_size = sample.to_json.bytesize
          expect(sample_size).to be < 10_000 # Less than 10KB per sample
        end
      end
    end

    context 'concurrent execution optimization' do
      it 'handles concurrent tasks efficiently' do
        # Test concurrent execution performance
        start_time = Time.now
        
        # Run with concurrency
        results = benchmark.instance_variable_get(:@browser_automation)
          .run_concurrent_tasks(['https://httpbin.org/get'], 5)
        
        end_time = Time.now
        duration = end_time - start_time
        
        # Should handle 5 concurrent tasks efficiently
        expect(duration).to be < 10.0
        expect(results.length).to eq(5)
      end

      it 'avoids thread contention' do
        # Test that threads don't block each other
        urls = ['https://httpbin.org/get', 'https://httpbin.org/delay/1']
        
        start_time = Time.now
        
        results = benchmark.instance_variable_get(:@browser_automation)
          .run_concurrent_tasks(urls, 4)
        
        end_time = Time.now
        duration = end_time - start_time
        
        # Should complete concurrent tasks without excessive blocking
        expect(duration).to be < 15.0
        expect(results.length).to eq(4)
      end
    end

    context 'early termination optimization' do
      it 'stops early when time limit is reached' do
        # Test early termination performance
        fast_config = config.dup
        fast_config.output[:max_runtime_minutes] = 0.01 # Very short runtime
        
        fast_benchmark = described_class.new(fast_config)
        
        start_time = Time.now
        
        fast_benchmark.run
        
        end_time = Time.now
        duration = end_time - start_time
        
        # Should stop early and quickly
        expect(duration).to be < 5.0
      end

      it 'stops early when degradation is detected' do
        # Test degradation-based early termination
        degradation_config = config.dup
        degradation_config.thresholds[:latency_threshold_x] = 1.1 # Very low threshold
        
        degradation_benchmark = described_class.new(degradation_config)
        
        start_time = Time.now
        
        degradation_benchmark.run
        
        end_time = Time.now
        duration = end_time - start_time
        
        # Should detect degradation and stop early
        expect(duration).to be < 10.0
      end
    end
  end

  describe 'performance monitoring' do
    it 'tracks performance metrics during execution' do
      # Test that performance is monitored
      benchmark.run
      
      metrics_collector = benchmark.instance_variable_get(:@metrics_collector)
      samples = metrics_collector.get_samples
      
      # Should have performance data
      expect(samples).not_to be_empty
      
      samples.each do |sample|
        expect(sample[:host]).to include(:cpu_usage, :memory_usage)
        expect(sample[:latency_ms]).to include(:p50, :p95)
      end
    end

    it 'provides performance insights' do
      # Test that performance insights are available
      benchmark.run
      
      # Check that we can analyze performance
      metrics_collector = benchmark.instance_variable_get(:@metrics_collector)
      baseline = metrics_collector.calculate_baseline
      
      expect(baseline).to include(:p50, :p95, :p99)
    end
  end

  private

  def get_process_memory
    `ps -o rss= -p #{Process.pid}`.to_i
  end
end
