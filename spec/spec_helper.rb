# frozen_string_literal: true

require 'rspec'
require 'fileutils'
require 'time'

# Add the lib directory to the load path
$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '..', 'lib'))

# Load the main library
require 'browser_benchmark_tool'

# Configure RSpec
RSpec.configure do |config|
  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = '.rspec_status'

  # Disable RSpec exposing methods globally on `Module` and `main`
  config.disable_monkey_patching!

  # Set test environment
  ENV['RACK_ENV'] = 'test'
  ENV['RAILS_ENV'] = 'test'

  # Configure test artifacts directory
  config.before(:suite) do
    FileUtils.mkdir_p('./artifacts')
  end

  config.after(:suite) do
    # Clean up test artifacts
    FileUtils.rm_rf('./artifacts') if Dir.exist?('./artifacts')
  end

  # Test type configuration
  config.define_derived_metadata do |metadata|
    # Unit tests - fast, mocked dependencies
    if metadata[:file_path] =~ /_unit_spec\.rb$/
      metadata[:fast] = true
      metadata[:type] = :unit
    end

    # Integration tests - slower, real components
    if metadata[:file_path] =~ /_integration_spec\.rb$/
      metadata[:slow] = true
      metadata[:type] = :integration
    end

    # Performance tests - slowest, real benchmarks
    if metadata[:file_path] =~ /_performance_spec\.rb$/
      metadata[:performance] = true
      metadata[:type] = :performance
    end

    # Component tests - medium speed, real HTTP
    if metadata[:file_path] =~ /_spec\.rb$/ && !metadata[:file_path].match?(/_unit_spec\.rb$|_integration_spec\.rb$|_performance_spec\.rb$/)
      metadata[:component] = true
      metadata[:type] = :component
    end
  end

  # Filter tests by type
  unless ENV['RUN_ALL_TESTS']
    config.filter_run_excluding :slow unless ENV['RUN_SLOW_TESTS']
    config.filter_run_excluding :performance unless ENV['RUN_PERFORMANCE_TESTS']
    config.filter_run_excluding :integration unless ENV['RUN_INTEGRATION_TESTS']
    config.filter_run_excluding :playwright unless ENV['RUN_PLAYWRIGHT_TESTS']
    config.filter_run_excluding :real_metrics unless ENV['RUN_REAL_METRICS_TESTS']

    # Default to running only fast tests
    config.filter_run :fast
  end
end

# Test utilities
module TestHelpers
  def create_temp_config
    BrowserBenchmarkTool::Config.default.tap do |config|
      config.workload[:mode] = 'simulated'
      config.workload[:urls] = ['https://httpbin.org/get']
      config.workload[:per_browser_repetitions] = 1
      config.ramp[:levels] = [1]
      config.output[:max_runtime_minutes] = 0.1
      config.output[:dir] = './artifacts'
    end
  end

  def cleanup_test_artifacts
    FileUtils.rm_rf('./artifacts') if Dir.exist?('./artifacts')
  end
end

RSpec.configure do |config|
  config.include TestHelpers
end
