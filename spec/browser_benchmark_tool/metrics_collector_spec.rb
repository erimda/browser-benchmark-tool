# frozen_string_literal: true

require 'spec_helper'

RSpec.describe BrowserBenchmarkTool::MetricsCollector do
  let(:collector) { described_class.new }

  describe '#initialize' do
    it 'creates a metrics collector with empty samples and start time' do
      expect(collector.instance_variable_get(:@samples)).to eq([])
      expect(collector.instance_variable_get(:@start_time)).to be_a(Time)
    end
  end

  describe '#collect_host_metrics' do
    context 'with real system metrics' do
      before do
        # Skip if system metrics are not available
        skip('System metrics not available') unless system_metrics_available?
      end

      it 'collects real CPU usage metrics' do
        metrics = collector.collect_host_metrics
        expect(metrics[:cpu_usage]).to be_a(Float)
        expect(metrics[:cpu_usage]).to be_between(0.0, 1.0)
      end

      it 'collects real memory usage metrics' do
        metrics = collector.collect_host_metrics
        expect(metrics[:memory_usage]).to be_a(Float)
        expect(metrics[:memory_usage]).to be_between(0.0, 1.0)
      end

      it 'collects real load average metrics' do
        metrics = collector.collect_host_metrics
        expect(metrics[:load_average]).to be_an(Array)
        expect(metrics[:load_average].length).to eq(3)
        metrics[:load_average].each do |load|
          expect(load).to be_a(Float)
          expect(load).to be >= 0.0
        end
      end

      it 'includes timestamp and uptime' do
        metrics = collector.collect_host_metrics
        expect(metrics[:timestamp]).to match(/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d{3}Z$/)
        expect(metrics[:uptime]).to be > 0
      end
    end

    context 'with simulated metrics (fallback)' do
      it 'provides simulated metrics when real ones are not available' do
        allow(collector).to receive(:system_metrics_available?).and_return(false)
        
        metrics = collector.collect_host_metrics
        expect(metrics[:cpu_usage]).to be_a(Float)
        expect(metrics[:memory_usage]).to be_a(Float)
        expect(metrics[:load_average]).to be_an(Array)
        expect(metrics[:timestamp]).to match(/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d{3}Z$/)
        expect(metrics[:uptime]).to be > 0
      end
    end
  end

  describe '#collect_process_metrics' do
    context 'with real process metrics' do
      before do
        # Skip if process metrics are not available
        skip('Process metrics not available') unless process_metrics_available?
      end

      it 'collects real process metrics for specified processes' do
        process_names = %w[ruby chromium]
        metrics = collector.collect_process_metrics(process_names)
        
        expect(metrics).to be_an(Array)
        metrics.each do |process|
          expect(process).to include(:pid, :comm, :cpu_percent, :memory_mb, :vsize_mb)
          expect(process[:pid]).to be_a(Integer)
          expect(process[:pid]).to be > 0
          expect(process[:comm]).to be_a(String)
          expect(process[:cpu_percent]).to be_a(Float)
          expect(process[:memory_mb]).to be_a(Float)
          expect(process[:vsize_mb]).to be_a(Float)
        end
      end

      it 'handles empty process list gracefully' do
        metrics = collector.collect_process_metrics([])
        expect(metrics).to eq([])
      end
    end

    context 'with simulated process metrics (fallback)' do
      it 'provides simulated metrics when real ones are not available' do
        allow(collector).to receive(:process_metrics_available?).and_return(false)
        
        metrics = collector.collect_process_metrics(%w[chromium])
        expect(metrics).to be_an(Array)
        expect(metrics.length).to eq(1)
        
        process = metrics.first
        expect(process).to include(:pid, :comm, :cpu_percent, :memory_mb, :vsize_mb)
        expect(process[:pid]).to be_between(1000, 9999)
        expect(process[:comm]).to eq('chromium-simulated')
        expect(process[:cpu_percent]).to be_between(5.0, 25.0)
        expect(process[:memory_mb]).to be_between(100.0, 500.0)
        expect(process[:vsize_mb]).to be_between(200.0, 1000.0)
      end
    end
  end

  describe '#add_sample' do
    let(:results) do
      [
        { success: true, duration_ms: 100 },
        { success: true, duration_ms: 150 },
        { success: false, error: 'Network error' }
      ]
    end

    let(:host_metrics) do
      {
        timestamp: Time.now.strftime('%Y-%m-%dT%H:%M:%S.%LZ'),
        cpu_usage: 0.5,
        memory_usage: 0.6,
        load_average: [1.2, 1.1, 1.0],
        uptime: 300.0
      }
    end

    let(:process_metrics) do
      [
        {
          pid: 1234,
          comm: 'chromium',
          cpu_percent: 15.5,
          memory_mb: 250.0,
          vsize_mb: 500.0
        }
      ]
    end

    it 'adds a sample with correct structure' do
      sample = collector.add_sample(2, results, host_metrics, process_metrics)
      
      expect(sample).to include(:timestamp, :level, :tasks, :latency_ms, :host, :processes)
      expect(sample[:level]).to eq(2)
      expect(sample[:tasks][:attempted]).to eq(3)
      expect(sample[:tasks][:successful]).to eq(2)
      expect(sample[:tasks][:failed]).to eq(1)
      expect(sample[:tasks][:error_rate]).to eq(1.0 / 3.0)
    end

    it 'calculates latency percentiles correctly' do
      sample = collector.add_sample(1, results, host_metrics, process_metrics)
      
      expect(sample[:latency_ms]).to include(:p50, :p90, :p95, :p99)
      expect(sample[:latency_ms][:p50]).to eq(125.0) # Median of [100, 150]
      expect(sample[:latency_ms][:p95]).to eq(150)   # 95th percentile
    end

    it 'handles empty results gracefully' do
      sample = collector.add_sample(1, [], host_metrics, process_metrics)
      
      expect(sample[:tasks][:attempted]).to eq(0)
      expect(sample[:tasks][:successful]).to eq(0)
      expect(sample[:tasks][:failed]).to eq(0)
      expect(sample[:tasks][:error_rate]).to eq(0.0)
    end

    it 'handles results with missing duration' do
      results_without_duration = [
        { success: true },
        { success: false, error: 'Error' }
      ]
      
      sample = collector.add_sample(1, results_without_duration, host_metrics, process_metrics)
      
      expect(sample[:tasks][:attempted]).to eq(2)
      expect(sample[:tasks][:successful]).to eq(1)
      expect(sample[:tasks][:failed]).to eq(1)
    end
  end

  describe '#get_samples' do
    it 'returns all collected samples' do
      expect(collector.get_samples).to eq([])
      
      results = [{ success: true, duration_ms: 100 }]
      host_metrics = { cpu_usage: 0.5, memory_usage: 0.6, load_average: [1.0], uptime: 100.0 }
      process_metrics = []
      
      collector.add_sample(1, results, host_metrics, process_metrics)
      expect(collector.get_samples.length).to eq(1)
      
      collector.add_sample(2, results, host_metrics, process_metrics)
      expect(collector.get_samples.length).to eq(2)
    end
  end

  describe '#calculate_baseline' do
    it 'returns nil for empty samples' do
      expect(collector.calculate_baseline).to be_nil
    end

    it 'returns baseline from first level (concurrency = 1)' do
      results = [{ success: true, duration_ms: 100 }]
      host_metrics = { cpu_usage: 0.5, memory_usage: 0.6, load_average: [1.0], uptime: 100.0 }
      process_metrics = []
      
      collector.add_sample(1, results, host_metrics, process_metrics)
      collector.add_sample(2, results, host_metrics, process_metrics)
      
      baseline = collector.calculate_baseline
      expect(baseline).to include(:p50, :p95, :p99)
      expect(baseline[:p50]).to eq(100)
    end

    it 'returns nil if no baseline level found' do
      results = [{ success: true, duration_ms: 100 }]
      host_metrics = { cpu_usage: 0.5, memory_usage: 0.6, load_average: [1.0], uptime: 100.0 }
      process_metrics = []
      
      collector.add_sample(2, results, host_metrics, process_metrics)
      
      expect(collector.calculate_baseline).to be_nil
    end
  end

  describe 'performance characteristics' do
    it 'handles large numbers of samples efficiently' do
      results = [{ success: true, duration_ms: 100 }]
      host_metrics = { cpu_usage: 0.5, memory_usage: 0.6, load_average: [1.0], uptime: 100.0 }
      process_metrics = []
      
      start_time = Time.now
      
      # Add 1000 samples
      1000.times do |i|
        collector.add_sample(i % 10 + 1, results, host_metrics, process_metrics)
      end
      
      end_time = Time.now
      duration = end_time - start_time
      
      expect(duration).to be < 5.0 # Should complete within 5 seconds
      expect(collector.get_samples.length).to eq(1000)
    end
  end

  private

  def system_metrics_available?
    # Check if we can collect real system metrics
    begin
      require 'sys-proctable'
      true
    rescue LoadError
      false
    end
  end

  def process_metrics_available?
    # Check if we can collect real process metrics
    begin
      require 'sys-proctable'
      true
    rescue LoadError
      false
    end
  end
end
