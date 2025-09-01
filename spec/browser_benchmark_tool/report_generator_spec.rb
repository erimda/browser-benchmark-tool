# frozen_string_literal: true

require 'spec_helper'

RSpec.describe BrowserBenchmarkTool::ReportGenerator do
  let(:config) do
    BrowserBenchmarkTool::Config.new.tap do |c|
      c.workload = { mode: 'playwright', engine: 'chromium', headless: true }
      c.ramp = { strategy: 'exponential', levels: [1, 2, 4] }
      c.thresholds = { latency_multiplier_x: 2.0, cpu_utilization: 0.9, memory_utilization: 0.8, error_rate: 0.01 }
      c.output = { dir: './artifacts', formats: ['jsonl', 'csv', 'md'], charts: true }
    end
  end

  let(:sample_data) do
    [
      {
        timestamp: '2025-01-01T12:00:01.000Z',
        level: 1,
        tasks: { attempted: 5, successful: 5, failed: 0, error_rate: 0.0 },
        latency_ms: { p50: 100, p90: 150, p95: 200, p99: 300 },
        host: { cpu_usage: 0.3, memory_usage: 0.4, load_average: [0.5, 0.4, 0.3] },
        processes: []
      },
      {
        timestamp: '2025-01-01T12:00:02.000Z',
        level: 2,
        tasks: { attempted: 10, successful: 9, failed: 1, error_rate: 0.1 },
        latency_ms: { p50: 150, p90: 250, p95: 350, p99: 500 },
        host: { cpu_usage: 0.6, memory_usage: 0.5, load_average: [1.0, 0.8, 0.6] },
        processes: []
      }
    ]
  end

  let(:degradation_engine) do
    engine = BrowserBenchmarkTool::DegradationEngine.new(config)
    engine.set_baseline({ p50: 100, p95: 200, p99: 300 })
    engine
  end

  let(:report_generator) { described_class.new(config, sample_data, degradation_engine) }

  describe '#initialize' do
    it 'creates a report generator with config, data, and degradation engine' do
      expect(report_generator.config).to eq(config)
      expect(report_generator.samples).to eq(sample_data)
      expect(report_generator.degradation_engine).to eq(degradation_engine)
    end
  end

  describe '#generate_summary' do
    it 'generates a markdown summary report' do
      summary = report_generator.generate_summary
      
      expect(summary).to include('# Browser Benchmark Summary')
      expect(summary).to include('## Configuration')
      expect(summary).to include('## Results')
      expect(summary).to include('## Per-Level Metrics')
    end

    it 'includes configuration details' do
      summary = report_generator.generate_summary
      
      expect(summary).to include('**Mode:** playwright')
      expect(summary).to include('**Engine:** chromium')
      expect(summary).to include('**Ramp Strategy:** exponential')
      expect(summary).to include('**Levels:** 1, 2, 4')
    end

    it 'includes MSC (Maximum Sustainable Concurrency)' do
      summary = report_generator.generate_summary
      
      expect(summary).to include('**Maximum Sustainable Concurrency (MSC):**')
    end
  end

  describe '#export_jsonl' do
    it 'exports samples as JSONL format' do
      jsonl = report_generator.export_jsonl
      lines = jsonl.lines.map(&:strip).reject(&:empty?)
      
      expect(lines.length).to eq(2)
      
      first_line = JSON.parse(lines.first)
      expect(first_line['level']).to eq(1)
      expect(first_line['tasks']['attempted']).to eq(5)
      expect(first_line['latency_ms']['p95']).to eq(200)
    end
  end

  describe '#export_csv' do
    it 'exports samples as CSV format' do
      csv = report_generator.export_csv
      lines = csv.lines.map(&:strip).reject(&:empty?)
      
      expect(lines.length).to eq(3) # Header + 2 data rows
      
      expect(lines.first).to include('level,attempted,successful,failed,error_rate,p50,p95,p99,cpu_usage,memory_usage')
      expect(lines[1]).to include('1,5,5,0,0.0,100,200,300,30.0,40.0')
      expect(lines[2]).to include('2,10,9,1,10.0,150,350,500,60.0,50.0')
    end
  end

  describe '#generate_per_level_table' do
    it 'generates a formatted table of per-level metrics' do
      table = report_generator.generate_per_level_table
      
      expect(table).to include('| Level | Attempted | Successful | Failed | Error Rate | P95 (ms) | CPU % | Memory % |')
      expect(table).to include('| 1 | 5 | 5 | 0 | 0.0% | 200 | 30.0% | 40.0% |')
      expect(table).to include('| 2 | 10 | 9 | 1 | 10.0% | 350 | 60.0% | 50.0% |')
    end
  end

  describe '#save_reports' do
    let(:output_dir) { './test_artifacts' }

    before do
      FileUtils.mkdir_p(output_dir)
    end

    after do
      FileUtils.rm_rf(output_dir)
    end

    it 'saves all report formats to the output directory' do
      config.output[:dir] = output_dir
      
      report_generator.save_reports
      
      expect(File.exist?(File.join(output_dir, 'summary.md'))).to be true
      expect(File.exist?(File.join(output_dir, 'metrics.jsonl'))).to be true
      expect(File.exist?(File.join(output_dir, 'metrics.csv'))).to be true
    end

    it 'creates the output directory if it does not exist' do
      config.output[:dir] = './new_test_dir'
      
      report_generator.save_reports
      
      expect(Dir.exist?('./new_test_dir')).to be true
      FileUtils.rm_rf('./new_test_dir')
    end
  end

  describe '#get_maximum_sustainable_concurrency' do
    context 'when degradation is detected' do
      before do
        allow(degradation_engine).to receive(:degradation_detected?).and_return(true)
        allow(degradation_engine).to receive(:get_maximum_sustainable_concurrency).and_return(1)
      end

      it 'returns the MSC from degradation engine' do
        msc = report_generator.get_maximum_sustainable_concurrency
        expect(msc).to eq(1)
      end
    end

    context 'when no degradation is detected' do
      before do
        allow(degradation_engine).to receive(:degradation_detected?).and_return(false)
      end

      it 'returns the highest tested level' do
        msc = report_generator.get_maximum_sustainable_concurrency
        expect(msc).to eq(2) # Highest level in test data
      end
    end
  end
end
