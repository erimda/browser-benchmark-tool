# frozen_string_literal: true

require_relative 'browser_benchmark_tool/version'
require_relative 'browser_benchmark_tool/cli'
require_relative 'browser_benchmark_tool/config'
require_relative 'browser_benchmark_tool/benchmark'
require_relative 'browser_benchmark_tool/browser_automation'
require_relative 'browser_benchmark_tool/metrics_collector'
require_relative 'browser_benchmark_tool/degradation_engine'

# Main module for the Browser Benchmark Tool
module BrowserBenchmarkTool
  class Error < StandardError; end
  
  # Your code goes here...
end
