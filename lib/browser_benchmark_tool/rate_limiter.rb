# frozen_string_literal: true

require 'time'

module BrowserBenchmarkTool
  class RateLimiter
    def initialize(requests_per_second)
      @requests_per_second = requests_per_second
      @request_times = {}
    end

    def allow_request?(domain)
      now = Time.now
      domain_times = @request_times[domain] || []
      
      # Remove old requests outside the 1-second window
      domain_times.reject! { |time| now - time >= 1.0 }
      
      # Check if we're under the rate limit
      if domain_times.length < @requests_per_second
        domain_times << now
        @request_times[domain] = domain_times
        true
      else
        false
      end
    end

    def reset
      @request_times.clear
    end

    def get_stats
      {
        domains: @request_times.keys,
        total_requests: @request_times.values.sum(&:length)
      }
    end
  end
end

