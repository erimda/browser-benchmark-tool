# frozen_string_literal: true

require 'timeout'
require 'uri'

module BrowserBenchmarkTool
  class CustomWorkloadScripts
    attr_reader :config

    def initialize(config)
      @config = config
      @enabled = config.custom_scripts&.dig(:enabled) || false
      @script_loaded = false
      @script_content = nil
      @execution_metrics = {}
    end

    def enabled?
      @enabled
    end

    def script_path
      config.custom_scripts&.dig(:script_path) || './scripts/custom_workload.rb'
    end

    def script_timeout
      config.custom_scripts&.dig(:script_timeout) || 30
    end

    def allow_external_scripts?
      config.custom_scripts&.dig(:allow_external_scripts) || false
    end

    def script_parameters
      config.custom_scripts&.dig(:script_parameters) || {}
    end

    def validation_rules
      config.custom_scripts&.dig(:validation_rules) || ['url_format', 'safety_checks']
    end

    def load_script
      return { success: false, error: 'Custom scripts not enabled' } unless enabled?

      begin
        unless File.exist?(script_path)
          return { success: false, error: 'Script file not found' }
        end

        @script_content = File.read(script_path)
        
        # Validate script syntax
        begin
          RubyVM::InstructionSequence.compile(@script_content)
        rescue SyntaxError => e
          return { success: false, error: "syntax error: #{e.message}" }
        end

        @script_loaded = true
        { success: true, script_loaded: true, script_path: script_path }
      rescue StandardError => e
        { success: false, error: "Failed to load script: #{e.message}" }
      end
    end

    def execute_script
      return { success: false, error: 'Script not loaded' } unless @script_loaded

      start_time = Time.now
      start_memory = get_memory_usage

      begin
        result = Timeout.timeout(script_timeout) do
          run_script_in_sandbox(@script_content)
        end

        execution_time = Time.now - start_time
        memory_used = get_memory_usage - start_memory

        @execution_metrics = {
          execution_time: execution_time,
          memory_used: memory_used,
          timestamp: Time.now.strftime('%Y-%m-%dT%H:%M:%S.%LZ')
        }

        result.merge(@execution_metrics)
      rescue Timeout::Error
        { success: false, error: 'Script execution timeout' }
      rescue StandardError => e
        { success: false, error: "Script execution failed: #{e.message}" }
      end
    end

    def validate_script_output(script_output)
      return { valid: false, validation_errors: ['No output to validate'] } unless script_output

      errors = []

      # Validate URLs
      if script_output[:urls]
        script_output[:urls].each_with_index do |url, index|
          unless valid_url?(url)
            errors << "Invalid URL at index #{index}: #{url}"
          end
        end
      end

      # Validate concurrency
      if script_output[:concurrency]
        if script_output[:concurrency] > 100
          errors << "Concurrency too high: #{script_output[:concurrency]} (max: 100)"
        elsif script_output[:concurrency] < 1
          errors << "Concurrency too low: #{script_output[:concurrency]} (min: 1)"
        end
      end

      # Validate parameters
      if script_output[:parameters]
        script_output[:parameters].each do |key, value|
          case key
          when 'max_depth'
            if value > 10
              errors << "Max depth too high: #{value} (max: 10)"
            end
          when 'follow_redirects'
            unless [true, false].include?(value)
              errors << "follow_redirects must be boolean, got: #{value.class}"
            end
          end
        end
      end

      { valid: errors.empty?, validation_errors: errors }
    end

    def run_script_in_sandbox(script_code)
      return { success: false, error: 'No script content' } unless script_code

      # Create a safe execution environment
      sandbox = create_sandbox_environment

      begin
        # Execute script in sandbox
        result = sandbox.instance_eval(script_code)
        
        # Validate and format result
        if result.is_a?(Array) && result.all? { |item| item.is_a?(String) }
          { success: true, urls: result }
        elsif result.is_a?(Hash)
          { success: true }.merge(result)
        else
          { success: true, output: result }
        end
      rescue SecurityError => e
        { success: false, error: "security violation: #{e.message}" }
      rescue StandardError => e
        { success: false, error: "execution error: #{e.message}" }
      end
    end

    def generate_workload_from_script
      return fallback_workload unless enabled?

      script_result = execute_script
      return fallback_workload unless script_result[:success]

      # Validate script output
      validation = validate_script_output(script_result)
      return fallback_workload unless validation[:valid]

      # Generate workload configuration
      workload = {
        mode: 'custom_script',
        engine: config.workload[:engine] || 'chromium',
        headless: config.workload[:headless] || true,
        urls: script_result[:urls] || [],
        concurrency: script_result[:concurrency] || 1,
        parameters: script_result[:parameters] || {},
        script_generated: true
      }

      fallback_workload.merge(workload)
    end

    def get_script_templates
      {
        'basic_workload' => basic_workload_template,
        'crawl_workload' => crawl_workload_template,
        'api_workload' => api_workload_template
      }
    end

    def generate_script_from_template(template_name, parameters = {})
      template = get_script_templates[template_name]
      return "Unknown template: #{template_name}" unless template

      # Replace placeholders with parameters
      script = template.dup
      parameters.each do |key, value|
        script.gsub!("{{#{key}}}", value.to_s)
      end

      script
    end

    def integrate_with_benchmark(benchmark)
      return false unless enabled?

      workload = generate_workload_from_script
      benchmark.set_workload(workload) if benchmark.respond_to?(:set_workload)
      true
    end

    def get_execution_metrics
      @execution_metrics
    end

    private

    def create_sandbox_environment
      # Create a safe execution environment
      sandbox = Object.new

      # Define safe methods
      sandbox.define_singleton_method(:generate_workload) do
        ['https://example.com']
      end

      sandbox.define_singleton_method(:log) do |message|
        # Safe logging method
        puts "[SCRIPT] #{message}" if ENV['DEBUG']
      end

      sandbox.define_singleton_method(:config) do
        # Access to configuration parameters
        @config ||= {}
      end

      # Prevent dangerous operations
      sandbox.define_singleton_method(:system) do |*args|
        raise SecurityError, 'System calls not allowed in sandbox'
      end

      sandbox.define_singleton_method(:`) do |*args|
        raise SecurityError, 'Backtick execution not allowed in sandbox'
      end

      sandbox.define_singleton_method(:eval) do |*args|
        raise SecurityError, 'Eval not allowed in sandbox'
      end

      sandbox.define_singleton_method(:require) do |*args|
        raise SecurityError, 'Require not allowed in sandbox'
      end

      sandbox.define_singleton_method(:load) do |*args|
        raise SecurityError, 'Load not allowed in sandbox'
      end

      sandbox
    end

    def valid_url?(url)
      return false unless url.is_a?(String)
      
      begin
        uri = URI.parse(url)
        uri.is_a?(URI::HTTP) || uri.is_a?(URI::HTTPS)
      rescue URI::InvalidURIError
        false
      end
    end

    def get_memory_usage
      # Simple memory usage estimation
      GC.stat[:total_allocated_objects]
    end

    def fallback_workload
      {
        mode: 'custom_script',
        engine: config.workload[:engine] || 'chromium',
        headless: config.workload[:headless] || true,
        urls: config.workload[:urls] || ['https://httpbin.org/get'],
        concurrency: 1,
        fallback: true
      }
    end

    def basic_workload_template
      <<~RUBY
        def generate_workload
          base_url = "{{base_url}}"
          max_pages = {{max_pages}}
          
          urls = [base_url]
          (1..max_pages).each do |page|
            urls << "\#{base_url}/page\#{page}"
          end
          
          {
            urls: urls,
            concurrency: 3,
            parameters: {
              max_depth: 2,
              follow_redirects: true
            }
          }
        end
        
        generate_workload
      RUBY
    end

    def crawl_workload_template
      <<~RUBY
        def generate_workload
          base_url = "{{base_url}}"
          max_depth = {{max_depth}}
          
          urls = [base_url]
          discovered_urls = []
          
          # Simulate link discovery
          (1..max_depth).each do |depth|
            level_urls = []
            urls.each do |url|
              level_urls << "\#{url}/level\#{depth}"
              level_urls << "\#{url}/page\#{depth}"
            end
            discovered_urls.concat(level_urls)
          end
          
          {
            urls: discovered_urls.uniq,
            concurrency: 5,
            parameters: {
              max_depth: max_depth,
              follow_redirects: true,
              crawl_mode: true
            }
          }
        end
        
        generate_workload
      RUBY
    end

    def api_workload_template
      <<~RUBY
        def generate_workload
          base_url = "{{base_url}}"
          endpoints = {{endpoints}}
          
          urls = []
          endpoints.each do |endpoint|
            urls << "\#{base_url}\#{endpoint}"
          end
          
          {
            urls: urls,
            concurrency: 2,
            parameters: {
              api_mode: true,
              auth_required: {{auth_required}},
              rate_limit: {{rate_limit}}
            }
          }
        end
        
        generate_workload
      RUBY
    end
  end
end
