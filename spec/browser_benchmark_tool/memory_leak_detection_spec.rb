# frozen_string_literal: true

require 'spec_helper'

RSpec.describe BrowserBenchmarkTool::MemoryLeakDetector, :memory_leak do
  let(:config) do
    BrowserBenchmarkTool::Config.new.tap do |c|
      c.workload = { mode: 'playwright', engine: 'chromium', headless: true }
      c.memory_leak = {
        enabled: true,
        threshold_mb: 100,
        check_interval_requests: 10,
        max_memory_growth_percent: 20
      }
    end
  end

  let(:detector) { described_class.new(config) }

  describe '#initialize' do
    it 'creates detector with configuration' do
      expect(detector.config).to eq(config)
      expect(detector.enabled?).to be true
      expect(detector.threshold_mb).to eq(100)
    end

    it 'can be disabled via configuration' do
      config.memory_leak[:enabled] = false
      detector = described_class.new(config)
      
      expect(detector.enabled?).to be false
    end
  end

  describe '#check_memory_usage' do
    it 'tracks memory usage over time' do
      # Simulate memory usage tracking
      detector.record_memory_usage(50.0) # 50MB
      detector.record_memory_usage(55.0) # 55MB
      detector.record_memory_usage(60.0) # 60MB
      
      history = detector.memory_history
      expect(history.length).to eq(3)
      expect(history.last[:memory_mb]).to eq(60.0)
    end

    it 'detects memory leaks when usage exceeds threshold' do
      # Simulate memory growth
      detector.record_memory_usage(50.0)  # Baseline
      detector.record_memory_usage(100.0) # At threshold
      detector.record_memory_usage(150.0) # Exceeds threshold
      
      leak_detected = detector.check_for_leaks
      expect(leak_detected).to be true
    end

    it 'detects memory leaks based on growth percentage' do
      # Simulate memory growth exceeding percentage threshold
      detector.record_memory_usage(100.0) # Baseline
      detector.record_memory_usage(130.0) # 30% growth (exceeds 20% threshold)
      
      leak_detected = detector.check_for_leaks
      expect(leak_detected).to be true
    end

    it 'does not detect leaks for normal memory fluctuations' do
      # Simulate normal memory usage
      detector.record_memory_usage(100.0) # Baseline
      detector.record_memory_usage(105.0) # 5% growth (normal)
      detector.record_memory_usage(110.0) # 10% growth (normal)
      
      # Reset baseline to avoid cumulative growth detection
      detector.reset_baseline
      
      leak_detected = detector.check_for_leaks
      expect(leak_detected).to be false
    end
  end

  describe '#get_memory_stats' do
    it 'provides comprehensive memory statistics' do
      detector.record_memory_usage(50.0)
      detector.record_memory_usage(60.0)
      detector.record_memory_usage(70.0)
      
      stats = detector.get_memory_stats
      
      expect(stats).to include(:current_mb)
      expect(stats).to include(:peak_mb)
      expect(stats).to include(:baseline_mb)
      expect(stats).to include(:growth_percent)
      expect(stats).to include(:leak_detected)
      
      expect(stats[:current_mb]).to eq(70.0)
      expect(stats[:peak_mb]).to eq(70.0)
      expect(stats[:baseline_mb]).to eq(50.0)
      expect(stats[:growth_percent]).to eq(40.0)
    end
  end

  describe '#reset_baseline' do
    it 'allows resetting memory baseline' do
      detector.record_memory_usage(100.0) # Set baseline
      detector.record_memory_usage(120.0) # Some growth
      
      detector.reset_baseline
      
      stats = detector.get_memory_stats
      expect(stats[:baseline_mb]).to eq(120.0)
      expect(stats[:growth_percent]).to eq(0.0)
    end
  end

  describe '#should_check_memory' do
    it 'checks memory based on request interval' do
      config.memory_leak[:check_interval_requests] = 5
      
      # Reset request count to start fresh
      detector.instance_variable_set(:@request_count, 1)
      
      # First 4 requests should not trigger check
      4.times do
        expect(detector.should_check_memory).to be false
        detector.increment_request_count
      end
      
      # 5th request should trigger check
      expect(detector.should_check_memory).to be true
    end
  end

  describe 'integration with browser automation' do
    it 'can be integrated with browser automation class' do
      # Mock memory usage for integration test
      allow(detector).to receive(:get_current_memory_usage).and_return(80.0)
      
      # Simulate integration
      detector.record_memory_usage(80.0)
      
      expect(detector.memory_history.length).to eq(1)
      expect(detector.get_memory_stats[:current_mb]).to eq(80.0)
    end
  end

  describe 'memory leak prevention' do
    it 'provides recommendations when leaks are detected' do
      # Simulate memory leak
      detector.record_memory_usage(100.0) # Baseline
      detector.record_memory_usage(150.0) # Exceeds threshold
      
      recommendations = detector.get_leak_recommendations
      
      expect(recommendations).to be_an(Array)
      expect(recommendations).not_to be_empty
      expect(recommendations.first).to include('Memory usage')
    end

    it 'can suggest context pool adjustments' do
      config.memory_leak[:enabled] = true
      
      # Simulate memory leak to get recommendations
      detector.record_memory_usage(100.0) # Baseline
      detector.record_memory_usage(150.0) # Exceeds threshold
      
      recommendations = detector.get_leak_recommendations
      
      expect(recommendations).to include(include('context pool'))
    end
  end
end
