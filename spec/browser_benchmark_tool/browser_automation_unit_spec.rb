# frozen_string_literal: true

require 'spec_helper'

RSpec.describe BrowserBenchmarkTool::BrowserAutomation do
  let(:config) do
    BrowserBenchmarkTool::Config.default.tap do |c|
      c.workload[:mode] = 'simulated'
      c.safety[:max_concurrent_requests] = 10
      c.safety[:max_total_requests] = 100
      c.safety[:request_timeout_seconds] = 30
    end
  end

  let(:automation) { described_class.new(config) }

  describe '#initialize' do
    it 'creates automation with configuration' do
      expect(automation.config).to eq(config)
      expect(automation.safety_manager).to be_a(BrowserBenchmarkTool::SafetyManager)
    end
  end

  describe '#run_concurrent_tasks' do
    it 'creates correct number of threads' do
      urls = ['https://example.com/1', 'https://example.com/2']
      concurrency = 5
      
      # Mock the run_single_task method to avoid real execution
      allow(automation).to receive(:run_single_task).and_return({ success: true })
      
      results = automation.run_concurrent_tasks(urls, concurrency)
      
      expect(results.length).to eq(5)
      expect(automation).to have_received(:run_single_task).exactly(5).times
    end

    it 'distributes URLs round-robin' do
      urls = ['https://example.com/1', 'https://example.com/2']
      concurrency = 3
      
      # Mock the run_single_task method
      allow(automation).to receive(:run_single_task).and_return({ success: true })
      
      automation.run_concurrent_tasks(urls, concurrency)
      
      # Should call with URL 1, then 2, then 1 again (round-robin)
      expect(automation).to have_received(:run_single_task).with('https://example.com/1').at_least(:once)
      expect(automation).to have_received(:run_single_task).with('https://example.com/2').at_least(:once)
    end
  end

  describe '#cleanup' do
    it 'calls cleanup methods when instance variables exist' do
      # Mock the instance variables
      context = instance_double('PlaywrightContext')
      browser = instance_double('PlaywrightBrowser')
      playwright = instance_double('Playwright')
      
      expect(context).to receive(:close)
      expect(browser).to receive(:close)
      expect(playwright).to receive(:stop)
      
      automation.instance_variable_set(:@context, context)
      automation.instance_variable_set(:@browser, browser)
      automation.instance_variable_set(:@playwright, playwright)
      
      automation.cleanup
    end

    it 'handles missing instance variables gracefully' do
      # Should not raise any errors when instance variables are nil
      expect { automation.cleanup }.not_to raise_error
    end
  end

  describe 'private methods' do
    describe '#run_single_task' do
      it 'records request start and end' do
        url = 'https://example.com'
        safety_manager = automation.safety_manager
        
        # Mock can_make_request to return true
        allow(safety_manager).to receive(:can_make_request).and_return(true)
        allow(safety_manager).to receive(:record_request_start)
        allow(safety_manager).to receive(:record_request_end)
        
        # Mock fetch_url to return success
        allow(automation).to receive(:fetch_url).and_return({ success: true })
        
        automation.send(:run_single_task, url)
        
        expect(safety_manager).to have_received(:record_request_start)
        expect(safety_manager).to have_received(:record_request_end)
      end

      it 'returns error when safety check fails' do
        url = 'https://example.com'
        safety_manager = automation.safety_manager
        
        # Mock can_make_request to return false
        allow(safety_manager).to receive(:can_make_request).and_return(false)
        
        result = automation.send(:run_single_task, url)
        
        expect(result[:success]).to be false
        expect(result[:error]).to eq('Safety limit exceeded')
      end

      it 'handles fetch_url errors gracefully' do
        url = 'https://example.com'
        safety_manager = automation.safety_manager
        
        # Mock can_make_request to return true
        allow(safety_manager).to receive(:can_make_request).and_return(true)
        allow(safety_manager).to receive(:record_request_start)
        allow(safety_manager).to receive(:record_request_end)
        
        # Mock fetch_url to raise an error
        allow(automation).to receive(:fetch_url).and_raise(StandardError.new('Network error'))
        
        result = automation.send(:run_single_task, url)
        
        expect(result[:success]).to be false
        expect(result[:error]).to eq('Network error')
        expect(result[:duration_ms]).to be > 0
      end
    end

    describe '#fetch_url' do
      it 'handles invalid URIs gracefully' do
        # Test with a malformed URL that will cause network errors
        # Use HTTP mode to avoid simulated mode special handling
        test_config = BrowserBenchmarkTool::Config.default.tap do |c|
          c.workload[:mode] = 'http'
        end
        test_automation = described_class.new(test_config)
        
        # Mock Net::HTTP to simulate network failure
        http_double = instance_double(Net::HTTP)
        allow(Net::HTTP).to receive(:new).and_return(http_double)
        allow(http_double).to receive(:use_ssl=)
        allow(http_double).to receive(:open_timeout=)
        allow(http_double).to receive(:read_timeout=)
        allow(http_double).to receive(:get).and_raise(StandardError.new('Connection refused'))
        
        result = test_automation.send(:fetch_url, 'http://invalid-host-that-does-not-exist-12345.com')
        
        expect(result[:success]).to be false
        expect(result[:error]).to eq('Connection refused')
        expect(result[:status_code]).to eq(500)
      end

      it 'calls simulate_playwright_actions for simulated mode' do
        config.workload[:mode] = 'playwright'
        
        # Mock simulate_playwright_actions
        allow(automation).to receive(:simulate_playwright_actions).and_return({ success: true })
        
        automation.send(:fetch_url, 'https://example.com')
        
        expect(automation).to have_received(:simulate_playwright_actions)
      end

      it 'calls simulate_playwright_actions for simulated mode' do
        # Create a new config instance to avoid modifying the shared one
        test_config = BrowserBenchmarkTool::Config.default.tap do |c|
          c.workload[:mode] = 'playwright'  # Use 'playwright' mode to trigger simulate_playwright_actions
        end
        test_automation = described_class.new(test_config)
        
        # Mock simulate_playwright_actions
        allow(test_automation).to receive(:simulate_playwright_actions).and_return({ success: true })
        
        test_automation.send(:fetch_url, 'https://example.com')
        
        expect(test_automation).to have_received(:simulate_playwright_actions)
      end

      it 'makes HTTP request for non-playwright mode' do
        config.workload[:mode] = 'http'
        
        # Mock Net::HTTP to avoid real network calls
        http_double = instance_double(Net::HTTP)
        response_double = instance_double(Net::HTTPResponse)
        
        allow(Net::HTTP).to receive(:new).and_return(http_double)
        allow(http_double).to receive(:use_ssl=)
        allow(http_double).to receive(:open_timeout=)
        allow(http_double).to receive(:read_timeout=)
        allow(http_double).to receive(:get).and_return(response_double)
        allow(response_double).to receive(:code).and_return('200')
        allow(response_double).to receive(:body).and_return('test content')
        
        result = automation.send(:fetch_url, 'https://example.com')
        
        expect(result[:success]).to be true
        expect(result[:status_code]).to eq(200)
        expect(result[:content_length]).to eq(12)
      end
    end
  end

  describe 'error handling' do
    it 'handles network errors gracefully' do
      url = 'https://example.com'
      
      # Mock fetch_url to simulate network error
      allow(automation).to receive(:fetch_url).and_raise(StandardError.new('Connection refused'))
      
      result = automation.send(:run_single_task, url)
      
      expect(result[:success]).to be false
      expect(result[:error]).to eq('Connection refused')
    end

    it 'handles timeout errors gracefully' do
      url = 'https://example.com'
      
      # Mock fetch_url to simulate timeout
      allow(automation).to receive(:fetch_url).and_raise(Timeout::Error.new('Request timeout'))
      
      result = automation.send(:run_single_task, url)
      
      expect(result[:success]).to be false
      expect(result[:error]).to eq('Request timeout')
    end
  end
end
