# frozen_string_literal: true

require 'fileutils'

module BrowserBenchmarkTool
  class HeadedBrowserSupport
    attr_reader :config

    def initialize(config)
      @config = config
      @headed_browser = config.headed_browser || {}
      @display_mode = @headed_browser[:display_mode] || 'auto'
      @screenshot_dir = 'screenshots'
      @video_dir = 'videos'
      setup_directories
    end

    def enabled?
      @headed_browser[:enabled] || false
    end

    def display_mode
      @display_mode
    end

    def headed?
      display_mode == 'headed'
    end

    def headless?
      display_mode == 'headless'
    end

    def auto_mode?
      display_mode == 'auto'
    end

    def window_size
      @headed_browser[:window_size] || { width: 1920, height: 1080 }
    end

    def viewport_size
      @headed_browser[:viewport_size] || { width: 1366, height: 768 }
    end

    def fullscreen?
      @headed_browser[:fullscreen] || false
    end

    def show_devtools?
      @headed_browser[:show_devtools] || false
    end

    def slow_mo
      @headed_browser[:slow_mo] || 0
    end

    def timeout
      @headed_browser[:timeout] || 30
    end

    def screenshot_on_failure?
      @headed_browser[:screenshot_on_failure] || false
    end

    def video_recording?
      @headed_browser[:video_recording] || false
    end

    def enable_visual_debugging?
      @headed_browser[:enable_visual_debugging] || false
    end

    def browser_flags
      @headed_browser[:browser_flags] || []
    end

    def user_agent
      @headed_browser[:user_agent] || 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36'
    end

    def locale
      @headed_browser[:locale] || 'en-US'
    end

    def timezone
      @headed_browser[:timezone] || 'America/New_York'
    end

    def geolocation
      @headed_browser[:geolocation] || { latitude: 40.7128, longitude: -74.0060 }
    end

    def permissions
      @headed_browser[:permissions] || []
    end

    def extra_http_headers
      @headed_browser[:extra_http_headers] || {}
    end

    def get_browser_options
      options = {
        headless: headless?,
        args: build_browser_args,
        timeout: timeout * 1000 # Convert to milliseconds
      }

      # Add viewport if specified
      options[:viewport] = viewport_size if viewport_size

      # Add user agent if specified
      options[:user_agent] = user_agent if user_agent

      options
    end

    def get_context_options
      options = {
        viewport: viewport_size,
        locale: locale,
        timezone_id: timezone
      }

      # Add geolocation if specified
      options[:geolocation] = geolocation if geolocation

      # Add permissions if specified
      options[:permissions] = permissions if permissions.any?

      # Add extra HTTP headers if specified
      options[:extra_http_headers] = extra_http_headers if extra_http_headers.any?

      options
    end

    def configure_for_environment(environment_options = {})
      result = { success: true }

      # Auto-mode logic
      if auto_mode?
        if ENV['CI'] == 'true'
          # Switch to headless in CI environment
          @display_mode = 'headless'
          result[:mode_changed] = true
          result[:new_mode] = 'headless'
        elsif ENV['RACK_ENV'] == 'development'
          # Keep headed mode in development
          @display_mode = 'headed'
          result[:mode_changed] = false
        else
          # Default to headless for other environments
          @display_mode = 'headless'
          result[:mode_changed] = true
          result[:new_mode] = 'headless'
        end
      end

      # Adjust window size for different screen resolutions
      if environment_options[:screen_resolution]
        new_window_size = get_window_size_for_resolution(environment_options[:screen_resolution])
        if new_window_size != window_size
          @headed_browser[:window_size] = new_window_size
          result[:window_size_adjusted] = true
          result[:new_window_size] = new_window_size
        end
      end

      result
    end

    def get_visual_debugging_options
      options = {}

      if screenshot_on_failure?
        options[:screenshot] = true
        options[:screenshot_path] = File.join(@screenshot_dir, "screenshot_#{Time.now.strftime('%Y%m%d_%H%M%S')}.png")
      end

      if video_recording?
        options[:video] = true
        options[:video_path] = File.join(@video_dir, "video_#{Time.now.strftime('%Y%m%d_%H%M%S')}.mp4")
      end

      if slow_mo > 0
        options[:slow_mo] = slow_mo
      end

      options
    end

    def get_performance_options
      options = {
        args: browser_flags,
        timeout: timeout * 1000
      }

      # Add performance optimization flags
      performance_flags = [
        '--disable-gpu',
        '--no-sandbox',
        '--disable-dev-shm-usage',
        '--disable-setuid-sandbox'
      ]

      options[:args] += performance_flags

      options
    end

    def get_accessibility_options
      options = {
        accessibility: enable_visual_debugging?,
        color_scheme: 'light'
      }

      # Add high contrast mode if specified
      if @headed_browser[:accessibility_mode] == 'high_contrast'
        options[:color_scheme] = 'dark'
        options[:forced_colors] = 'active'
      end

      options
    end

    def get_mobile_emulation_options
      return {} unless @headed_browser[:mobile_emulation]

      mobile_config = @headed_browser[:mobile_emulation]
      options = {
        device: mobile_config[:device],
        has_touch: true,
        is_mobile: true
      }

      # Add custom user agent if specified
      options[:user_agent] = mobile_config[:user_agent] if mobile_config[:user_agent]

      options
    end

    def get_customization_options
      options = {
        args: browser_flags,
        user_agent: user_agent,
        locale: locale,
        timezone_id: timezone
      }

      options
    end

    def integrate_with_automation(automation)
      return false unless automation.respond_to?(:set_browser_options) && automation.respond_to?(:set_context_options)

      automation.set_browser_options(get_browser_options)
      automation.set_context_options(get_context_options)
      true
    end

    def switch_display_mode(new_mode)
      return { success: false, error: 'Invalid mode' } unless ['headed', 'headless', 'auto'].include?(new_mode)
      return { success: false, error: 'Already in requested mode' } if display_mode == new_mode

      @display_mode = new_mode
      { success: true, mode_changed: true, new_mode: new_mode }
    end

    def take_screenshot(name = nil)
      return false unless screenshot_on_failure?

      filename = name || "screenshot_#{Time.now.strftime('%Y%m%d_%H%M%S')}"
      filepath = File.join(@screenshot_dir, "#{filename}.png")

      # Ensure screenshot directory exists
      FileUtils.mkdir_p(@screenshot_dir)

      # In a real implementation, this would capture the actual screenshot
      # For now, we'll just create a placeholder file
      File.write(filepath, "Screenshot placeholder for #{filename}")
      
      { success: true, filepath: filepath, timestamp: Time.now }
    end

    def start_video_recording
      return false unless video_recording?

      filename = "video_#{Time.now.strftime('%Y%m%d_%H%M%S')}"
      filepath = File.join(@video_dir, "#{filename}.mp4")

      # Ensure video directory exists
      FileUtils.mkdir_p(@video_dir)

      # In a real implementation, this would start video recording
      # For now, we'll just return the configuration
      { success: true, filepath: filepath, started_at: Time.now }
    end

    def stop_video_recording
      return false unless video_recording?

      # In a real implementation, this would stop video recording
      { success: true, stopped_at: Time.now }
    end

    def get_environment_info
      {
        display_mode: display_mode,
        window_size: window_size,
        viewport_size: viewport_size,
        user_agent: user_agent,
        locale: locale,
        timezone: timezone,
        geolocation: geolocation,
        permissions: permissions,
        browser_flags: browser_flags,
        screenshot_enabled: screenshot_on_failure?,
        video_enabled: video_recording?,
        visual_debugging_enabled: enable_visual_debugging?
      }
    end

    private

    def setup_directories
      FileUtils.mkdir_p(@screenshot_dir) if screenshot_on_failure?
      FileUtils.mkdir_p(@video_dir) if video_recording?
    end

    def build_browser_args
      args = browser_flags.dup

      # Add window size
      args << "--window-size=#{window_size[:width]},#{window_size[:height]}"

      # Add fullscreen if enabled
      args << '--start-maximized' if fullscreen?

      # Add devtools if enabled
      args << '--auto-open-devtools-for-tabs' if show_devtools?

      # Add performance flags
      args += [
        '--disable-web-security',
        '--disable-features=VizDisplayCompositor',
        '--disable-background-timer-throttling',
        '--disable-backgrounding-occluded-windows',
        '--disable-renderer-backgrounding'
      ]

      args
    end

    def get_window_size_for_resolution(resolution)
      case resolution.to_s.downcase
      when '4k', 'uhd'
        { width: 3840, height: 2160 }
      when '2k', 'qhd'
        { width: 2560, height: 1440 }
      when 'fhd', '1080p'
        { width: 1920, height: 1080 }
      when 'hd', '720p'
        { width: 1280, height: 720 }
      when 'vga'
        { width: 640, height: 480 }
      else
        window_size
      end
    end
  end
end
