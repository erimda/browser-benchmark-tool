# frozen_string_literal: true

require 'json'
require 'fileutils'

module BrowserBenchmarkTool
  class ChartGenerator
    attr_reader :config, :samples

    def initialize(config, samples)
      @config = config
      @samples = samples
    end

    def generate_latency_chart
      data = extract_chart_data
      
      traces = [
        {
          x: data[:levels],
          y: data[:p50_latency],
          type: 'scatter',
          mode: 'lines+markers',
          name: 'p50',
          line: { color: '#1f77b4' }
        },
        {
          x: data[:levels],
          y: data[:p95_latency],
          type: 'scatter',
          mode: 'lines+markers',
          name: 'p95',
          line: { color: '#ff7f0e' }
        },
        {
          x: data[:levels],
          y: data[:p99_latency],
          type: 'scatter',
          mode: 'lines+markers',
          name: 'p99',
          line: { color: '#d62728' }
        }
      ]

      layout = {
        title: 'Latency vs Concurrency',
        xaxis: { title: 'Concurrency Level' },
        yaxis: { title: 'Latency (ms)' },
        showlegend: true
      }

      generate_html_template('Latency vs Concurrency', 'latency-chart', traces, layout)
    end

    def generate_resource_chart
      data = extract_chart_data
      
      traces = [
        {
          x: data[:levels],
          y: data[:cpu_usage],
          type: 'scatter',
          mode: 'lines+markers',
          name: 'CPU Usage',
          line: { color: '#2ca02c' }
        },
        {
          x: data[:levels],
          y: data[:memory_usage],
          type: 'scatter',
          mode: 'lines+markers',
          name: 'Memory Usage',
          line: { color: '#9467bd' }
        }
      ]

      layout = {
        title: 'Resource Usage vs Concurrency',
        xaxis: { title: 'Concurrency Level' },
        yaxis: { title: 'Usage (%)' },
        showlegend: true
      }

      generate_html_template('Resource Usage vs Concurrency', 'resource-chart', traces, layout)
    end

    def generate_error_rate_chart
      data = extract_chart_data
      
      traces = [
        {
          x: data[:levels],
          y: data[:error_rates],
          type: 'scatter',
          mode: 'lines+markers',
          name: 'Error Rate (%)',
          line: { color: '#e377c2' }
        }
      ]

      layout = {
        title: 'Error Rate vs Concurrency',
        xaxis: { title: 'Concurrency Level' },
        yaxis: { title: 'Error Rate (%)' },
        showlegend: true
      }

      generate_html_template('Error Rate vs Concurrency', 'error-rate-chart', traces, layout)
    end

    def generate_combined_chart
      data = extract_chart_data
      
      traces = [
        # Latency subplot
        {
          x: data[:levels],
          y: data[:p95_latency],
          type: 'scatter',
          mode: 'lines+markers',
          name: 'P95 Latency',
          subplot: 'xy',
          line: { color: '#ff7f0e' }
        },
        # Resource subplot
        {
          x: data[:levels],
          y: data[:cpu_usage],
          type: 'scatter',
          mode: 'lines+markers',
          name: 'CPU Usage',
          subplot: 'xy2',
          line: { color: '#2ca02c' }
        },
        {
          x: data[:levels],
          y: data[:memory_usage],
          type: 'scatter',
          mode: 'lines+markers',
          name: 'Memory Usage',
          subplot: 'xy2',
          line: { color: '#9467bd' }
        },
        # Error rate subplot
        {
          x: data[:levels],
          y: data[:error_rates],
          type: 'scatter',
          mode: 'lines+markers',
          name: 'Error Rate',
          subplot: 'xy3',
          line: { color: '#e377c2' }
        }
      ]

      layout = {
        title: 'Browser Benchmark Results',
        grid: { rows: 3, columns: 1, pattern: 'independent' },
        xaxis: { title: 'Concurrency Level' },
        yaxis: { title: 'Latency (ms)' },
        xaxis2: { title: 'Concurrency Level' },
        yaxis2: { title: 'Resource Usage (%)' },
        xaxis3: { title: 'Concurrency Level' },
        yaxis3: { title: 'Error Rate (%)' },
        showlegend: true
      }

      generate_html_template('Browser Benchmark Results', 'combined-chart', traces, layout)
    end

    def save_charts
      output_dir = config.output[:dir]
      FileUtils.mkdir_p(output_dir)
      
      # Save individual charts
      File.write(File.join(output_dir, 'latency_chart.html'), generate_latency_chart)
      File.write(File.join(output_dir, 'resource_chart.html'), generate_resource_chart)
      File.write(File.join(output_dir, 'error_rate_chart.html'), generate_error_rate_chart)
      File.write(File.join(output_dir, 'combined_chart.html'), generate_combined_chart)
      
      puts "Charts saved to: #{output_dir}"
    end

    def extract_chart_data
      levels = samples.map { |s| s[:level] }
      p50_latency = samples.map { |s| s[:latency_ms][:p50] }
      p95_latency = samples.map { |s| s[:latency_ms][:p95] }
      p99_latency = samples.map { |s| s[:latency_ms][:p99] }
      cpu_usage = samples.map { |s| (s[:host][:cpu_usage] * 100).round(1) }
      memory_usage = samples.map { |s| (s[:host][:memory_usage] * 100).round(1) }
      error_rates = samples.map { |s| (s[:tasks][:error_rate] * 100).round(1) }
      
      {
        levels: levels,
        p50_latency: p50_latency,
        p95_latency: p95_latency,
        p99_latency: p99_latency,
        cpu_usage: cpu_usage,
        memory_usage: memory_usage,
        error_rates: error_rates
      }
    end

    def generate_html_template(title, chart_id, traces, layout)
      <<~HTML
        <!DOCTYPE html>
        <html>
        <head>
          <title>#{title}</title>
          <script src="https://cdn.plot.ly/plotly-latest.min.js"></script>
        </head>
        <body>
          <div id="#{chart_id}"></div>
          <script>
            var traces = #{traces.to_json};
            var layout = #{layout.to_json};
            Plotly.newPlot('#{chart_id}', traces, layout);
          </script>
        </body>
        </html>
      HTML
    end
  end
end
