# frozen_string_literal: true

require 'spec_helper'

RSpec.describe BrowserBenchmarkTool::BrowserAutomation, :context_optimization do
  let(:config) do
    BrowserBenchmarkTool::Config.new.tap do |c|
      c.workload = { mode: 'playwright', engine: 'chromium', headless: true }
      c.safety = { request_timeout_seconds: 5 }
    end
  end

  let(:automation) { described_class.new(config) }

  describe 'browser context management' do
    it 'reuses browser instance across multiple requests' do
      # First request should create browser
      automation.send(:playwright)
      first_browser = automation.send(:browser)
      
      # Second request should reuse same browser
      automation.send(:playwright)
      second_browser = automation.send(:browser)
      
      expect(first_browser).to eq(second_browser)
    end

    it 'creates new context for each request for isolation' do
      # First request
      first_context = automation.send(:context)
      
      # Second request
      second_context = automation.send(:context)
      
      # Should be different contexts for isolation
      expect(first_context).not_to eq(second_context)
    end

    it 'properly closes pages after each request' do
      # Mock the context to track page creation
      mock_context = instance_double('Playwright::Context')
      mock_page = instance_double('Playwright::Page')
      
      allow(mock_context).to receive(:new_page).and_return(mock_page)
      allow(mock_page).to receive(:set_default_timeout)
      allow(mock_page).to receive(:goto).and_return(double(status: 200))
      allow(mock_page).to receive(:wait_for_load_state)
      allow(mock_page).to receive(:title).and_return('Test Page')
      allow(mock_page).to receive(:url).and_return('http://example.com')
      allow(mock_page).to receive(:viewport_size).and_return({ width: 1920, height: 1080 })
      allow(mock_page).to receive(:content).and_return('Test content')
      allow(mock_page).to receive(:close)
      
      allow(automation).to receive(:context).and_return(mock_context)
      
      # Make request
      result = automation.send(:run_real_playwright_actions, 'http://example.com')
      
      expect(result[:success]).to be true
      expect(mock_page).to have_received(:close)
    end

    it 'handles context creation errors gracefully' do
      # Mock browser to raise error on new_context
      mock_browser = instance_double('Playwright::Browser')
      allow(mock_browser).to receive(:new_context).and_raise(StandardError.new('Context creation failed'))
      
      allow(automation).to receive(:browser).and_return(mock_browser)
      
      expect { automation.send(:context) }.to raise_error(StandardError, 'Context creation failed')
    end

    it 'maintains browser instance across multiple concurrent requests' do
      # Mock browser and context
      mock_browser = instance_double('Playwright::Browser')
      mock_context = instance_double('Playwright::Context')
      mock_page = instance_double('Playwright::Page')
      
      allow(mock_browser).to receive(:new_context).and_return(mock_context)
      allow(mock_context).to receive(:new_page).and_return(mock_page)
      allow(mock_page).to receive(:set_default_timeout)
      allow(mock_page).to receive(:goto).and_return(double(status: 200))
      allow(mock_page).to receive(:wait_for_load_state)
      allow(mock_page).to receive(:title).and_return('Test Page')
      allow(mock_page).to receive(:url).and_return('http://example.com')
      allow(mock_page).to receive(:viewport_size).and_return({ width: 1920, height: 1080 })
      allow(mock_page).to receive(:content).and_return('Test content')
      allow(mock_page).to receive(:close)
      
      allow(automation).to receive(:browser).and_return(mock_browser)
      
      # Simulate concurrent requests
      threads = []
      3.times do
        threads << Thread.new do
          automation.send(:run_real_playwright_actions, 'http://example.com')
        end
      end
      
      threads.each(&:join)
      
      # With context pooling, should create contexts up to pool size, then reuse
      # For 3 concurrent requests, should create at least 1 context (pool size default is 10)
      expect(mock_browser).to have_received(:new_context).at_least(1).times
      expect(mock_browser).to have_received(:new_context).at_most(3).times
    end

    it 'optimizes context creation for high-concurrency scenarios' do
      # Test that context creation is efficient
      start_time = Time.now
      
      # Create multiple contexts rapidly
      10.times do
        automation.send(:context)
      end
      
      duration = Time.now - start_time
      
      # Context creation should be reasonably fast (under 500ms for 10 contexts)
      # This accounts for the overhead of creating real Playwright contexts
      expect(duration).to be < 0.5
    end

    it 'provides context configuration options' do
      # Mock browser
      mock_browser = instance_double('Playwright::Browser')
      mock_context = instance_double('Playwright::Context')
      
      allow(mock_browser).to receive(:new_context).and_return(mock_context)
      allow(automation).to receive(:browser).and_return(mock_browser)
      
      # Should be able to create context with options
      context = automation.send(:context)
      
      expect(context).to eq(mock_context)
    end
  end
end
