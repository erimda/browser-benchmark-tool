# frozen_string_literal: true

require 'uri'
require 'net/http'
require_relative 'rate_limiter'

module BrowserBenchmarkTool
  class SafetyManager
    attr_reader :config, :rate_limiter

    def initialize(config)
      @config = config
      @rate_limiter = RateLimiter.new(config.safety[:external_rate_limit_rps] || 2)
      @current_requests = 0
      @total_requests = 0
      @robots_cache = {}
    end

    def check_rate_limit(url)
      domain = extract_domain(url)
      @rate_limiter.allow_request?(domain)
    end

    def check_concurrent_limit
      max_concurrent = @config.safety[:max_concurrent_requests] || 10
      @current_requests < max_concurrent
    end

    def check_total_requests_limit
      max_total = @config.safety[:max_total_requests] || 100
      @total_requests < max_total
    end

    def check_robots_txt(url)
      return true unless @config.safety[:robots_txt_respect]
      
      domain = extract_domain(url)
      robots_content = fetch_robots_txt(domain)
      
      return true unless robots_content
      
      # Simple robots.txt parsing - check if URL is disallowed
      path = URI(url).path
      robots_content.lines.each do |line|
        if line.strip.start_with?('Disallow:')
          disallowed_path = line.strip.split('Disallow:').last.strip
          return false if path.start_with?(disallowed_path)
        end
      end
      
      true
    end

    def can_make_request(url)
      check_rate_limit(url) &&
        check_concurrent_limit &&
        check_total_requests_limit &&
        check_robots_txt(url)
    end

    def record_request_start
      @current_requests += 1
      @total_requests += 1
    end

    def record_request_end
      @current_requests = [@current_requests - 1, 0].max
    end

    def get_safety_stats
      {
        current_requests: @current_requests,
        total_requests: @total_requests,
        rate_limited_domains: @rate_limiter.get_stats[:domains]
      }
    end

    def reset_limits
      @current_requests = 0
      @total_requests = 0
      @rate_limiter.reset
      @robots_cache.clear
    end

    private

    def extract_domain(url)
      URI(url).host
    rescue URI::InvalidURIError
      'unknown'
    end

    def fetch_robots_txt(domain)
      return @robots_cache[domain] if @robots_cache.key?(domain)
      
      begin
        robots_url = "https://#{domain}/robots.txt"
        uri = URI(robots_url)
        
        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = uri.scheme == 'https'
        http.open_timeout = 5
        http.read_timeout = 5
        
        response = http.get(uri.path)
        
        if response.code == '200'
          @robots_cache[domain] = response.body
        else
          @robots_cache[domain] = nil
        end
      rescue => e
        @robots_cache[domain] = nil
      end
      
      @robots_cache[domain]
    end
  end
end

