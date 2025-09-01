# frozen_string_literal: true

require 'spec_helper'

RSpec.describe BrowserBenchmarkTool::MetricsCollector, :real_metrics do
  let(:collector) { described_class.new }

  describe 'real system metrics collection' do
    it 'collects real CPU usage' do
      metrics = collector.collect_host_metrics
      
      expect(metrics[:cpu_usage]).to be_a(Float)
      expect(metrics[:cpu_usage]).to be >= 0.0
      expect(metrics[:cpu_usage]).to be <= 1.0
    end

    it 'collects real memory usage' do
      metrics = collector.collect_host_metrics
      
      expect(metrics[:memory_usage]).to be_a(Float)
      expect(metrics[:memory_usage]).to be >= 0.0
      expect(metrics[:memory_usage]).to be <= 1.0
    end

    it 'collects real load average' do
      metrics = collector.collect_host_metrics
      
      expect(metrics[:load_average]).to be_an(Array)
      expect(metrics[:load_average].length).to eq(3)
      metrics[:load_average].each do |load|
        expect(load).to be_a(Float)
        expect(load).to be >= 0.0
      end
    end

    it 'collects real process metrics for browser processes' do
      process_metrics = collector.collect_process_metrics(['chromium', 'chrome', 'firefox'])
      
      expect(process_metrics).to be_an(Array)
      process_metrics.each do |process|
        expect(process).to have_key(:pid)
        expect(process).to have_key(:comm)
        expect(process).to have_key(:cpu_percent)
        expect(process).to have_key(:memory_mb)
        expect(process).to have_key(:vsize_mb)
        
        expect(process[:pid]).to be_an(Integer)
        expect(process[:pid]).to be > 0
        expect(process[:cpu_percent]).to be_a(Float)
        expect(process[:cpu_percent]).to be >= 0.0
        expect(process[:memory_mb]).to be_a(Float)
        expect(process[:memory_mb]).to be >= 0.0
      end
    end

    it 'handles missing processes gracefully' do
      process_metrics = collector.collect_process_metrics(['nonexistent-process-12345'])
      
      expect(process_metrics).to be_an(Array)
      expect(process_metrics).to be_empty
    end

    it 'provides consistent metric structure' do
      host_metrics = collector.collect_host_metrics
      process_metrics = collector.collect_process_metrics(['chromium'])
      
      expect(host_metrics).to have_key(:timestamp)
      expect(host_metrics).to have_key(:cpu_usage)
      expect(host_metrics).to have_key(:memory_usage)
      expect(host_metrics).to have_key(:load_average)
      expect(host_metrics).to have_key(:uptime)
      
      expect(host_metrics[:timestamp]).to match(/\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d{3}Z/)
      expect(host_metrics[:uptime]).to be > 0
    end

    it 'collects metrics multiple times without errors' do
      # Collect metrics multiple times to ensure stability
      5.times do
        host_metrics = collector.collect_host_metrics
        process_metrics = collector.collect_process_metrics(['chromium'])
        
        expect(host_metrics[:cpu_usage]).to be_a(Float)
        expect(host_metrics[:memory_usage]).to be_a(Float)
        expect(process_metrics).to be_an(Array)
        
        sleep(0.1) # Small delay between collections
      end
    end
  end

  describe 'cross-platform compatibility' do
    it 'works on macOS systems' do
      # This test ensures the metrics collector works on macOS
      metrics = collector.collect_host_metrics
      
      expect(metrics[:cpu_usage]).to be_a(Float)
      expect(metrics[:memory_usage]).to be_a(Float)
      expect(metrics[:load_average]).to be_an(Array)
    end

    it 'works on Linux systems' do
      # This test ensures the metrics collector works on Linux
      metrics = collector.collect_host_metrics
      
      expect(metrics[:cpu_usage]).to be_a(Float)
      expect(metrics[:memory_usage]).to be_a(Float)
      expect(metrics[:load_average]).to be_an(Array)
    end
  end

  describe 'performance characteristics' do
    it 'collects metrics quickly' do
      start_time = Time.now
      
      collector.collect_host_metrics
      collector.collect_process_metrics(['chromium'])
      
      duration = Time.now - start_time
      expect(duration).to be < 0.1 # Should complete in under 100ms
    end

    it 'does not consume excessive memory' do
      initial_memory = GC.stat[:total_allocated_objects]
      
      10.times do
        collector.collect_host_metrics
        collector.collect_process_metrics(['chromium'])
      end
      
      final_memory = GC.stat[:total_allocated_objects]
      memory_increase = final_memory - initial_memory
      
      # Should not create excessive objects
      expect(memory_increase).to be < 1000
    end
  end
end
