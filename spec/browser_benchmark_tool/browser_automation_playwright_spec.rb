# frozen_string_literal: true

require 'spec_helper'

RSpec.describe BrowserBenchmarkTool::BrowserAutomation, :playwright do
  let(:config) do
    BrowserBenchmarkTool::Config.default.tap do |c|
      c.workload[:mode] = 'playwright'
      c.workload[:engine] = 'chromium'
      c.workload[:headless] = true
      c.safety[:max_concurrent_requests] = 10
      c.safety[:max_total_requests] = 100
      c.safety[:request_timeout_seconds] = 30
    end
  end
  let(:automation) { described_class.new(config) }

  before(:each) do
    # Skip if Playwright is not available
    skip 'Playwright not available' unless automation.send(:playwright_available?)
  end

  after(:each) do
    automation.cleanup
  end

  describe 'real Playwright integration' do
    it 'initializes Playwright client successfully' do
      expect(automation.send(:playwright)).to be_a(Playwright::Execution)
    end

    it 'creates browser instance' do
      expect(automation.send(:browser)).to be_a(Playwright::Browser)
    end

    it 'creates browser context' do
      expect(automation.send(:context)).to be_a(Playwright::BrowserContext)
    end

    it 'navigates to a real URL and captures metrics' do
      result = automation.run_single_task('https://httpbin.org/get')
      
      expect(result[:success]).to be true
      expect(result[:status_code]).to eq(200)
      expect(result[:duration_ms]).to be > 0
      expect(result[:content_length]).to be > 0
    end

    it 'handles network errors gracefully' do
      result = automation.run_single_task('http://192.168.1.999:99999')
      
      expect(result[:success]).to be false
      expect(result[:error]).to include('Cannot navigate to invalid URL')
    end

    it 'respects timeout settings' do
      # Use a slow endpoint to test timeout
      result = automation.run_single_task('https://httpbin.org/delay/5')
      
      # Should timeout before 5 seconds
      expect(result[:duration_ms]).to be < 5000
    end

    it 'captures page metrics accurately' do
      result = automation.run_single_task('https://httpbin.org/html')
      
      expect(result[:success]).to be true
      expect(result[:status_code]).to eq(200)
      expect(result[:content_length]).to be > 0
      expect(result[:page_metrics]).to be_a(Hash)
      expect(result[:page_metrics][:url]).to eq('https://httpbin.org/html')
      expect(result[:page_metrics][:viewport]).not_to be_nil
    end
  end

  describe 'browser management' do
    it 'reuses browser instance for multiple requests' do
      browser1 = automation.send(:browser)
      
      automation.run_single_task('https://httpbin.org/get')
      
      browser2 = automation.send(:browser)
      expect(browser1).to eq(browser2)
    end

    it 'creates new context for each request' do
      context1 = automation.send(:context)
      
      automation.run_single_task('https://httpbin.org/get')
      
      context2 = automation.send(:context)
      expect(context1).not_to eq(context2)
    end

    it 'cleans up resources properly' do
      browser = automation.send(:browser)
      context = automation.send(:context)
      
      automation.cleanup
      
      expect { browser.new_page }.to raise_error(StandardError)
      expect { context.new_page }.to raise_error(StandardError)
    end
  end

  describe 'concurrent execution' do
    it 'handles multiple concurrent requests' do
      urls = [
        'https://httpbin.org/get',
        'https://httpbin.org/status/200',
        'https://httpbin.org/headers'
      ]
      
      results = automation.run_concurrent_tasks(urls, 3)
      
      expect(results.length).to eq(3)
      results.each do |result|
        expect(result[:success]).to be true
        expect(result[:status_code]).to eq(200)
      end
    end
  end
end
