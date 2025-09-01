# frozen_string_literal: true

require 'securerandom'

module BrowserBenchmarkTool
  class BrowserModeOptions
    attr_reader :config

    def initialize(config)
      @config = config
      @browser_mode = config.browser_mode || {}
      @context_pool = []
      @process_pool = []
      @instance_counter = 0
      @pool_stats = {
        context: { total: 0, in_use: 0, available: 0 },
        process: { total: 0, in_use: 0, available: 0 }
      }
    end

    def mode
      @browser_mode[:mode] || 'context'
    end

    def context_mode?
      mode == 'context'
    end

    def process_mode?
      mode == 'process'
    end

    def context_pool_size
      config.browser_mode[:context_pool_size] || 5
    end

    def process_limit
      @browser_mode[:process_limit] || 3
    end

    def context_reuse?
      @browser_mode[:context_reuse] || true
    end

    def process_isolation?
      @browser_mode[:process_isolation] || false
    end

    def memory_per_context
      @browser_mode[:memory_per_context] || 100
    end

    def memory_per_process
      @browser_mode[:memory_per_process] || 500
    end

    def context_timeout
      @browser_mode[:context_timeout] || 30
    end

    def process_timeout
      @browser_mode[:process_timeout] || 60
    end

    def enable_context_pooling?
      config.browser_mode.key?(:enable_context_pooling) ? config.browser_mode[:enable_context_pooling] : true
    end

    def enable_process_pooling?
      @browser_mode[:enable_process_pooling] || false
    end

    def get_browser_instance
      if context_mode?
        get_context_instance
      else
        get_process_instance
      end
    end

    def release_browser_instance(instance_id)
      if context_mode?
        release_context_instance(instance_id)
      else
        release_process_instance(instance_id)
      end
    end

    def get_pool_status
      if context_mode?
        {
          mode: 'context',
          total_instances: @pool_stats[:context][:total],
          available_instances: @pool_stats[:context][:available],
          in_use_instances: @pool_stats[:context][:in_use],
          pool_size: context_pool_size,
          memory_per_instance: memory_per_context
        }
      else
        {
          mode: 'process',
          total_instances: @pool_stats[:process][:total],
          available_instances: @pool_stats[:process][:available],
          in_use_instances: @pool_stats[:process][:in_use],
          process_limit: process_limit,
          memory_per_instance: memory_per_process
        }
      end
    end

    def configure_for_workload(workload_config)
      result = { success: true }

      # Adjust pool size based on concurrency
      if workload_config[:concurrency]
        if context_mode? && enable_context_pooling?
          new_pool_size = [workload_config[:concurrency], context_pool_size].max
          if new_pool_size != context_pool_size
            @browser_mode[:context_pool_size] = new_pool_size
            result[:pool_size_adjusted] = true
            result[:new_pool_size] = new_pool_size
          end
        elsif process_mode? && enable_process_pooling?
          new_process_limit = [workload_config[:concurrency], process_limit].max
          if new_process_limit != process_limit
            @browser_mode[:process_limit] = new_process_limit
            result[:process_limit_adjusted] = true
            result[:new_process_limit] = new_process_limit
          end
        end
      end

      # Switch mode for high isolation requirements
      if workload_config[:isolation_level] == 'high' && context_mode?
        result[:mode_switched] = true
        result[:new_mode] = 'process'
        @browser_mode[:mode] = 'process'
      end

      # Optimize memory usage for large workloads
      if workload_config[:memory_intensive] && workload_config[:concurrency] && workload_config[:concurrency] > 10
        if context_mode?
          new_memory_per_context = (memory_per_context * 0.8).round
          @browser_mode[:memory_per_context] = new_memory_per_context
          result[:memory_optimized] = true
          result[:memory_per_instance] = new_memory_per_context
        end
      end

      result
    end

    def get_performance_metrics
      if context_mode?
        {
          mode: 'context',
          memory_usage: @pool_stats[:context][:total] * memory_per_context,
          instance_count: @pool_stats[:context][:total],
          pool_efficiency: calculate_pool_efficiency(:context),
          total_memory: @pool_stats[:context][:total] * memory_per_context,
          memory_per_instance: memory_per_context
        }
      else
        {
          mode: 'process',
          memory_usage: @pool_stats[:process][:total] * memory_per_process,
          instance_count: @pool_stats[:process][:total],
          isolation_level: process_isolation? ? 'high' : 'standard',
          total_memory: @pool_stats[:process][:total] * memory_per_process,
          memory_per_instance: memory_per_process
        }
      end
    end

    def cleanup_resources
      result = { success: true }

      if context_mode?
        instances_released = @context_pool.length
        @context_pool.clear
        @pool_stats[:context] = { total: 0, in_use: 0, available: 0 }
        result[:instances_released] = instances_released
      else
        processes_terminated = @process_pool.length
        @process_pool.clear
        @pool_stats[:process] = { total: 0, in_use: 0, available: 0 }
        result[:processes_terminated] = processes_terminated
      end

      result
    end

    def integrate_with_automation(automation)
      return false unless automation.respond_to?(:set_browser_mode)

      automation.set_browser_mode(self)
      true
    end

    def switch_mode(new_mode)
      return { success: false, error: 'Invalid mode' } unless ['context', 'process'].include?(new_mode)
      return { success: false, error: 'Already in requested mode' } if mode == new_mode

      # Cleanup current mode resources
      cleanup_resources

      # Switch mode
      @browser_mode[:mode] = new_mode

      { success: true, mode_changed: true, new_mode: new_mode }
    end

    private

    def get_context_instance
      if enable_context_pooling? && @pool_stats[:context][:available] > 0
        # Reuse existing context
        instance = @context_pool.shift
        @pool_stats[:context][:available] -= 1
        @pool_stats[:context][:in_use] += 1
        instance
      elsif enable_context_pooling?
        # Create new context for pool
        instance = create_context_instance
        if instance
          @pool_stats[:context][:available] -= 1
          @pool_stats[:context][:in_use] += 1
        end
        instance
      else
        # Create temporary context (no pooling)
        create_temporary_context_instance
      end
    end

    def get_process_instance
      if enable_process_pooling? && !@process_pool.empty?
        # Reuse existing process
        instance = @process_pool.shift
        @pool_stats[:process][:available] -= 1
        @pool_stats[:process][:in_use] += 1
        instance
      else
        # Create new process
        create_process_instance
      end
    end

    def create_temporary_context_instance
      @instance_counter += 1
      instance = {
        id: "temp_context_#{@instance_counter}",
        type: 'context',
        created_at: Time.now.strftime('%Y-%m-%dT%H:%M:%S.%LZ'),
        memory_limit: memory_per_context,
        timeout: context_timeout,
        temporary: true
      }

      # Don't add to pool or stats for temporary instances
      instance
    end

    def create_context_instance
      return nil if @pool_stats[:context][:total] >= context_pool_size

      @instance_counter += 1
      instance = {
        id: "context_#{@instance_counter}",
        type: 'context',
        created_at: Time.now.strftime('%Y-%m-%dT%H:%M:%S.%LZ'),
        memory_limit: memory_per_context,
        timeout: context_timeout
      }

      # Only add to pool if pooling is enabled
      if enable_context_pooling?
        @context_pool << instance
        @pool_stats[:context][:total] += 1
        @pool_stats[:context][:available] += 1
      end

      instance
    end

    def create_process_instance
      return nil if @pool_stats[:process][:total] >= process_limit

      @instance_counter += 1
      instance = {
        id: "process_#{@instance_counter}",
        type: 'process',
        created_at: Time.now.strftime('%Y-%m-%dT%H:%M:%S.%LZ'),
        memory_limit: memory_per_process,
        timeout: process_timeout,
        isolated: process_isolation?
      }

      @process_pool << instance
      @pool_stats[:process][:total] += 1
      @pool_stats[:process][:available] += 1

      instance
    end

    def release_context_instance(instance_id)
      instance = find_instance_by_id(instance_id, @context_pool)
      return { success: false, error: 'Instance not found' } unless instance

      if enable_context_pooling? && @pool_stats[:context][:total] < context_pool_size
        # Return to pool for reuse
        @context_pool << instance
        @pool_stats[:context][:in_use] -= 1
        @pool_stats[:context][:available] += 1
        { success: true, released: true, reused: true }
      else
        # Remove instance
        @context_pool.delete(instance)
        @pool_stats[:context][:total] -= 1
        @pool_stats[:context][:in_use] -= 1
        { success: true, released: true, removed: true }
      end
    end

    def release_process_instance(instance_id)
      instance = find_instance_by_id(instance_id, @process_pool)
      return { success: false, error: 'Instance not found' } unless instance

      if enable_process_pooling? && @pool_stats[:process][:total] < process_limit
        # Return to pool for reuse
        @process_pool << instance
        @pool_stats[:process][:in_use] -= 1
        @pool_stats[:process][:available] += 1
        { success: true, terminated: false, reused: true }
      else
        # Terminate process
        @process_pool.delete(instance)
        @pool_stats[:process][:total] -= 1
        @pool_stats[:process][:in_use] -= 1
        { success: true, terminated: true, removed: true }
      end
    end

    def find_instance_by_id(instance_id, pool)
      pool.find { |instance| instance[:id] == instance_id }
    end

    def calculate_pool_efficiency(pool_type)
      stats = @pool_stats[pool_type]
      return 0.0 if stats[:total] == 0

      (stats[:in_use].to_f / stats[:total]) * 100
    end
  end
end
