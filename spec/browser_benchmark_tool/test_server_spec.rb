# frozen_string_literal: true

require 'spec_helper'
require 'net/http'
require 'uri'

RSpec.describe BrowserBenchmarkTool::TestServer do
  let(:config) do
    BrowserBenchmarkTool::Config.new.tap do |c|
      c.workload = { mode: 'playwright', engine: 'chromium', headless: true }
      c.output = { dir: './artifacts' }
    end
  end

  let(:test_server) { described_class.new(config) }

  describe '#initialize' do
    it 'creates a test server with configuration' do
      expect(test_server.config).to eq(config)
      expect(test_server.port).to be_between(3000, 9999)
    end

    it 'generates unique port for each instance' do
      server1 = described_class.new(config)
      server2 = described_class.new(config)
      
      expect(server1.port).not_to eq(server2.port)
    end
  end

  describe '#start' do
    it 'starts the server and makes it accessible' do
      test_server.start
      
      # Wait a moment for server to start
      sleep(0.5)
      
      # Test basic connectivity
      uri = URI("http://localhost:#{test_server.port}/health")
      response = Net::HTTP.get_response(uri)
      
      expect(response.code).to eq('200')
      expect(response.body).to include('healthy')
      
      test_server.stop
    end

    it 'creates all required test endpoints' do
      test_server.start
      sleep(0.5)
      
      endpoints = [
        '/health',
        '/ok',
        '/slow',
        '/flaky',
        '/heavy',
        '/static/test.html'
      ]
      
      endpoints.each do |endpoint|
        uri = URI("http://localhost:#{test_server.port}#{endpoint}")
        response = Net::HTTP.get_response(uri)
        expect(response.code).to eq('200')
      end
      
      test_server.stop
    end
  end

  describe '#stop' do
    it 'stops the server and makes it inaccessible' do
      test_server.start
      sleep(0.5)
      
      # Verify server is running
      uri = URI("http://localhost:#{test_server.port}/health")
      response = Net::HTTP.get_response(uri)
      expect(response.code).to eq('200')
      
      # Stop server
      test_server.stop
      sleep(0.5)
      
      # Verify server is stopped
      expect { Net::HTTP.get_response(uri) }.to raise_error(Errno::ECONNREFUSED)
    end
  end

  describe '#base_url' do
    it 'returns the base URL for the server' do
      expect(test_server.base_url).to eq("http://localhost:#{test_server.port}")
    end
  end

  describe '#test_urls' do
    it 'returns a list of test URLs for benchmarking' do
      test_server.start
      sleep(0.5)
      
      urls = test_server.test_urls
      
      expect(urls).to include("#{test_server.base_url}/ok")
      expect(urls).to include("#{test_server.base_url}/slow")
      expect(urls).to include("#{test_server.base_url}/heavy")
      expect(urls).to include("#{test_server.base_url}/static/test.html")
      
      test_server.stop
    end
  end

  describe 'endpoint behavior' do
    before do
      test_server.start
      sleep(0.5)
    end

    after do
      test_server.stop
    end

    it 'serves /ok endpoint with fast response' do
      start_time = Time.now
      uri = URI("#{test_server.base_url}/ok")
      response = Net::HTTP.get_response(uri)
      duration = (Time.now - start_time) * 1000
      
      expect(response.code).to eq('200')
      expect(response.body).to include('OK')
      expect(duration).to be < 100 # Should be very fast
    end

    it 'serves /slow endpoint with controlled delay' do
      start_time = Time.now
      uri = URI("#{test_server.base_url}/slow")
      response = Net::HTTP.get_response(uri)
      duration = (Time.now - start_time) * 1000
      
      expect(response.code).to eq('200')
      expect(response.body).to include('Slow Response')
      expect(duration).to be_between(200, 600) # 200-600ms delay
    end

    it 'serves /flaky endpoint with occasional errors' do
      responses = []
      10.times do
        uri = URI("#{test_server.base_url}/flaky")
        response = Net::HTTP.get_response(uri)
        responses << response.code
      end
      
      expect(responses).to include('200')
      expect(responses).to include('500')
      expect(responses.count('500')).to be_between(1, 3) # ~10-30% error rate
    end

    it 'serves /heavy endpoint with high resource usage' do
      uri = URI("#{test_server.base_url}/heavy")
      response = Net::HTTP.get_response(uri)
      
      expect(response.code).to eq('200')
      expect(response.body).to include('Heavy Load')
      expect(response.body.length).to be > 10000 # Large response
    end

    it 'serves static HTML content' do
      uri = URI("#{test_server.base_url}/static/test.html")
      response = Net::HTTP.get_response(uri)
      
      expect(response.code).to eq('200')
      expect(response.body).to include('<html>')
      expect(response.body).to include('<h1>Test Page</h1>')
    end
  end

  describe '#with_server' do
    it 'provides a block interface for server lifecycle' do
      base_url = nil
      
      test_server.with_server do |server|
        base_url = server.base_url
        uri = URI("#{base_url}/health")
        response = Net::HTTP.get_response(uri)
        expect(response.code).to eq('200')
      end
      
      # Server should be stopped after block
      expect { Net::HTTP.get_response(URI("#{base_url}/health")) }.to raise_error(Errno::ECONNREFUSED)
    end
  end

  describe 'concurrent access' do
    it 'handles multiple concurrent requests' do
      test_server.start
      sleep(0.5)
      
      threads = []
      responses = []
      
      5.times do
        threads << Thread.new do
          uri = URI("#{test_server.base_url}/ok")
          response = Net::HTTP.get_response(uri)
          responses << response.code
        end
      end
      
      threads.each(&:join)
      
      expect(responses.length).to eq(5)
      expect(responses.all? { |code| code == '200' }).to be true
      
      test_server.stop
    end
  end
end
