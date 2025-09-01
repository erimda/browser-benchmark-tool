# frozen_string_literal: true

require 'spec_helper'

RSpec.describe BrowserBenchmarkTool::Benchmark do
  let(:config) do
    BrowserBenchmarkTool::Config.default.tap do |c|
      c.workload[:mode] = 'simulated'
      c.workload[:urls] = ['https://httpbin.org/get']
      c.workload[:per_browser_repetitions] = 2
      c.ramp[:levels] = [1, 2]
      c.output[:max_runtime_minutes] = 1
      c.output[:dir] = './artifacts'
    end
  end

  let(:benchmark) { described_class.new(config) }

  describe '#initialize' do
    it 'creates benchmark with configuration' do
      expect(benchmark.instance_variable_get(:@config)).to eq(config)
      expect(benchmark.instance_variable_get(:@max_runtime_minutes)).to eq(1)
    end

    it 'initializes components' do
      expect(benchmark.instance_variable_get(:@browser_automation)).to be_a(BrowserBenchmarkTool::BrowserAutomation)
      expect(benchmark.instance_variable_get(:@metrics_collector)).to be_a(BrowserBenchmarkTool::MetricsCollector)
      expect(benchmark.instance_variable_get(:@degradation_engine)).to be_a(BrowserBenchmarkTool::DegradationEngine)
    end
  end

  describe '#should_stop_early?' do
    it 'returns false when no start time' do
      expect(benchmark.send(:should_stop_early?)).to be false
    end

    it 'returns true when runtime exceeded' do
      benchmark.instance_variable_set(:@start_time, Time.now - 61) # 61 seconds ago
      expect(benchmark.send(:should_stop_early?)).to be true
    end

    it 'returns false when runtime not exceeded' do
      benchmark.instance_variable_set(:@start_time, Time.now - 30) # 30 seconds ago
      expect(benchmark.send(:should_stop_early?)).to be false
    end
  end

  describe '#calculate_adaptive_wait_time' do
    it 'calculates wait time for fast levels' do
      wait_time = benchmark.send(:calculate_adaptive_wait_time, 10) # 10 seconds
      expect(wait_time).to be >= 0.1
      expect(wait_time).to be <= 30
    end

    it 'calculates wait time for slow levels' do
      wait_time = benchmark.send(:calculate_adaptive_wait_time, 60) # 60 seconds
      expect(wait_time).to be >= 0.1
      expect(wait_time).to be <= 60
    end

    it 'respects minimum wait time' do
      wait_time = benchmark.send(:calculate_adaptive_wait_time, 100) # 100 seconds
      expect(wait_time).to be >= 0.1
    end
  end

  describe '#print_level_results' do
    it 'prints level results correctly' do
      results = [
        { success: true, duration_ms: 100 },
        { success: false, duration_ms: 200 }
      ]

      expect { benchmark.send(:print_level_results, 1, results, 1.5) }.to output(/Results: 1 successful, 1 failed/).to_stdout
      expect { benchmark.send(:print_level_results, 1, results, 1.5) }.to output(/Average duration: 150.0ms/).to_stdout
      expect { benchmark.send(:print_level_results, 1, results, 1.5) }.to output(/Level duration: 1.5s/).to_stdout
    end
  end

  describe '#generate_summary' do
    it 'generates summary with runtime' do
      benchmark.instance_variable_set(:@start_time, Time.now - 10)
      
      expect { benchmark.send(:generate_summary) }.to output(/Benchmark Summary/).to_stdout
      expect { benchmark.send(:generate_summary) }.to output(/Total runtime/).to_stdout
    end

    it 'shows early termination warning when applicable' do
      benchmark.instance_variable_set(:@start_time, Time.now - 61)
      
      expect { benchmark.send(:generate_summary) }.to output(/stopped early due to time limit/).to_stdout
    end
  end

  describe '#cleanup_browser' do
    it 'calls cleanup on browser automation' do
      browser_automation = instance_double(BrowserBenchmarkTool::BrowserAutomation)
      expect(browser_automation).to receive(:cleanup)
      
      benchmark.instance_variable_set(:@browser_automation, browser_automation)
      
      expect { benchmark.send(:cleanup_browser) }.to output(/Cleaning up/).to_stdout
    end
  end

  describe 'private methods' do
    it 'has expected private methods' do
      private_methods = benchmark.private_methods(false)
      
      expect(private_methods).to include(:run_level, :print_level_results, :generate_summary, :generate_reports)
      expect(private_methods).to include(:cleanup_browser, :should_stop_early?, :calculate_adaptive_wait_time)
    end
  end
end
