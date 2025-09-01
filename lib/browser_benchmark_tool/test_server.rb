# frozen_string_literal: true

require 'socket'
require 'json'

module BrowserBenchmarkTool
  class TestServer
    attr_reader :config, :port, :server_thread, :server_socket

    def initialize(config)
      @config = config
      @port = find_available_port
      @server_thread = nil
      @server_socket = nil
      @running = false
    end

    def start
      return if @running

      @server_socket = TCPServer.new('localhost', @port)
      @running = true

      @server_thread = Thread.new do
        loop do
          break unless @running

          begin
            client = @server_socket.accept
            Thread.new { handle_request(client) }
          rescue StandardError
            break unless @running
          end
        end
      end

      # Give server time to start
      sleep(0.2)
    end

    def stop
      @running = false
      
      # Close the server socket to stop accepting new connections
      if @server_socket
        @server_socket.close
        @server_socket = nil
      end
      
      # Wait for the server thread to finish
      if @server_thread
        @server_thread.join(2) # Wait up to 2 seconds
        @server_thread = nil
      end
      
      # Give the OS time to release the port
      sleep(0.1)
    end

    def base_url
      "http://localhost:#{@port}"
    end

    def test_urls
      [
        "#{base_url}/ok",
        "#{base_url}/slow",
        "#{base_url}/heavy",
        "#{base_url}/static/test.html"
      ]
    end

    def with_server
      start
      yield self
    ensure
      stop
    end

    private

    def handle_request(client)
      request_line = client.gets
      return unless request_line

      method, path, _version = request_line.strip.split

      # Read headers
      headers = {}
      while (line = client.gets&.strip) && !line.empty?
        key, value = line.split(': ', 2)
        headers[key.downcase] = value if key && value
      end

      response = generate_response(method, path)

      client.write(response)
      client.close
    rescue StandardError
      client&.close
    end

    def generate_response(_method, path)
      case path
      when '/health'
        generate_json_response({ status: 'healthy', timestamp: Time.now.iso8601 })
      when '/ok'
        generate_html_response('OK Response', 'OK', 'Fast response endpoint for testing.')
      when '/slow'
        sleep(rand(0.2..0.6))
        generate_html_response('Slow Response', 'Slow Response',
                               'This endpoint has a controlled delay for testing latency.')
      when '/flaky'
        if rand < 0.2
          generate_error_response(500, 'Internal Server Error', 'Simulated error for testing error handling.')
        else
          generate_html_response('Flaky Response', 'Flaky Response',
                                 'This endpoint occasionally fails for testing error rates.')
        end
      when '/heavy'
        large_content = Array.new(1000) { |i| "<p>Heavy content line #{i + 1}</p>" }.join("\n")
        generate_html_response('Heavy Load', 'Heavy Load',
                               'This endpoint serves large content for testing memory usage.', large_content)
      when '/static/test.html'
        generate_test_page
      else
        generate_error_response(404, 'Not Found', 'Endpoint not found.')
      end
    end

    def generate_html_response(title, heading, description, extra_content = '')
      content = <<~HTML
        <!DOCTYPE html>
        <html>
        <head>
          <title>#{title}</title>
        </head>
        <body>
          <h1>#{heading}</h1>
          <p>#{description}</p>
          <p>Response time: #{Time.now.strftime('%H:%M:%S.%L')}</p>
          #{extra_content}
        </body>
        </html>
      HTML

      <<~HTTP
        HTTP/1.1 200 OK\r
        Content-Type: text/html\r
        Content-Length: #{content.bytesize}\r
        Connection: close\r
        \r
        #{content}
      HTTP
    end

    def generate_json_response(data)
      content = data.to_json

      <<~HTTP
        HTTP/1.1 200 OK\r
        Content-Type: application/json\r
        Content-Length: #{content.bytesize}\r
        Connection: close\r
        \r
        #{content}
      HTTP
    end

    def generate_error_response(status, title, message)
      content = <<~HTML
        <!DOCTYPE html>
        <html>
        <head>
          <title>#{title}</title>
        </head>
        <body>
          <h1>#{title}</h1>
          <p>#{message}</p>
        </body>
        </html>
      HTML

      <<~HTTP
        HTTP/1.1 #{status} #{title}\r
        Content-Type: text/html\r
        Content-Length: #{content.bytesize}\r
        Connection: close\r
        \r
        #{content}
      HTTP
    end

    def generate_test_page
      content = <<~HTML
        <!DOCTYPE html>
        <html>
        <head>
          <title>Test Page</title>
          <style>
            body { font-family: Arial, sans-serif; margin: 40px; }
            .test-section { margin: 20px 0; padding: 15px; border: 1px solid #ccc; }
            .button { padding: 10px 20px; background: #007bff; color: white; border: none; cursor: pointer; }
            .button:hover { background: #0056b3; }
          </style>
        </head>
        <body>
          <h1>Test Page</h1>
          <p>This is a comprehensive test page for browser benchmarking.</p>
        #{'  '}
          <div class="test-section">
            <h2>Interactive Elements</h2>
            <button class="button" onclick="alert('Button clicked!')">Click Me</button>
            <input type="text" placeholder="Enter text here" />
            <select>
              <option>Option 1</option>
              <option>Option 2</option>
              <option>Option 3</option>
            </select>
          </div>
        #{'  '}
          <div class="test-section">
            <h2>Content Sections</h2>
            <p>Lorem ipsum dolor sit amet, consectetur adipiscing elit. Sed do eiusmod tempor incididunt ut labore et dolore magna aliqua.</p>
            <p>Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat.</p>
          </div>
        #{'  '}
          <div class="test-section">
            <h2>Dynamic Content</h2>
            <p>Current time: <span id="current-time"></span></p>
            <script>
              function updateTime() {
                document.getElementById('current-time').textContent = new Date().toLocaleTimeString();
              }
              updateTime();
              setInterval(updateTime, 1000);
            </script>
          </div>
        #{'  '}
          <p>Response time: #{Time.now.strftime('%H:%M:%S.%L')}</p>
        </body>
        </html>
      HTML

      <<~HTTP
        HTTP/1.1 200 OK\r
        Content-Type: text/html\r
        Content-Length: #{content.bytesize}\r
        Connection: close\r
        \r
        #{content}
      HTTP
    end

    def find_available_port
      # Find an available port starting from 3000
      (3000..9999).each do |port|
        begin
          server = TCPServer.new('localhost', port)
          server.close
          # Add a small delay to ensure port is fully released
          sleep(0.01)
          return port
        rescue Errno::EADDRINUSE
          next
        end
      end
      raise 'No available ports found'
    end
  end
end
