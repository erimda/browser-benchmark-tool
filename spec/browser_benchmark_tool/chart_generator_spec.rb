# frozen_string_literal: true

require 'spec_helper'

RSpec.describe BrowserBenchmarkTool::ChartGenerator do
  let(:config) do
    BrowserBenchmarkTool::Config.new.tap do |c|
      c.workload = { mode: 'playwright', engine: 'chromium', headless: true }
      c.ramp = { strategy: 'exponential', levels: [1, 2, 4] }
      c.output = { dir: './artifacts', charts: true }
    end
  end

  let(:sample_data) do
    [
      {
        level: 1,
        tasks: { attempted: 5, successful: 5, failed: 0, error_rate: 0.0 },
        latency_ms: { p50: 100, p90: 150, p95: 200, p99: 300 },
        host: { cpu_usage: 0.3, memory_usage: 0.4 }
      },
      {
        level: 2,
        tasks: { attempted: 10, successful: 9, failed: 1, error_rate: 0.1 },
        latency_ms: { p50: 150, p90: 250, p95: 350, p99: 500 },
        host: { cpu_usage: 0.6, memory_usage: 0.5 }
      },
      {
        level: 4,
        tasks: { attempted: 20, successful: 18, failed: 2, error_rate: 0.1 },
        latency_ms: { p50: 250, p90: 400, p95: 600, p99: 800 },
        host: { cpu_usage: 0.85, memory_usage: 0.75 }
      }
    ]
  end

  let(:chart_generator) { described_class.new(config, sample_data) }

  describe '#initialize' do
    it 'creates a chart generator with config and data' do
      expect(chart_generator.config).to eq(config)
      expect(chart_generator.samples).to eq(sample_data)
    end
  end

  describe '#generate_latency_chart' do
    it 'generates HTML chart for latency metrics' do
      chart_html = chart_generator.generate_latency_chart
      
      expect(chart_html).to include('<html>')
      expect(chart_html).to include('<script src="https://cdn.plot.ly/plotly-latest.min.js"></script>')
      expect(chart_html).to include('Latency vs Concurrency')
      expect(chart_html).to include('p50')
      expect(chart_html).to include('p95')
      expect(chart_html).to include('p99')
    end

    it 'includes chart data in JSON format' do
      chart_html = chart_generator.generate_latency_chart
      
      expect(chart_html).to include('"x":[1,2,4]')
      expect(chart_html).to include('"y":[100,150,250]') # p50 values
      expect(chart_html).to include('"y":[200,350,600]') # p95 values
    end
  end

  describe '#generate_resource_chart' do
    it 'generates HTML chart for CPU and memory usage' do
      chart_html = chart_generator.generate_resource_chart
      
      expect(chart_html).to include('<html>')
      expect(chart_html).to include('Resource Usage vs Concurrency')
      expect(chart_html).to include('CPU Usage')
      expect(chart_html).to include('Memory Usage')
    end

    it 'includes resource data in JSON format' do
      chart_html = chart_generator.generate_resource_chart
      
      expect(chart_html).to include('"x":[1,2,4]')
      expect(chart_html).to include('"y":[30.0,60.0,85.0]') # CPU percentages
      expect(chart_html).to include('"y":[40.0,50.0,75.0]') # Memory percentages
    end
  end

  describe '#generate_error_rate_chart' do
    it 'generates HTML chart for error rates' do
      chart_html = chart_generator.generate_error_rate_chart
      
      expect(chart_html).to include('<html>')
      expect(chart_html).to include('Error Rate vs Concurrency')
      expect(chart_html).to include('Error Rate (%)')
    end

    it 'includes error rate data in JSON format' do
      chart_html = chart_generator.generate_error_rate_chart
      
      expect(chart_html).to include('"x":[1,2,4]')
      expect(chart_html).to include('"y":[0.0,10.0,10.0]') # Error rates as percentages
    end
  end

  describe '#generate_combined_chart' do
    it 'generates a comprehensive HTML chart with all metrics' do
      chart_html = chart_generator.generate_combined_chart
      
      expect(chart_html).to include('<html>')
      expect(chart_html).to include('Browser Benchmark Results')
      expect(chart_html).to include('Latency (ms)')
      expect(chart_html).to include('Resource Usage (%)')
      expect(chart_html).to include('Error Rate (%)')
    end

    it 'creates subplots for different metric types' do
      chart_html = chart_generator.generate_combined_chart
      
      expect(chart_html).to include('"subplot":"xy"')
      expect(chart_html).to include('"subplot":"xy2"')
      expect(chart_html).to include('"subplot":"xy3"')
    end
  end

  describe '#save_charts' do
    let(:output_dir) { './test_charts' }

    before do
      FileUtils.mkdir_p(output_dir)
    end

    after do
      FileUtils.rm_rf(output_dir)
    end

    it 'saves all chart types to the output directory' do
      config.output[:dir] = output_dir
      
      chart_generator.save_charts
      
      expect(File.exist?(File.join(output_dir, 'latency_chart.html'))).to be true
      expect(File.exist?(File.join(output_dir, 'resource_chart.html'))).to be true
      expect(File.exist?(File.join(output_dir, 'error_rate_chart.html'))).to be true
      expect(File.exist?(File.join(output_dir, 'combined_chart.html'))).to be true
    end

    it 'creates the output directory if it does not exist' do
      config.output[:dir] = './new_charts_dir'
      
      chart_generator.save_charts
      
      expect(Dir.exist?('./new_charts_dir')).to be true
      FileUtils.rm_rf('./new_charts_dir')
    end
  end

  describe '#extract_chart_data' do
    it 'extracts x and y values for charting' do
      data = chart_generator.extract_chart_data
      
      expect(data[:levels]).to eq([1, 2, 4])
      expect(data[:p50_latency]).to eq([100, 150, 250])
      expect(data[:p95_latency]).to eq([200, 350, 600])
      expect(data[:cpu_usage]).to eq([30, 60, 85])
      expect(data[:memory_usage]).to eq([40, 50, 75])
      expect(data[:error_rates]).to eq([0, 10, 10])
    end
  end

  describe '#generate_html_template' do
    it 'generates basic HTML structure with Plotly' do
      traces = [{ x: [1], y: [1], type: 'scatter' }]
      layout = { title: 'Test' }
      html = chart_generator.generate_html_template('Test Chart', 'test-chart', traces, layout)
      
      expect(html).to include('<!DOCTYPE html>')
      expect(html).to include('<html>')
      expect(html).to include('<head>')
      expect(html).to include('<title>Test Chart</title>')
      expect(html).to include('plotly-latest.min.js')
      expect(html).to include('<div id="test-chart">')
    end
  end
end
