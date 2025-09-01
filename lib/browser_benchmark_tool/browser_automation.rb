# frozen_string_literal: true

require 'json'
require 'net/http'
require 'uri'

module BrowserBenchmarkTool
  class BrowserAutomation
    def initialize(config)
      @config = config
      @contexts = []
    end

    def setup
      puts "Setting up browser automation (simulated mode)..."
      # In a real implementation, this would initialize Playwright
    end

    def create_context
      context_id = @contexts.length
      @contexts << { id: context_id }
      { id: context_id }
    end

    def run_task(context, url, actions = [])
      start_time = Time.now
      
      begin
        # Simulate browser navigation
        uri = URI(url)
        response = Net::HTTP.get_response(uri)
        
        # Simulate action execution time
        actions.each do |action|
          execute_action_simulation(action)
        end
        
        # Add some random processing time to simulate real browser behavior
        sleep(rand(0.1..0.5))
        
        duration = (Time.now - start_time) * 1000 # Convert to milliseconds
        
        {
          success: response.code == '200',
          duration: duration,
          status_code: response.code.to_i,
          title: "Simulated Page - #{url}",
          content_length: response.body.length,
          url: url
        }
      rescue => e
        duration = (Time.now - start_time) * 1000
        {
          success: false,
          duration: duration,
          error: e.message,
          url: url
        }
      end
    end

    def run_concurrent_tasks(concurrency_level, urls, actions, repetitions)
      puts "Running #{concurrency_level} concurrent browsers with #{repetitions} repetitions each..."
      
      # Create contexts
      contexts = concurrency_level.times.map { create_context }
      
      # Prepare tasks
      tasks = []
      contexts.each_with_index do |context, context_index|
        repetitions.times do |rep_index|
          url = urls[context_index % urls.length]
          tasks << {
            context: context,
            url: url,
            actions: actions,
            context_index: context_index,
            repetition: rep_index
          }
        end
      end
      
      # Run tasks concurrently using threads
      results = []
      threads = tasks.map do |task|
        Thread.new do
          result = run_task(task[:context], task[:url], task[:actions])
          result.merge(
            context_index: task[:context_index],
            repetition: task[:repetition]
          )
        end
      end
      
      threads.each { |thread| results << thread.value }
      results
    end

    def cleanup
      @contexts.clear
      puts "Cleaned up browser contexts"
    end

    private

    def execute_action_simulation(action)
      case action
      when Hash
        if action[:wait_for]
          # Simulate waiting for selector
          sleep(rand(0.1..0.3))
        elsif action[:click]
          # Simulate clicking
          sleep(rand(0.05..0.15))
        elsif action[:screenshot]
          # Simulate screenshot
          sleep(rand(0.2..0.4))
        elsif action[:text]
          # Simulate text extraction
          sleep(rand(0.05..0.1))
        end
      when String
        # Simple selector wait simulation
        sleep(rand(0.1..0.3))
      end
    end
  end
end
