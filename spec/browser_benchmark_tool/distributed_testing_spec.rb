# frozen_string_literal: true

require 'spec_helper'

RSpec.describe BrowserBenchmarkTool::DistributedTesting, :distributed do
  let(:config) do
    BrowserBenchmarkTool::Config.new.tap do |c|
      c.workload = { mode: 'playwright', engine: 'chromium', headless: true }
      c.distributed = {
        enabled: true,
        nodes: ['http://node1:8080', 'http://node2:8080'],
        coordinator_port: 9000,
        load_balancing: 'round_robin',
        health_check_interval: 30,
        failover_enabled: true
      }
    end
  end

  let(:distributed) { described_class.new(config) }

  describe '#initialize' do
    it 'creates distributed testing with configuration' do
      expect(distributed.config).to eq(config)
      expect(distributed.enabled?).to be true
      expect(distributed.nodes).to eq(['http://node1:8080', 'http://node2:8080'])
    end

    it 'can be disabled via configuration' do
      config.distributed[:enabled] = false
      distributed = described_class.new(config)
      
      expect(distributed.enabled?).to be false
    end
  end

  describe '#distribute_workload' do
    it 'distributes workload across multiple nodes' do
      urls = ['https://example.com', 'https://example.org', 'https://example.net']
      concurrency_level = 6
      
      result = distributed.distribute_workload(urls, concurrency_level)
      
      expect(result).to be_a(Hash)
      expect(result[:distributed]).to be true
      expect(result[:nodes_used]).to eq(2)
      expect(result[:workload_per_node]).to be_a(Array)
    end

    it 'uses round-robin load balancing' do
      config.distributed[:load_balancing] = 'round_robin'
      
      urls = ['https://example.com', 'https://example.org']
      concurrency_level = 4
      
      result = distributed.distribute_workload(urls, concurrency_level)
      
      expect(result[:load_balancing]).to eq('round_robin')
      expect(result[:workload_per_node].length).to eq(2)
    end

    it 'uses weighted load balancing when configured' do
      config.distributed[:load_balancing] = 'weighted'
      config.distributed[:node_weights] = { 'http://node1:8080' => 2, 'http://node2:8080' => 1 }
      
      urls = ['https://example.com', 'https://example.org', 'https://example.net']
      concurrency_level = 6
      
      result = distributed.distribute_workload(urls, concurrency_level)
      
      expect(result[:load_balancing]).to eq('weighted')
      expect(result[:workload_per_node][0][:concurrency]).to be > result[:workload_per_node][1][:concurrency]
    end
  end

  describe '#health_check' do
    it 'checks health of all nodes' do
      # Mock the private method by making it public for testing
      allow(distributed).to receive(:check_node_health).and_return(
        { status: 'healthy', response_time: 50 },
        { status: 'healthy', response_time: 45 }
      )
      
      health_status = distributed.health_check
      
      expect(health_status).to be_a(Hash)
      expect(health_status['http://node1:8080'][:status]).to eq('healthy')
      expect(health_status['http://node2:8080'][:status]).to eq('healthy')
    end

    it 'marks unhealthy nodes as unavailable' do
      allow(distributed).to receive(:check_node_health).and_return(
        { status: 'unhealthy', response_time: 5000 },
        { status: 'healthy', response_time: 45 }
      )
      
      health_status = distributed.health_check
      
      expect(health_status['http://node1:8080'][:status]).to eq('unhealthy')
      expect(health_status['http://node2:8080'][:status]).to eq('healthy')
    end
  end

  describe '#failover' do
    it 'enables failover when primary node fails' do
      config.distributed[:failover_enabled] = true
      
      # Mock primary node failure
      allow(distributed).to receive(:check_node_health).and_return(
        { status: 'unhealthy', response_time: 5000 },
        { status: 'healthy', response_time: 45 }
      )
      
      result = distributed.handle_failover('http://node1:8080')
      
      expect(result[:failover_occurred]).to be true
      expect(result[:new_primary]).to eq('http://node2:8080')
    end

    it 'disables failover when configured' do
      config.distributed[:failover_enabled] = false
      
      result = distributed.handle_failover('http://node1:8080')
      
      expect(result[:failover_occurred]).to be false
    end
  end

  describe '#collect_results' do
    it 'collects results from all nodes' do
      # Mock node results
      node1_results = [{ url: 'https://example.com', success: true, duration_ms: 500 }]
      node2_results = [{ url: 'https://example.org', success: true, duration_ms: 600 }]
      
      allow(distributed).to receive(:collect_node_results).and_return(
        node1_results,
        node2_results
      )
      
      combined_results = distributed.collect_results
      
      expect(combined_results).to be_an(Array)
      expect(combined_results.length).to eq(2)
      expect(combined_results.first[:url]).to eq('https://example.com')
      expect(combined_results.last[:url]).to eq('https://example.org')
    end

    it 'handles partial node failures gracefully' do
      # Mock one node success, one node failure
      allow(distributed).to receive(:collect_node_results).and_return(
        [{ url: 'https://example.com', success: true }],
        { error: 'Connection failed' }
      )
      
      combined_results = distributed.collect_results
      
      expect(combined_results).to be_an(Array)
      expect(combined_results.length).to eq(1)
      expect(combined_results.first[:url]).to eq('https://example.com')
    end
  end

  describe '#monitor_performance' do
    it 'monitors performance across all nodes' do
      # Mock performance data
      allow(distributed).to receive(:get_node_performance).and_return(
        { cpu: 0.6, memory: 0.7, requests_per_second: 100 },
        { cpu: 0.5, memory: 0.6, requests_per_second: 95 }
      )
      
      performance = distributed.monitor_performance
      
      expect(performance).to be_a(Hash)
      expect(performance['http://node1:8080'][:cpu]).to eq(0.6)
      expect(performance['http://node2:8080'][:requests_per_second]).to eq(95)
    end

    it 'identifies performance bottlenecks' do
      # Mock performance data with bottleneck
      allow(distributed).to receive(:get_node_performance).and_return(
        { cpu: 0.9, memory: 0.8, requests_per_second: 50 },
        { cpu: 0.5, memory: 0.6, requests_per_second: 95 }
      )
      
      bottlenecks = distributed.identify_bottlenecks
      
      expect(bottlenecks).to be_an(Array)
      expect(bottlenecks.first[:node]).to eq('http://node1:8080')
      expect(bottlenecks.first[:issue]).to include('high CPU')
    end
  end

  describe 'integration with benchmark' do
    it 'can coordinate distributed benchmark execution' do
      # Mock distributed execution
      allow(distributed).to receive(:distribute_workload).and_return(
        { distributed: true, nodes_used: 2, workload_per_node: [] }
      )
      allow(distributed).to receive(:collect_results).and_return([])
      
      result = distributed.run_distributed_benchmark(['https://example.com'], 4)
      
      expect(result[:distributed]).to be true
      expect(result[:nodes_used]).to eq(2)
    end

    it 'provides distributed benchmark metrics' do
      # Mock benchmark execution
      allow(distributed).to receive(:run_distributed_benchmark).and_return(
        { distributed: true, total_requests: 100, successful_requests: 95, failed_requests: 5 }
      )
      
      metrics = distributed.get_distributed_metrics
      
      expect(metrics[:total_requests]).to eq(100)
      expect(metrics[:success_rate]).to eq(0.95)
    end
  end
end
