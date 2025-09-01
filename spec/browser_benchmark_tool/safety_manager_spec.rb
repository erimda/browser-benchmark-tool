# frozen_string_literal: true

require 'spec_helper'

RSpec.describe BrowserBenchmarkTool::SafetyManager do
  let(:config) do
    BrowserBenchmarkTool::Config.new.tap do |c|
      c.safety = {
        robots_txt_respect: true,
        external_rate_limit_rps: 2,
        max_concurrent_requests: 10,
        request_timeout_seconds: 30,
        max_total_requests: 100
      }
    end
  end

  let(:safety_manager) { described_class.new(config) }

  describe '#initialize' do
    it 'creates a safety manager with configuration' do
      expect(safety_manager.config).to eq(config)
      expect(safety_manager.rate_limiter).to be_a(BrowserBenchmarkTool::RateLimiter)
    end
  end

  describe '#check_rate_limit' do
    it 'allows requests within rate limit' do
      expect(safety_manager.check_rate_limit('https://example.com')).to be true
      expect(safety_manager.check_rate_limit('https://example.com')).to be true
    end

    it 'blocks requests when rate limit exceeded' do
      # Make requests up to the rate limit
      2.times { safety_manager.check_rate_limit('https://example.com') }

      # Next request should be blocked
      expect(safety_manager.check_rate_limit('https://example.com')).to be false
    end

    it 'tracks different domains separately' do
      expect(safety_manager.check_rate_limit('https://example.com')).to be true
      expect(safety_manager.check_rate_limit('https://test.com')).to be true
      expect(safety_manager.check_rate_limit('https://example.com')).to be true
    end
  end

  describe '#check_concurrent_limit' do
    it 'allows requests within concurrent limit' do
      expect(safety_manager.check_concurrent_limit).to be true
    end

    it 'blocks requests when concurrent limit exceeded' do
      # Simulate max concurrent requests
      safety_manager.instance_variable_set(:@current_requests, config.safety[:max_concurrent_requests])

      expect(safety_manager.check_concurrent_limit).to be false
    end
  end

  describe '#check_total_requests_limit' do
    it 'allows requests within total limit' do
      expect(safety_manager.check_total_requests_limit).to be true
    end

    it 'blocks requests when total limit exceeded' do
      # Simulate max total requests
      safety_manager.instance_variable_set(:@total_requests, config.safety[:max_total_requests])

      expect(safety_manager.check_total_requests_limit).to be false
    end
  end

  describe '#check_robots_txt' do
    it 'respects robots.txt when enabled' do
      config.safety[:robots_txt_respect] = true

      # Mock robots.txt check
      allow(safety_manager).to receive(:fetch_robots_txt).and_return("User-agent: *\nDisallow: /private/")

      expect(safety_manager.check_robots_txt('https://example.com/private/page')).to be false
      expect(safety_manager.check_robots_txt('https://example.com/public/page')).to be true
    end

    it 'ignores robots.txt when disabled' do
      config.safety[:robots_txt_respect] = false

      expect(safety_manager.check_robots_txt('https://example.com/private/page')).to be true
    end
  end

  describe '#can_make_request' do
    it 'returns true when all safety checks pass' do
      expect(safety_manager.can_make_request('https://example.com')).to be true
    end

    it 'returns false when rate limit exceeded' do
      2.times { safety_manager.check_rate_limit('https://example.com') }

      expect(safety_manager.can_make_request('https://example.com')).to be false
    end

    it 'returns false when concurrent limit exceeded' do
      safety_manager.instance_variable_set(:@current_requests, config.safety[:max_concurrent_requests])

      expect(safety_manager.can_make_request('https://example.com')).to be false
    end

    it 'returns false when total requests limit exceeded' do
      safety_manager.instance_variable_set(:@total_requests, config.safety[:max_total_requests])

      expect(safety_manager.can_make_request('https://example.com')).to be false
    end
  end

  describe '#record_request_start' do
    it 'increments current and total request counters' do
      initial_current = safety_manager.instance_variable_get(:@current_requests)
      initial_total = safety_manager.instance_variable_get(:@total_requests)

      safety_manager.record_request_start

      expect(safety_manager.instance_variable_get(:@current_requests)).to eq(initial_current + 1)
      expect(safety_manager.instance_variable_get(:@total_requests)).to eq(initial_total + 1)
    end
  end

  describe '#record_request_end' do
    it 'decrements current request counter' do
      safety_manager.record_request_start
      initial_current = safety_manager.instance_variable_get(:@current_requests)

      safety_manager.record_request_end

      expect(safety_manager.instance_variable_get(:@current_requests)).to eq(initial_current - 1)
    end
  end

  describe '#get_safety_stats' do
    it 'returns current safety statistics' do
      stats = safety_manager.get_safety_stats

      expect(stats).to include(:current_requests)
      expect(stats).to include(:total_requests)
      expect(stats).to include(:rate_limited_domains)
    end
  end

  describe '#reset_limits' do
    it 'resets all safety counters and limits' do
      safety_manager.record_request_start
      safety_manager.check_rate_limit('https://example.com')

      safety_manager.reset_limits

      expect(safety_manager.instance_variable_get(:@current_requests)).to eq(0)
      expect(safety_manager.instance_variable_get(:@total_requests)).to eq(0)
      expect(safety_manager.check_rate_limit('https://example.com')).to be true
    end
  end
end
