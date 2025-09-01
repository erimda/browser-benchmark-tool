# frozen_string_literal: true

require 'spec_helper'

RSpec.describe BrowserBenchmarkTool::Crawl4aiIntegration, :crawl4ai do
  let(:config) do
    BrowserBenchmarkTool::Config.new.tap do |c|
      c.workload = { mode: 'crawl4ai', engine: 'chromium', headless: true }
      c.crawl4ai = {
        enabled: true,
        api_key: 'test_key_123',
        max_pages_per_site: 10,
        follow_links: true,
        extract_content: true,
        respect_robots_txt: true
      }
    end
  end

  let(:integration) { described_class.new(config) }

  describe '#initialize' do
    it 'creates integration with configuration' do
      expect(integration.config).to eq(config)
      expect(integration.enabled?).to be true
      expect(integration.api_key).to eq('test_key_123')
    end

    it 'can be disabled via configuration' do
      config.crawl4ai[:enabled] = false
      integration = described_class.new(config)
      
      expect(integration.enabled?).to be false
    end
  end

  describe '#crawl_site' do
    it 'crawls a single URL and discovers links' do
      # Mock crawl4ai response
      mock_response = {
        'url' => 'https://example.com',
        'title' => 'Example Domain',
        'links' => ['https://example.com/page1', 'https://example.com/page2'],
        'content' => 'This domain is for use in illustrative examples'
      }
      
      allow(integration).to receive(:call_crawl4ai_api).and_return(mock_response)
      
      result = integration.crawl_site('https://example.com')
      
      expect(result[:url]).to eq('https://example.com')
      expect(result[:links]).to include('https://example.com/page1')
      expect(result[:content]).to include('illustrative examples')
    end

    it 'respects max_pages_per_site limit' do
      config.crawl4ai[:max_pages_per_site] = 3
      
      # Mock multiple page responses
      allow(integration).to receive(:call_crawl4ai_api).and_return(
        { 'url' => 'https://example.com', 'links' => ['https://example.com/page1', 'https://example.com/page2'] },
        { 'url' => 'https://example.com/page1', 'links' => ['https://example.com/page3'] },
        { 'url' => 'https://example.com/page2', 'links' => ['https://example.com/page4'] }
      )
      
      result = integration.crawl_site('https://example.com')
      
      expect(result[:discovered_urls].length).to be <= 3
    end

    it 'follows links when enabled' do
      config.crawl4ai[:follow_links] = true
      
      allow(integration).to receive(:call_crawl4ai_api).and_return(
        { 'url' => 'https://example.com', 'links' => ['https://example.com/page1'] },
        { 'url' => 'https://example.com/page1', 'links' => [] }
      )
      
      result = integration.crawl_site('https://example.com')
      
      expect(result[:discovered_urls]).to include('https://example.com/page1')
    end

    it 'does not follow links when disabled' do
      config.crawl4ai[:follow_links] = false
      
      allow(integration).to receive(:call_crawl4ai_api).and_return(
        { 'url' => 'https://example.com', 'links' => ['https://example.com/page1'] }
      )
      
      result = integration.crawl_site('https://example.com')
      
      expect(result[:discovered_urls]).to eq(['https://example.com'])
    end
  end

  describe '#extract_content' do
    it 'extracts content when enabled' do
      config.crawl4ai[:extract_content] = true
      
      mock_response = {
        'url' => 'https://example.com',
        'title' => 'Example Domain',
        'content' => 'This domain is for use in illustrative examples',
        'text_content' => 'This domain is for use in illustrative examples'
      }
      
      allow(integration).to receive(:call_crawl4ai_api).and_return(mock_response)
      
      result = integration.crawl_site('https://example.com')
      
      expect(result[:content]).to include('illustrative examples')
      expect(result[:text_content]).to include('illustrative examples')
    end

    it 'skips content extraction when disabled' do
      config.crawl4ai[:extract_content] = false
      
      mock_response = {
        'url' => 'https://example.com',
        'title' => 'Example Domain',
        'links' => []
      }
      
      allow(integration).to receive(:call_crawl4ai_api).and_return(mock_response)
      
      result = integration.crawl_site('https://example.com')
      
      expect(result[:content]).to be_nil
      expect(result[:text_content]).to be_nil
    end
  end

  describe '#respect_robots_txt' do
    it 'checks robots.txt when enabled' do
      config.crawl4ai[:respect_robots_txt] = true
      
      allow(integration).to receive(:check_robots_txt).and_return(true)
      allow(integration).to receive(:call_crawl4ai_api).and_return(
        { 'url' => 'https://example.com', 'links' => [] }
      )
      
      result = integration.crawl_site('https://example.com')
      
      expect(integration).to have_received(:check_robots_txt).with('https://example.com')
      expect(result[:robots_allowed]).to be true
    end

    it 'skips robots.txt check when disabled' do
      config.crawl4ai[:respect_robots_txt] = false
      
      # Mock the check_robots_txt method to track calls
      allow(integration).to receive(:check_robots_txt).and_return(true)
      allow(integration).to receive(:call_crawl4ai_api).and_return(
        { 'url' => 'https://example.com', 'links' => [] }
      )
      
      integration.crawl_site('https://example.com')
      
      expect(integration).not_to have_received(:check_robots_txt)
    end
  end

  describe '#generate_crawl_report' do
    it 'generates comprehensive crawl report' do
      crawl_results = [
        { url: 'https://example.com', links: ['https://example.com/page1'], content_length: 150 },
        { url: 'https://example.com/page1', links: [], content_length: 100 }
      ]
      
      report = integration.generate_crawl_report(crawl_results)
      
      expect(report).to include('Crawl Report')
      expect(report).to include('**Total URLs crawled:** 2')
      expect(report).to include('**Total links discovered:** 1')
      expect(report).to include('**Average content length:** 125 characters')
    end
  end

  describe 'integration with browser automation' do
    it 'can be used as workload source for benchmarks' do
      # Mock crawl4ai to return URLs
      allow(integration).to receive(:crawl_site).and_return(
        { success: true, discovered_urls: ['https://example.com', 'https://example.com/page1'] }
      )
      
      urls = integration.get_workload_urls('https://example.com')
      
      expect(urls).to include('https://example.com')
      expect(urls).to include('https://example.com/page1')
    end

    it 'provides crawl metrics for benchmark analysis' do
      crawl_results = [
        { url: 'https://example.com', response_time: 500, content_length: 150 },
        { url: 'https://example.com/page1', response_time: 300, content_length: 100 }
      ]
      
      metrics = integration.get_crawl_metrics(crawl_results)
      
      expect(metrics[:total_urls]).to eq(2)
      expect(metrics[:avg_response_time]).to eq(400)
      expect(metrics[:total_content_length]).to eq(250)
    end
  end

  describe 'error handling' do
    it 'handles API errors gracefully' do
      allow(integration).to receive(:call_crawl4ai_api).and_raise(StandardError.new('API Error'))
      
      result = integration.crawl_site('https://example.com')
      
      expect(result[:error]).to eq('API Error')
      expect(result[:success]).to be false
    end

    it 'handles network timeouts' do
      allow(integration).to receive(:call_crawl4ai_api).and_raise(Timeout::Error.new('Request timeout'))
      
      result = integration.crawl_site('https://example.com')
      
      expect(result[:error]).to include('timeout')
      expect(result[:success]).to be false
    end
  end
end
