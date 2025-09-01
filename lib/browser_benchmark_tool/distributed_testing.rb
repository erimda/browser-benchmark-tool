# frozen_string_literal: true

require 'net/http'
require 'uri'
require 'json'
require 'timeout'

module BrowserBenchmarkTool
  class DistributedTesting
    attr_reader :config

    def initialize(config)
      @config = config
      @enabled = config.distributed&.dig(:enabled) || false
      @current_primary_node = nil
    end

    def enabled?
      @enabled
    end

    def nodes
      config.distributed&.dig(:nodes) || []
    end

    def coordinator_port
      config.distributed&.dig(:coordinator_port) || 9000
    end

    def load_balancing
      config.distributed&.dig(:load_balancing) || 'round_robin'
    end

    def health_check_interval
      config.distributed&.dig(:health_check_interval) || 30
    end

    def failover_enabled?
      config.distributed&.dig(:failover_enabled) || false
    end

    def node_weights
      config.distributed&.dig(:node_weights) || {}
    end

    def distribute_workload(urls, concurrency_level)
      return { distributed: false, error: 'Distributed testing not enabled' } unless enabled?
      return { distributed: false, error: 'No nodes configured' } if nodes.empty?

      case load_balancing
      when 'round_robin'
        distribute_round_robin(urls, concurrency_level)
      when 'weighted'
        distribute_weighted(urls, concurrency_level)
      else
        distribute_round_robin(urls, concurrency_level)
      end
    end

    def health_check
      return {} unless enabled?

      health_status = {}
      nodes.each do |node|
        health_status[node] = check_node_health(node)
      end
      health_status
    end

    def handle_failover(failed_node)
      return { failover_occurred: false, error: 'Failover not enabled' } unless failover_enabled?

      # Find a healthy node to promote
      healthy_nodes = health_check.select { |_, status| status[:status] == 'healthy' }.keys
      healthy_nodes.delete(failed_node)

      if healthy_nodes.any?
        @current_primary_node = healthy_nodes.first
        {
          failover_occurred: true,
          failed_node: failed_node,
          new_primary: @current_primary_node,
          timestamp: Time.now.strftime('%Y-%m-%dT%H:%M:%S.%LZ')
        }
      else
        {
          failover_occurred: false,
          error: 'No healthy nodes available for failover'
        }
      end
    end

    def collect_results
      return [] unless enabled?

      combined_results = []
      nodes.each do |node|
        begin
          node_results = collect_node_results(node)
          if node_results.is_a?(Array)
            combined_results.concat(node_results)
          elsif node_results.is_a?(Hash) && node_results[:error]
            # Log error but continue with other nodes
            puts "Warning: Failed to collect results from #{node}: #{node_results[:error]}"
          end
        rescue StandardError => e
          puts "Error collecting results from #{node}: #{e.message}"
        end
      end
      combined_results
    end

    def monitor_performance
      return {} unless enabled?

      performance_data = {}
      nodes.each do |node|
        performance_data[node] = get_node_performance(node)
      end
      performance_data
    end

    def identify_bottlenecks
      return [] unless enabled?

      bottlenecks = []
      performance_data = monitor_performance

      performance_data.each do |node, data|
        if data[:cpu] && data[:cpu] > 0.8
          bottlenecks << {
            node: node,
            issue: 'high CPU usage',
            value: data[:cpu],
            threshold: 0.8
          }
        end

        if data[:memory] && data[:memory] > 0.8
          bottlenecks << {
            node: node,
            issue: 'high memory usage',
            value: data[:memory],
            threshold: 0.8
          }
        end

        if data[:requests_per_second] && data[:requests_per_second] < 50
          bottlenecks << {
            node: node,
            issue: 'low throughput',
            value: data[:requests_per_second],
            threshold: 50
          }
        end
      end

      bottlenecks
    end

    def run_distributed_benchmark(urls, concurrency_level)
      return { distributed: false, error: 'Distributed testing not enabled' } unless enabled?

      # Distribute workload
      distribution = distribute_workload(urls, concurrency_level)
      return distribution unless distribution[:distributed]

      # Execute on distributed nodes
      results = []
      distribution[:workload_per_node].each do |node_workload|
        node_result = execute_node_workload(node_workload)
        results << node_result if node_result
      end

      # Combine results
      combined_results = results.flatten.compact
      {
        distributed: true,
        nodes_used: distribution[:nodes_used],
        total_requests: combined_results.length,
        successful_requests: combined_results.count { |r| r[:success] },
        failed_requests: combined_results.count { |r| !r[:success] },
        results: combined_results
      }
    end

    def get_distributed_metrics
      return {} unless enabled?

      benchmark_result = run_distributed_benchmark([], 0)
      return {} unless benchmark_result[:distributed]

      total_requests = benchmark_result[:total_requests]
      successful_requests = benchmark_result[:successful_requests]
      failed_requests = benchmark_result[:failed_requests]

      {
        total_requests: total_requests,
        successful_requests: successful_requests,
        failed_requests: failed_requests,
        success_rate: total_requests > 0 ? successful_requests.to_f / total_requests : 0.0,
        nodes_used: benchmark_result[:nodes_used],
        distributed: true
      }
    end

    private

    def distribute_round_robin(urls, concurrency_level)
      return { distributed: false, error: 'No nodes available' } if nodes.empty?

      workload_per_node = []
      nodes.each_with_index do |node, index|
        node_urls = urls.select.with_index { |_, url_index| url_index % nodes.length == index }
        node_concurrency = (concurrency_level.to_f / nodes.length).ceil

        workload_per_node << {
          node: node,
          urls: node_urls,
          concurrency: node_concurrency,
          load_balancing: 'round_robin'
        }
      end

      {
        distributed: true,
        nodes_used: nodes.length,
        load_balancing: 'round_robin',
        workload_per_node: workload_per_node
      }
    end

    def distribute_weighted(urls, concurrency_level)
      return { distributed: false, error: 'No nodes available' } if nodes.empty?

      # Calculate total weight
      total_weight = node_weights.values.sum
      return distribute_round_robin(urls, concurrency_level) if total_weight.zero?

      workload_per_node = []
      nodes.each do |node|
        weight = node_weights[node] || 1
        node_concurrency = (concurrency_level * weight / total_weight.to_f).ceil
        
        # Distribute URLs proportionally
        node_url_count = (urls.length * weight / total_weight.to_f).ceil
        node_urls = urls.first(node_url_count)
        urls = urls.drop(node_url_count)

        workload_per_node << {
          node: node,
          urls: node_urls,
          concurrency: node_concurrency,
          weight: weight,
          load_balancing: 'weighted'
        }
      end

      {
        distributed: true,
        nodes_used: nodes.length,
        load_balancing: 'weighted',
        workload_per_node: workload_per_node
      }
    end

    def check_node_health(node)
      # This is a mock implementation for testing
      # In production, this would make actual health check requests
      
      # Simulate health check
      response_time = rand(20..100)
      status = response_time < 80 ? 'healthy' : 'unhealthy'
      
      {
        status: status,
        response_time: response_time,
        timestamp: Time.now.strftime('%Y-%m-%dT%H:%M:%S.%LZ')
      }
    end

    def collect_node_results(node)
      # This is a mock implementation for testing
      # In production, this would collect actual results from the node
      
      # Simulate node results
      [
        { url: "#{node}/test1", success: true, duration_ms: rand(200..800) },
        { url: "#{node}/test2", success: true, duration_ms: rand(200..800) }
      ]
    end

    def get_node_performance(node)
      # This is a mock implementation for testing
      # In production, this would collect actual performance metrics from the node
      
      # Simulate performance data
      {
        cpu: rand(0.1..0.9),
        memory: rand(0.2..0.8),
        requests_per_second: rand(50..150),
        timestamp: Time.now.strftime('%Y-%m-%dT%H:%M:%S.%LZ')
      }
    end

    def execute_node_workload(node_workload)
      # This is a mock implementation for testing
      # In production, this would execute the workload on the actual node
      
      # Simulate execution
      node_workload[:urls].map do |url|
        {
          url: url,
          success: rand > 0.1, # 90% success rate
          duration_ms: rand(200..800),
          node: node_workload[:node]
        }
      end
    end
  end
end
