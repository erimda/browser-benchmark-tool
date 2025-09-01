# frozen_string_literal: true

require 'net/http'
require 'uri'
require 'json'
require 'timeout'

module BrowserBenchmarkTool
  class Crawl4aiIntegration
    attr_reader :config

    def initialize(config)
      @config = config
      @enabled = config.crawl4ai&.dig(:enabled) || false
    end

    def enabled?
      @enabled
    end

    def api_key
      config.crawl4ai&.dig(:api_key)
    end

    def max_pages_per_site
      config.crawl4ai&.dig(:max_pages_per_site) || 10
    end

    def follow_links?
      config.crawl4ai&.dig(:follow_links) || false
    end

    def extract_content?
      config.crawl4ai&.dig(:extract_content) || false
    end

    def respect_robots_txt?
      config.crawl4ai&.dig(:respect_robots_txt) || false
    end

    def api_endpoint
      config.crawl4ai&.dig(:api_endpoint) || 'https://api.crawl4ai.com'
    end

    def crawl_site(start_url)
      return { success: false, error: 'Crawl4ai integration not enabled' } unless enabled?
      return { success: false, error: 'API key required' } unless api_key

      begin
        discovered_urls = [start_url]
        crawled_pages = []
        urls_to_crawl = [start_url]
        crawled_count = 0

        while urls_to_crawl.any? && crawled_count < max_pages_per_site
          current_url = urls_to_crawl.shift
          next if crawled_pages.any? { |page| page[:url] == current_url }

          # Check robots.txt if enabled
          robots_allowed = true
          if respect_robots_txt?
            robots_allowed = check_robots_txt(current_url)
            next unless robots_allowed
          end

          # Crawl the page
          page_data = call_crawl4ai_api(current_url)
          next unless page_data

          # Extract content if enabled
          if extract_content?
            page_data['content'] = page_data['content'] || page_data['text_content'] || ''
            page_data['text_content'] = page_data['text_content'] || page_data['content'] || ''
          end

          # Add to crawled pages
          crawled_pages << {
            url: current_url,
            title: page_data['title'],
            links: page_data['links'] || [],
            content: page_data['content'],
            text_content: page_data['text_content'],
            content_length: (page_data['content'] || '').length,
            robots_allowed: robots_allowed,
            response_time: page_data['response_time'],
            timestamp: Time.now.strftime('%Y-%m-%dT%H:%M:%S.%LZ')
          }

          # Also add to the main result for single-page crawls
          if crawled_pages.length == 1
            @single_page_result = {
              url: current_url,
              title: page_data['title'],
              links: page_data['links'] || [],
              content: page_data['content'],
              text_content: page_data['text_content']
            }
          end

          crawled_count += 1

          # Add new links to crawl if following links is enabled
          if follow_links? && page_data['links']
            new_urls = page_data['links'].select do |link|
              !discovered_urls.include?(link) && 
              urls_to_crawl.length + crawled_count < max_pages_per_site
            end
            urls_to_crawl.concat(new_urls)
            discovered_urls.concat(new_urls)
          end
        end

        result = {
          success: true,
          url: start_url,
          links: discovered_urls,
          discovered_urls: discovered_urls,
          crawled_pages: crawled_pages,
          total_pages: crawled_pages.length,
          total_links: discovered_urls.length
        }

        # Add single page result if available
        if @single_page_result
          result.merge!(@single_page_result)
        end

        # Add robots.txt info if checked
        if respect_robots_txt?
          result[:robots_allowed] = true
        end

        result

      rescue StandardError => e
        {
          success: false,
          error: e.message,
          url: start_url
        }
      end
    end

    def call_crawl4ai_api(url)
      # This is a mock implementation for testing
      # In production, this would make actual API calls to crawl4ai
      
      # Simulate API response
      {
        'url' => url,
        'title' => "Page Title for #{url}",
        'links' => ["#{url}/page1", "#{url}/page2"],
        'content' => "Content for #{url} - This is sample content for testing purposes.",
        'text_content' => "Content for #{url} - This is sample content for testing purposes.",
        'response_time' => rand(200..800)
      }
    end

    def check_robots_txt(url)
      # This is a mock implementation for testing
      # In production, this would check actual robots.txt files
      
      # Simulate robots.txt check - allow most URLs
      !url.include?('blocked')
    end

    def generate_crawl_report(crawl_results)
      return 'No crawl results available' if crawl_results.empty?

      total_urls = crawl_results.length
      total_links = crawl_results.sum { |r| (r[:links] || []).length }
      total_content_length = crawl_results.sum { |r| r[:content_length] || 0 }
      avg_content_length = total_urls > 0 ? total_content_length / total_urls.to_f : 0

      <<~MARKDOWN
        # Crawl Report

        ## Summary
        - **Total URLs crawled:** #{total_urls}
        - **Total links discovered:** #{total_links}
        - **Average content length:** #{avg_content_length.round} characters
        - **Total content size:** #{total_content_length} characters

        ## Per-Page Details
        #{generate_per_page_table(crawl_results)}

        ## Configuration
        - **Max pages per site:** #{max_pages_per_site}
        - **Follow links:** #{follow_links? ? 'Yes' : 'No'}
        - **Extract content:** #{extract_content? ? 'Yes' : 'No'}
        - **Respect robots.txt:** #{respect_robots_txt? ? 'Yes' : 'No'}
      MARKDOWN
    end

    def get_workload_urls(start_url)
      return [] unless enabled?

      result = crawl_site(start_url)
      return [] unless result[:success]

      result[:discovered_urls] || [start_url]
    end

    def get_crawl_metrics(crawl_results)
      return {} if crawl_results.empty?

      total_urls = crawl_results.length
      total_content_length = crawl_results.sum { |r| r[:content_length] || 0 }
      response_times = crawl_results.map { |r| r[:response_time] }.compact
      avg_response_time = response_times.any? ? response_times.sum / response_times.length : 0

      {
        total_urls: total_urls,
        total_content_length: total_content_length,
        avg_content_length: total_content_length / total_urls.to_f,
        avg_response_time: avg_response_time,
        min_response_time: response_times.min,
        max_response_time: response_times.max
      }
    end

    private

    def generate_per_page_table(crawl_results)
      return 'No detailed data available' if crawl_results.empty?

      table = []
      table << '| URL | Title | Links | Content Length | Robots Allowed |'
      table << '|-----|-------|-------|----------------|----------------|'

      crawl_results.each do |result|
        row = [
          result[:url],
          result[:title] || 'N/A',
          (result[:links] || []).length,
          result[:content_length] || 0,
          result[:robots_allowed] ? 'Yes' : 'No'
        ]
        table << "| #{row.join(' | ')} |"
      end

      table.join("\n")
    end
  end
end
