# frozen_string_literal: true

require 'net/http'
require 'uri'
require 'json'
require_relative 'safety_manager'

module BrowserBenchmarkTool
  class BrowserAutomation
    attr_reader :config, :safety_manager

    def initialize(config)
      @config = config
      @safety_manager = SafetyManager.new(config)
    end

    def run_concurrent_tasks(urls, concurrency_level)
      results = []
      threads = []

      urls.each_with_index do |url, index|
        break if index >= concurrency_level

        threads << Thread.new do
          run_single_task(url)
        end
      end

      threads.each(&:join)

      # Collect results from threads
      threads.each do |thread|
        results << thread.value if thread.value
      end

      results
    end

    private

    def run_single_task(url)
      start_time = Time.now

      # Safety check before making request
      unless @safety_manager.can_make_request(url)
        return {
          url: url,
          success: false,
          error: 'Safety limit exceeded',
          duration_ms: 0,
          timestamp: Time.now.strftime('%Y-%m-%dT%H:%M:%S.%LZ')
        }
      end

      @safety_manager.record_request_start

      begin
        result = fetch_url(url)
        result[:duration_ms] = ((Time.now - start_time) * 1000).round(2)
        result[:timestamp] = Time.now.strftime('%Y-%m-%dT%H:%M:%S.%LZ')
        result
      rescue StandardError => e
        {
          url: url,
          success: false,
          error: e.message,
          duration_ms: ((Time.now - start_time) * 1000).round(2),
          timestamp: Time.now.strftime('%Y-%m-%dT%H:%M:%S.%LZ')
        }
      ensure
        @safety_manager.record_request_end
      end
    end

    def fetch_url(url)
      uri = URI(url)

      # Simulate browser automation
      if @config.workload[:mode] == 'playwright'
        simulate_playwright_actions(url)
      else
        # Simple HTTP request
        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = uri.scheme == 'https'
        http.open_timeout = @config.safety[:request_timeout_seconds] || 30
        http.read_timeout = @config.safety[:request_timeout_seconds] || 30

        response = http.get(uri.path.empty? ? '/' : uri.path)

        {
          url: url,
          success: response.code.start_with?('2'),
          status_code: response.code.to_i,
          content_length: response.body.length,
          duration_ms: 0 # Will be set by caller
        }
      end
    end

    def simulate_playwright_actions(url)
      # Simulate Playwright browser automation
      # Use much shorter times for testing
      if ENV['RACK_ENV'] == 'test' || ENV['RAILS_ENV'] == 'test'
        sleep(rand(0.01..0.05)) # Much faster for tests
      else
        sleep(rand(0.1..0.5)) # Simulate page load time
      end

      # Simulate some browser interactions
      if ENV['RACK_ENV'] == 'test' || ENV['RAILS_ENV'] == 'test'
        sleep(rand(0.005..0.02)) # Much faster for tests
      else
        sleep(rand(0.05..0.2)) # Simulate DOM interaction
      end

      # Simulate screenshot
      if ENV['RACK_ENV'] == 'test' || ENV['RAILS_ENV'] == 'test'
        sleep(rand(0.01..0.03)) # Much faster for tests
      else
        sleep(rand(0.1..0.3)) # Simulate screenshot capture
      end

      {
        url: url,
        success: true,
        status_code: 200,
        content_length: rand(1000..50_000), # Simulate content size
        duration_ms: 0 # Will be set by caller
      }
    end
  end
end
