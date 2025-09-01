# frozen_string_literal: true

require_relative 'browser_benchmark_tool/version'
require_relative 'browser_benchmark_tool/cli'
require_relative 'browser_benchmark_tool/config'
require_relative 'browser_benchmark_tool/benchmark'
require_relative 'browser_benchmark_tool/browser_automation'
require_relative 'browser_benchmark_tool/metrics_collector'
require_relative 'browser_benchmark_tool/degradation_engine'
require_relative 'browser_benchmark_tool/report_generator'
require_relative 'browser_benchmark_tool/chart_generator'
require_relative 'browser_benchmark_tool/test_server'
require_relative 'browser_benchmark_tool/safety_manager'
require_relative 'browser_benchmark_tool/rate_limiter'
require_relative 'browser_benchmark_tool/crawl4ai_integration'
require_relative 'browser_benchmark_tool/distributed_testing'
require_relative 'browser_benchmark_tool/custom_workload_scripts'
require_relative 'browser_benchmark_tool/browser_mode_options'
require_relative 'browser_benchmark_tool/headed_browser_support'

# Main module for the Browser Benchmark Tool
module BrowserBenchmarkTool
  class Error < StandardError; end

  # Your code goes here...
end
