# frozen_string_literal: true

require 'spec_helper'

RSpec.describe BrowserBenchmarkTool::BrowserModeOptions, :browser_mode do
  let(:config) do
    BrowserBenchmarkTool::Config.new.tap do |c|
      c.workload = { mode: 'playwright', engine: 'chromium', headless: true }
      c.browser_mode = {
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
    end
  end

  let(:browser_mode) { described_class.new(config) }

  describe '#initialize' do
    it 'creates browser mode manager with configuration' do
      expect(browser_mode.config).to eq(config)
      expect(browser_mode.mode).to eq('context')
      expect(browser_mode.context_pool_size).to eq(5)
      expect(browser_mode.process_limit).to eq(3)
    end

    it 'can be configured for process mode' do
      config.browser_mode[:mode] = 'process'
      browser_mode = described_class.new(config)
      
      expect(browser_mode.mode).to eq('process')
      expect(browser_mode.process_mode?).to be true
      expect(browser_mode.context_mode?).to be false
    end

    it 'can be configured for context mode' do
      config.browser_mode[:mode] = 'context'
      browser_mode = described_class.new(config)
      
      expect(browser_mode.mode).to eq('context')
      expect(browser_mode.context_mode?).to be true
      expect(browser_mode.process_mode?).to be false
    end
  end

  describe '#context_mode?' do
    it 'returns true when mode is context' do
      config.browser_mode[:mode] = 'context'
      browser_mode = described_class.new(config)
      
      expect(browser_mode.context_mode?).to be true
    end

    it 'returns false when mode is process' do
      config.browser_mode[:mode] = 'process'
      browser_mode = described_class.new(config)
      
      expect(browser_mode.context_mode?).to be false
    end
  end

  describe '#process_mode?' do
    it 'returns true when mode is process' do
      config.browser_mode[:mode] = 'process'
      browser_mode = described_class.new(config)
      
      expect(browser_mode.process_mode?).to be true
    end

    it 'returns false when mode is context' do
      config.browser_mode[:mode] = 'context'
      browser_mode = described_class.new(config)
      
      expect(browser_mode.process_mode?).to be false
    end
  end

  describe '#get_browser_instance' do
    it 'returns context instance when in context mode' do
      config.browser_mode[:mode] = 'context'
      browser_mode = described_class.new(config)
      
      instance = browser_mode.get_browser_instance
      
      expect(instance).to be_a(Hash)
      expect(instance[:type]).to eq('context')
      expect(instance[:id]).not_to be_nil
      expect(instance[:created_at]).not_to be_nil
    end

    it 'returns process instance when in process mode' do
      config.browser_mode[:mode] = 'process'
      browser_mode = described_class.new(config)
      
      instance = browser_mode.get_browser_instance
      
      expect(instance).to be_a(Hash)
      expect(instance[:type]).to eq('process')
      expect(instance[:id]).not_to be_nil
      expect(instance[:created_at]).not_to be_nil
    end

    it 'reuses existing instances when pooling is enabled' do
      config.browser_mode[:mode] = 'context'
      config.browser_mode[:enable_context_pooling] = true
      browser_mode = described_class.new(config)
      
      instance1 = browser_mode.get_browser_instance
      browser_mode.release_browser_instance(instance1[:id])
      instance2 = browser_mode.get_browser_instance
      
      expect(instance1[:id]).to eq(instance2[:id])
    end

    it 'creates new instances when pooling is disabled' do
      config.browser_mode[:mode] = 'context'
      config.browser_mode[:enable_context_pooling] = false
      browser_mode = described_class.new(config)
      
      instance1 = browser_mode.get_browser_instance
      instance2 = browser_mode.get_browser_instance
      
      expect(instance1[:id]).not_to eq(instance2[:id])
    end
  end

  describe '#release_browser_instance' do
    it 'releases context instance back to pool' do
      config.browser_mode[:mode] = 'context'
      browser_mode = described_class.new(config)
      
      instance = browser_mode.get_browser_instance
      result = browser_mode.release_browser_instance(instance[:id])
      
      expect(result[:success]).to be true
      expect(result[:released]).to be true
    end

    it 'terminates process instance' do
      config.browser_mode[:mode] = 'process'
      browser_mode = described_class.new(config)
      
      instance = browser_mode.get_browser_instance
      result = browser_mode.release_browser_instance(instance[:id])
      
      expect(result[:success]).to be true
      expect(result[:terminated]).to be true
    end

    it 'handles invalid instance ID gracefully' do
      result = browser_mode.release_browser_instance('invalid-id')
      
      expect(result[:success]).to be false
      expect(result[:error]).to include('Instance not found')
    end
  end

  describe '#get_pool_status' do
    it 'returns context pool status when in context mode' do
      config.browser_mode[:mode] = 'context'
      browser_mode = described_class.new(config)
      
      status = browser_mode.get_pool_status
      
      expect(status[:mode]).to eq('context')
      expect(status[:total_instances]).to eq(0)
      expect(status[:available_instances]).to eq(0)
      expect(status[:in_use_instances]).to eq(0)
    end

    it 'returns process pool status when in process mode' do
      config.browser_mode[:mode] = 'process'
      browser_mode = described_class.new(config)
      
      status = browser_mode.get_pool_status
      
      expect(status[:mode]).to eq('process')
      expect(status[:total_instances]).to eq(0)
      expect(status[:available_instances]).to eq(0)
      expect(status[:in_use_instances]).to eq(0)
    end

    it 'tracks instance usage correctly' do
      config.browser_mode[:mode] = 'context'
      browser_mode = described_class.new(config)
      
      # Get an instance
      instance = browser_mode.get_browser_instance
      status = browser_mode.get_pool_status
      
      expect(status[:total_instances]).to eq(1)
      expect(status[:in_use_instances]).to eq(1)
      expect(status[:available_instances]).to eq(0)
      
      # Release the instance
      browser_mode.release_browser_instance(instance[:id])
      status = browser_mode.get_pool_status
      
      expect(status[:total_instances]).to eq(1)
      expect(status[:in_use_instances]).to eq(0)
      expect(status[:available_instances]).to eq(1)
    end
  end

  describe '#configure_for_workload' do
    it 'adjusts pool size based on concurrency requirements' do
      config.browser_mode[:mode] = 'context'
      browser_mode = described_class.new(config)
      
      workload_config = { concurrency: 10, urls: ['https://example.com'] * 10 }
      result = browser_mode.configure_for_workload(workload_config)
      
      expect(result[:success]).to be true
      expect(result[:pool_size_adjusted]).to be true
      expect(result[:new_pool_size]).to eq(10)
    end

    it 'switches to process mode for high isolation requirements' do
      config.browser_mode[:mode] = 'context'
      browser_mode = described_class.new(config)
      
      workload_config = { 
        concurrency: 5, 
        isolation_level: 'high',
        urls: ['https://example.com'] * 5 
      }
      result = browser_mode.configure_for_workload(workload_config)
      
      expect(result[:success]).to be true
      expect(result[:mode_switched]).to be true
      expect(result[:new_mode]).to eq('process')
    end

    it 'optimizes memory usage for large workloads' do
      config.browser_mode[:mode] = 'context'
      config.browser_mode[:memory_per_context] = 100
      browser_mode = described_class.new(config)
      
      workload_config = { 
        concurrency: 20, 
        memory_intensive: true,
        urls: ['https://example.com'] * 20 
      }
      result = browser_mode.configure_for_workload(workload_config)
      
      expect(result[:success]).to be true
      expect(result[:memory_optimized]).to be true
      expect(result[:memory_per_instance]).to be < 100
    end
  end

  describe '#get_performance_metrics' do
    it 'returns context mode performance metrics' do
      config.browser_mode[:mode] = 'context'
      browser_mode = described_class.new(config)
      
      metrics = browser_mode.get_performance_metrics
      
      expect(metrics[:mode]).to eq('context')
      expect(metrics[:memory_usage]).to be_a(Numeric)
      expect(metrics[:instance_count]).to be_a(Numeric)
      expect(metrics[:pool_efficiency]).to be_a(Numeric)
    end

    it 'returns process mode performance metrics' do
      config.browser_mode[:mode] = 'process'
      browser_mode = described_class.new(config)
      
      metrics = browser_mode.get_performance_metrics
      
      expect(metrics[:mode]).to eq('process')
      expect(metrics[:memory_usage]).to be_a(Numeric)
      expect(metrics[:instance_count]).to be_a(Numeric)
      expect(metrics[:isolation_level]).to be_a(String)
    end

    it 'tracks memory usage per instance type' do
      config.browser_mode[:mode] = 'context'
      config.browser_mode[:memory_per_context] = 100
      browser_mode = described_class.new(config)
      
      # Create some instances
      3.times { browser_mode.get_browser_instance }
      metrics = browser_mode.get_performance_metrics
      
      expect(metrics[:total_memory]).to eq(300)
      expect(metrics[:memory_per_instance]).to eq(100)
    end
  end

  describe '#cleanup_resources' do
    it 'releases all context instances' do
      config.browser_mode[:mode] = 'context'
      browser_mode = described_class.new(config)
      
      # Create instances
      3.times { browser_mode.get_browser_instance }
      initial_status = browser_mode.get_pool_status
      
      expect(initial_status[:total_instances]).to eq(3)
      
      # Cleanup
      result = browser_mode.cleanup_resources
      
      expect(result[:success]).to be true
      expect(result[:instances_released]).to eq(3)
      
      final_status = browser_mode.get_pool_status
      expect(final_status[:total_instances]).to eq(0)
    end

    it 'terminates all process instances' do
      config.browser_mode[:mode] = 'process'
      browser_mode = described_class.new(config)
      
      # Create instances
      2.times { browser_mode.get_browser_instance }
      initial_status = browser_mode.get_pool_status
      
      expect(initial_status[:total_instances]).to eq(2)
      
      # Cleanup
      result = browser_mode.cleanup_resources
      
      expect(result[:success]).to be true
      expect(result[:processes_terminated]).to eq(2)
      
      final_status = browser_mode.get_pool_status
      expect(final_status[:total_instances]).to eq(0)
    end
  end

  describe 'integration with browser automation' do
    it 'provides browser instances to automation system' do
      config.browser_mode[:mode] = 'context'
      browser_mode = described_class.new(config)
      
      # Mock browser automation
      automation = double('BrowserAutomation')
      allow(automation).to receive(:set_browser_mode)
      allow(automation).to receive(:get_browser_instance)
      
      browser_mode.integrate_with_automation(automation)
      
      expect(automation).to have_received(:set_browser_mode)
    end

    it 'handles mode switching during benchmark execution' do
      config.browser_mode[:mode] = 'context'
      browser_mode = described_class.new(config)
      
      # Start with context mode
      expect(browser_mode.context_mode?).to be true
      
      # Switch to process mode
      result = browser_mode.switch_mode('process')
      
      expect(result[:success]).to be true
      expect(result[:mode_changed]).to be true
      expect(browser_mode.process_mode?).to be true
    end
  end
end
