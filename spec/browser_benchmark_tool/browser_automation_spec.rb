# frozen_string_literal: true

require 'spec_helper'

RSpec.describe BrowserBenchmarkTool::BrowserAutomation do
  let(:config) do
    config = BrowserBenchmarkTool::Config.default
    config.workload[:mode] = 'playwright'
    config.workload[:engine] = 'chromium'
    config.workload[:headless] = true
    config.safety[:request_timeout_seconds] = 30
    config.safety[:max_concurrent_requests] = 10
    config.safety[:max_total_requests] = 100
    config
  end

  let(:automation) { described_class.new(config) }
  let(:test_urls) { ['https://httpbin.org/get', 'https://httpbin.org/delay/1'] }

  describe '#initialize' do
    it 'creates a browser automation instance with config and safety manager' do
      expect(automation.config).to eq(config)
      expect(automation.safety_manager).to be_a(BrowserBenchmarkTool::SafetyManager)
    end
  end

  describe '#run_concurrent_tasks' do
    context 'with real Playwright integration' do
      before do
        # Skip if Playwright is not available
        skip('Playwright not available') unless defined?(Playwright)
      end

      it 'runs concurrent tasks using real browser automation' do
        results = automation.run_concurrent_tasks(test_urls, 2)
        
        expect(results).to be_an(Array)
        expect(results.length).to eq(2)
        
        results.each do |result|
          expect(result).to include(:url, :success, :duration_ms, :timestamp)
          expect(result[:success]).to be(true)
          expect(result[:duration_ms]).to be > 0
        end
      end

      it 'handles different concurrency levels correctly' do
        results = automation.run_concurrent_tasks(test_urls, 1)
        expect(results.length).to eq(1)
        
        results = automation.run_concurrent_tasks(test_urls, 3)
        expect(results.length).to eq(2) # Limited by number of URLs
      end

      it 'respects safety limits during execution' do
        # Set very low limits to test safety
        config.safety[:max_concurrent_requests] = 1
        config.safety[:max_total_requests] = 2
        
        results = automation.run_concurrent_tasks(test_urls, 2)
        
        # Should still work but respect limits
        expect(results.length).to eq(2)
        results.each do |result|
          expect(result[:success]).to be(true)
        end
      end
    end

    context 'with simulated mode (fallback)' do
      let(:config) do
        config = BrowserBenchmarkTool::Config.default
        config.workload[:mode] = 'simulated'
        config.workload[:engine] = 'chromium'
        config.workload[:headless] = true
        config.safety[:request_timeout_seconds] = 30
        config.safety[:max_concurrent_requests] = 10
        config.safety[:max_total_requests] = 100
        config
      end

      it 'falls back to simulated mode when Playwright is not available' do
        results = automation.run_concurrent_tasks(test_urls, 2)
        
        expect(results).to be_an(Array)
        expect(results.length).to eq(2)
        
        results.each do |result|
          expect(result).to include(:url, :success, :duration_ms, :timestamp)
          expect(result[:success]).to be(true)
          expect(result[:duration_ms]).to be > 0
        end
      end
    end
  end

  describe 'error handling' do
    it 'handles network errors gracefully' do
      # Use URLs that will definitely cause network errors
      invalid_urls = ['http://invalid-host-that-does-not-exist-12345.com', 'http://192.168.1.999:99999/invalid']
      
      results = automation.run_concurrent_tasks(invalid_urls, 2)
      
      expect(results.length).to eq(2)
      results.each do |result|
        expect(result[:success]).to be(false)
        expect(result[:error]).not_to be_nil
        expect(result[:error]).not_to be_empty
        expect(result[:duration_ms]).to be > 0
      end
    end

    it 'handles safety limit exceeded errors' do
      # Set very low limits
      config.safety[:max_total_requests] = 0
      
      results = automation.run_concurrent_tasks(test_urls, 1)
      
      expect(results.length).to eq(1)
      expect(results.first[:success]).to be(false)
      expect(results.first[:error]).to eq('Safety limit exceeded')
    end
  end

  describe 'performance characteristics' do
    it 'completes tasks within reasonable time' do
      start_time = Time.now
      
      results = automation.run_concurrent_tasks(test_urls, 1)
      
      end_time = Time.now
      duration = end_time - start_time
      
      expect(duration).to be < 10.0 # Should complete within 10 seconds
      expect(results.first[:success]).to be(true)
    end

    it 'uses reasonable memory' do
      # This is a basic check - in a real scenario you'd want more sophisticated memory monitoring
      initial_memory = `ps -o rss= -p #{Process.pid}`.to_i
      
      results = automation.run_concurrent_tasks(test_urls, 2)
      
      final_memory = `ps -o rss= -p #{Process.pid}`.to_i
      memory_increase = final_memory - initial_memory
      
      # Memory increase should be reasonable (less than 100MB)
      expect(memory_increase).to be < 100 * 1024
      expect(results.length).to eq(2)
    end
  end
end
