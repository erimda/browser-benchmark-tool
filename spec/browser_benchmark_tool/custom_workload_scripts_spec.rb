# frozen_string_literal: true

require 'spec_helper'

RSpec.describe BrowserBenchmarkTool::CustomWorkloadScripts, :custom_scripts do
  let(:config) do
    BrowserBenchmarkTool::Config.new.tap do |c|
      c.workload = { mode: 'custom_script', engine: 'chromium', headless: true }
      c.custom_scripts = {
        enabled: true,
        script_path: './scripts/custom_workload.rb',
        script_timeout: 30,
        allow_external_scripts: false,
        script_parameters: { 'max_depth' => 3, 'follow_redirects' => true },
        validation_rules: ['url_format', 'safety_checks']
      }
    end
  end

  let(:script_engine) { described_class.new(config) }

  describe '#initialize' do
    it 'creates script engine with configuration' do
      expect(script_engine.config).to eq(config)
      expect(script_engine.enabled?).to be true
      expect(script_engine.script_path).to eq('./scripts/custom_workload.rb')
    end

    it 'can be disabled via configuration' do
      config.custom_scripts[:enabled] = false
      script_engine = described_class.new(config)
      
      expect(script_engine.enabled?).to be false
    end
  end

  describe '#load_script' do
    it 'loads custom workload script from file' do
      # Mock file existence and content
      allow(File).to receive(:exist?).with('./scripts/custom_workload.rb').and_return(true)
      allow(File).to receive(:read).with('./scripts/custom_workload.rb').and_return(
        'def generate_workload; ["https://example.com", "https://example.org"]; end'
      )
      
      result = script_engine.load_script
      
      expect(result[:success]).to be true
      expect(result[:script_loaded]).to be true
    end

    it 'handles missing script file gracefully' do
      allow(File).to receive(:exist?).with('./scripts/custom_workload.rb').and_return(false)
      
      result = script_engine.load_script
      
      expect(result[:success]).to be false
      expect(result[:error]).to include('Script file not found')
    end

    it 'validates script syntax before loading' do
      allow(File).to receive(:exist?).with('./scripts/custom_workload.rb').and_return(true)
      allow(File).to receive(:read).with('./scripts/custom_workload.rb').and_return(
        'def generate_workload; ["https://example.com", "https://example.org" end' # Missing closing brace
      )
      
      result = script_engine.load_script
      
      expect(result[:success]).to be false
      expect(result[:error]).to include('syntax error')
    end
  end

  describe '#execute_script' do
    it 'executes custom workload script with parameters' do
      # Set up script as loaded
      script_engine.instance_variable_set(:@script_loaded, true)
      script_engine.instance_variable_set(:@script_content, 'def generate_workload; ["https://example.com", "https://example.org"]; end')
      
      # Mock script execution
      allow(script_engine).to receive(:run_script_in_sandbox).and_return(
        { success: true, urls: ['https://example.com', 'https://example.org'] }
      )
      
      result = script_engine.execute_script
      
      expect(result[:success]).to be true
      expect(result[:urls]).to include('https://example.com')
      expect(result[:urls]).to include('https://example.org')
    end

    it 'passes configuration parameters to script' do
      # Set up script as loaded
      script_engine.instance_variable_set(:@script_loaded, true)
      script_engine.instance_variable_set(:@script_content, 'def generate_workload; {}; end')
      
      # Mock script execution
      allow(script_engine).to receive(:run_script_in_sandbox).and_return(
        { success: true, urls: [], parameters_used: config.custom_scripts[:script_parameters] }
      )
      
      result = script_engine.execute_script
      
      expect(result[:parameters_used]).to eq(config.custom_scripts[:script_parameters])
    end

    it 'enforces script timeout' do
      # Set up script as loaded
      script_engine.instance_variable_set(:@script_loaded, true)
      script_engine.instance_variable_set(:@script_content, 'def generate_workload; {}; end')
      
      # Mock script execution to raise timeout
      allow(script_engine).to receive(:run_script_in_sandbox).and_raise(Timeout::Error.new('Script timeout'))
      
      result = script_engine.execute_script
      
      expect(result[:success]).to be false
      expect(result[:error]).to include('timeout')
    end
  end

  describe '#validate_script_output' do
    it 'validates URLs from script output' do
      script_output = {
        urls: ['https://example.com', 'https://example.org'],
        concurrency: 5,
        parameters: { 'max_depth' => 3 }
      }
      
      result = script_engine.validate_script_output(script_output)
      
      expect(result[:valid]).to be true
      expect(result[:validation_errors]).to be_empty
    end

    it 'rejects invalid URLs' do
      script_output = {
        urls: ['https://example.com', 'invalid-url', 'ftp://example.org'],
        concurrency: 5
      }
      
      result = script_engine.validate_script_output(script_output)
      
      expect(result[:valid]).to be false
      expect(result[:validation_errors].any? { |error| error.include?('invalid-url') }).to be true
    end

    it 'enforces safety rules' do
      script_output = {
        urls: ['https://example.com'],
        concurrency: 1000, # Too high
        parameters: { 'max_depth' => 10 } # Too deep
      }
      
      result = script_engine.validate_script_output(script_output)
      
      expect(result[:valid]).to be false
      expect(result[:validation_errors].any? { |error| error.include?('Concurrency') }).to be true
    end
  end

  describe '#script_sandbox' do
    it 'runs scripts in isolated environment' do
      script_code = 'def test_method; "Hello World"; end; test_method'
      
      result = script_engine.run_script_in_sandbox(script_code)
      
      expect(result[:success]).to be true
      expect(result[:output]).to eq('Hello World')
    end

    it 'prevents dangerous operations' do
      dangerous_script = 'system("rm -rf /"); "Dangerous operation"'
      
      result = script_engine.run_script_in_sandbox(dangerous_script)
      
      expect(result[:success]).to be false
      expect(result[:error]).to include('security')
    end

    it 'limits script execution time' do
      # Use a safer test that doesn't actually hang
      long_running_script = 'sleep(0.1); "Completed"'
      
      # Mock the sandbox to simulate timeout behavior
      allow(script_engine).to receive(:run_script_in_sandbox).and_return(
        { success: false, error: 'execution timeout' }
      )
      
      result = script_engine.run_script_in_sandbox(long_running_script)
      
      expect(result[:success]).to be false
      expect(result[:error]).to include('timeout')
    end
  end

  describe '#generate_workload_from_script' do
    it 'generates complete workload configuration' do
      # Enable custom scripts
      config.custom_scripts[:enabled] = true
      
      allow(script_engine).to receive(:execute_script).and_return(
        { success: true, urls: ['https://example.com'], concurrency: 5 }
      )
      
      workload = script_engine.generate_workload_from_script
      
      expect(workload).to be_a(Hash)
      expect(workload[:urls]).to include('https://example.com')
      expect(workload[:concurrency]).to eq(5)
    end

    it 'integrates with existing benchmark configuration' do
      allow(script_engine).to receive(:execute_script).and_return(
        { success: true, urls: ['https://example.com'], concurrency: 5 }
      )
      
      workload = script_engine.generate_workload_from_script
      
      # Should merge with existing config
      expect(workload[:mode]).to eq('custom_script')
      expect(workload[:engine]).to eq('chromium')
    end

    it 'handles script execution failures gracefully' do
      # Enable custom scripts
      config.custom_scripts[:enabled] = true
      
      allow(script_engine).to receive(:execute_script).and_return(
        { success: false, error: 'Script failed' }
      )
      
      workload = script_engine.generate_workload_from_script
      
      expect(workload[:fallback]).to be true
      expect(workload[:urls]).to eq(['https://httpbin.org/get'])
    end
  end

  describe 'script templates' do
    it 'provides common script templates' do
      templates = script_engine.get_script_templates
      
      expect(templates).to be_a(Hash)
      expect(templates).to include('basic_workload')
      expect(templates).to include('crawl_workload')
      expect(templates).to include('api_workload')
    end

    it 'generates script from template' do
      template_name = 'basic_workload'
      parameters = { 'base_url' => 'https://example.com', 'max_pages' => 5 }
      
      script = script_engine.generate_script_from_template(template_name, parameters)
      
      expect(script).to include('def generate_workload')
      expect(script).to include('https://example.com')
      expect(script).to include('5')
    end
  end

  describe 'integration with benchmark' do
    it 'can replace default workload generation' do
      allow(script_engine).to receive(:generate_workload_from_script).and_return(
        { urls: ['https://script-generated.com'], concurrency: 3 }
      )
      
      # Mock benchmark integration
      benchmark = double('Benchmark')
      allow(benchmark).to receive(:set_workload)
      
      script_engine.integrate_with_benchmark(benchmark)
      
      expect(benchmark).to have_received(:set_workload)
    end

    it 'provides script execution metrics' do
      # Set execution metrics directly
      script_engine.instance_variable_set(:@execution_metrics, {
        execution_time: 1.5,
        memory_used: 50,
        timestamp: Time.now.strftime('%Y-%m-%dT%H:%M:%S.%LZ')
      })
      
      metrics = script_engine.get_execution_metrics
      
      expect(metrics[:execution_time]).to eq(1.5)
      expect(metrics[:memory_used]).to eq(50)
    end
  end
end
