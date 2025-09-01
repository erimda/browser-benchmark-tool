# frozen_string_literal: true

require 'spec_helper'

RSpec.describe BrowserBenchmarkTool::HeadedBrowserSupport, :headed_browser do
  let(:config) do
    BrowserBenchmarkTool::Config.new.tap do |c|
      c.workload = { mode: 'playwright', engine: 'chromium', headless: false }
      c.headed_browser = {
        enabled: true,
        display_mode: 'headed', # 'headed', 'headless', 'auto'
        window_size: { width: 1920, height: 1080 },
        viewport_size: { width: 1366, height: 768 },
        fullscreen: false,
        show_devtools: false,
        slow_mo: 0,
        timeout: 30,
        screenshot_on_failure: true,
        video_recording: false,
        enable_visual_debugging: true,
        browser_flags: ['--disable-web-security', '--disable-features=VizDisplayCompositor'],
        user_agent: 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36',
        locale: 'en-US',
        timezone: 'America/New_York',
        geolocation: { latitude: 40.7128, longitude: -74.0060 },
        permissions: ['geolocation', 'notifications', 'camera'],
        extra_http_headers: { 'Accept-Language': 'en-US,en;q=0.9' }
      }
    end
  end

  let(:headed_browser) { described_class.new(config) }

  describe '#initialize' do
    it 'creates headed browser support with configuration' do
      expect(headed_browser.config).to eq(config)
      expect(headed_browser.enabled?).to be true
      expect(headed_browser.display_mode).to eq('headed')
      expect(headed_browser.window_size).to eq({ width: 1920, height: 1080 })
    end

    it 'can be configured for headless mode' do
      config.headed_browser[:display_mode] = 'headless'
      headed_browser = described_class.new(config)
      
      expect(headed_browser.display_mode).to eq('headless')
      expect(headed_browser.headless?).to be true
      expect(headed_browser.headed?).to be false
    end

    it 'can be configured for auto mode' do
      config.headed_browser[:display_mode] = 'auto'
      headed_browser = described_class.new(config)
      
      expect(headed_browser.display_mode).to eq('auto')
      expect(headed_browser.auto_mode?).to be true
    end
  end

  describe '#headed?' do
    it 'returns true when display mode is headed' do
      config.headed_browser[:display_mode] = 'headed'
      headed_browser = described_class.new(config)
      
      expect(headed_browser.headed?).to be true
    end

    it 'returns false when display mode is headless' do
      config.headed_browser[:display_mode] = 'headless'
      headed_browser = described_class.new(config)
      
      expect(headed_browser.headed?).to be false
    end
  end

  describe '#headless?' do
    it 'returns true when display mode is headless' do
      config.headed_browser[:display_mode] = 'headless'
      headed_browser = described_class.new(config)
      
      expect(headed_browser.headless?).to be true
    end

    it 'returns false when display mode is headed' do
      config.headed_browser[:display_mode] = 'headed'
      headed_browser = described_class.new(config)
      
      expect(headed_browser.headless?).to be false
    end
  end

  describe '#auto_mode?' do
    it 'returns true when display mode is auto' do
      config.headed_browser[:display_mode] = 'auto'
      headed_browser = described_class.new(config)
      
      expect(headed_browser.auto_mode?).to be true
    end

    it 'returns false when display mode is headed' do
      config.headed_browser[:display_mode] = 'headed'
      headed_browser = described_class.new(config)
      
      expect(headed_browser.auto_mode?).to be false
    end
  end

  describe '#get_browser_options' do
    it 'returns headed browser options when enabled' do
      config.headed_browser[:display_mode] = 'headed'
      headed_browser = described_class.new(config)
      
      options = headed_browser.get_browser_options
      
      expect(options[:headless]).to be false
      expect(options[:args]).to include('--disable-web-security')
      expect(options[:viewport]).to eq({ width: 1366, height: 768 })
      expect(options[:user_agent]).to include('Mozilla/5.0')
    end

    it 'returns headless browser options when configured' do
      config.headed_browser[:display_mode] = 'headless'
      headed_browser = described_class.new(config)
      
      options = headed_browser.get_browser_options
      
      expect(options[:headless]).to be true
      expect(options[:args]).to include('--disable-web-security')
    end

    it 'includes window size configuration' do
      config.headed_browser[:window_size] = { width: 1600, height: 900 }
      headed_browser = described_class.new(config)
      
      options = headed_browser.get_browser_options
      
      expect(options[:args]).to include('--window-size=1600,900')
    end

    it 'includes fullscreen option when enabled' do
      config.headed_browser[:fullscreen] = true
      headed_browser = described_class.new(config)
      
      options = headed_browser.get_browser_options
      
      expect(options[:args]).to include('--start-maximized')
    end

    it 'includes devtools when enabled' do
      config.headed_browser[:show_devtools] = true
      headed_browser = described_class.new(config)
      
      options = headed_browser.get_browser_options
      
      expect(options[:args]).to include('--auto-open-devtools-for-tabs')
    end
  end

  describe '#get_context_options' do
    it 'returns context options with viewport and locale' do
      config.headed_browser[:viewport_size] = { width: 1200, height: 800 }
      config.headed_browser[:locale] = 'fr-FR'
      headed_browser = described_class.new(config)
      
      options = headed_browser.get_context_options
      
      expect(options[:viewport]).to eq({ width: 1200, height: 800 })
      expect(options[:locale]).to eq('fr-FR')
      expect(options[:timezone_id]).to eq('America/New_York')
    end

    it 'includes geolocation when configured' do
      config.headed_browser[:geolocation] = { latitude: 51.5074, longitude: -0.1278 }
      headed_browser = described_class.new(config)
      
      options = headed_browser.get_context_options
      
      expect(options[:geolocation]).to eq({ latitude: 51.5074, longitude: -0.1278 })
    end

    it 'includes permissions when specified' do
      config.headed_browser[:permissions] = ['microphone', 'payment']
      headed_browser = described_class.new(config)
      
      options = headed_browser.get_context_options
      
      expect(options[:permissions]).to include('microphone', 'payment')
    end

    it 'includes extra HTTP headers' do
      config.headed_browser[:extra_http_headers] = { 'X-Custom-Header' => 'test-value' }
      headed_browser = described_class.new(config)
      
      options = headed_browser.get_context_options
      
      expect(options[:extra_http_headers]).to include('X-Custom-Header' => 'test-value')
    end
  end

  describe '#configure_for_environment' do
    it 'automatically switches to headless in CI environment' do
      config.headed_browser[:display_mode] = 'auto'
      headed_browser = described_class.new(config)
      
      ENV['CI'] = 'true'
      result = headed_browser.configure_for_environment
      
      expect(result[:success]).to be true
      expect(result[:mode_changed]).to be true
      expect(result[:new_mode]).to eq('headless')
      expect(headed_browser.headless?).to be true
      
      ENV.delete('CI')
    end

    it 'keeps headed mode in development environment' do
      config.headed_browser[:display_mode] = 'auto'
      headed_browser = described_class.new(config)
      
      ENV['RACK_ENV'] = 'development'
      result = headed_browser.configure_for_environment
      
      expect(result[:success]).to be true
      expect(result[:mode_changed]).to be false
      expect(headed_browser.headed?).to be true
      
      ENV.delete('RACK_ENV')
    end

    it 'adjusts window size for different screen resolutions' do
      config.headed_browser[:display_mode] = 'headed'
      headed_browser = described_class.new(config)
      
      result = headed_browser.configure_for_environment(screen_resolution: '4K')
      
      expect(result[:success]).to be true
      expect(result[:window_size_adjusted]).to be true
      expect(result[:new_window_size]).to eq({ width: 3840, height: 2160 })
    end
  end

  describe '#get_visual_debugging_options' do
    it 'returns screenshot configuration when enabled' do
      config.headed_browser[:screenshot_on_failure] = true
      headed_browser = described_class.new(config)
      
      options = headed_browser.get_visual_debugging_options
      
      expect(options[:screenshot]).to be true
      expect(options[:screenshot_path]).to include('screenshots')
    end

    it 'returns video recording configuration when enabled' do
      config.headed_browser[:video_recording] = true
      headed_browser = described_class.new(config)
      
      options = headed_browser.get_visual_debugging_options
      
      expect(options[:video]).to be true
      expect(options[:video_path]).to include('videos')
    end

    it 'returns slow motion configuration when set' do
      config.headed_browser[:slow_mo] = 1000
      headed_browser = described_class.new(config)
      
      options = headed_browser.get_visual_debugging_options
      
      expect(options[:slow_mo]).to eq(1000)
    end
  end

  describe '#get_performance_options' do
    it 'returns performance optimization flags' do
      config.headed_browser[:browser_flags] = ['--disable-gpu', '--no-sandbox']
      headed_browser = described_class.new(config)
      
      options = headed_browser.get_performance_options
      
      expect(options[:args]).to include('--disable-gpu', '--no-sandbox')
    end

    it 'includes timeout configuration' do
      config.headed_browser[:timeout] = 60
      headed_browser = described_class.new(config)
      
      options = headed_browser.get_performance_options
      
      expect(options[:timeout]).to eq(60000)
    end
  end

  describe '#get_accessibility_options' do
    it 'returns accessibility testing configuration' do
      config.headed_browser[:enable_visual_debugging] = true
      headed_browser = described_class.new(config)
      
      options = headed_browser.get_accessibility_options
      
      expect(options[:accessibility]).to be true
      expect(options[:color_scheme]).to eq('light')
    end

    it 'includes high contrast mode when specified' do
      config.headed_browser[:accessibility_mode] = 'high_contrast'
      headed_browser = described_class.new(config)
      
      options = headed_browser.get_accessibility_options
      
      expect(options[:color_scheme]).to eq('dark')
      expect(options[:forced_colors]).to eq('active')
    end
  end

  describe '#get_mobile_emulation_options' do
    it 'returns mobile device emulation when configured' do
      config.headed_browser[:mobile_emulation] = {
        device: 'iPhone 12',
        user_agent: 'Mozilla/5.0 (iPhone; CPU iPhone OS 14_0 like Mac OS X)'
      }
      headed_browser = described_class.new(config)
      
      options = headed_browser.get_mobile_emulation_options
      
      expect(options[:device]).to eq('iPhone 12')
      expect(options[:user_agent]).to include('iPhone')
    end

    it 'returns touch simulation when mobile emulation is enabled' do
      config.headed_browser[:mobile_emulation] = { device: 'iPad' }
      headed_browser = described_class.new(config)
      
      options = headed_browser.get_mobile_emulation_options
      
      expect(options[:has_touch]).to be true
      expect(options[:is_mobile]).to be true
    end
  end

  describe '#get_customization_options' do
    it 'returns custom browser flags' do
      config.headed_browser[:browser_flags] = ['--custom-flag', '--another-flag']
      headed_browser = described_class.new(config)
      
      options = headed_browser.get_customization_options
      
      expect(options[:args]).to include('--custom-flag', '--another-flag')
    end

    it 'returns custom user agent' do
      config.headed_browser[:user_agent] = 'Custom User Agent String'
      headed_browser = described_class.new(config)
      
      options = headed_browser.get_customization_options
      
      expect(options[:user_agent]).to eq('Custom User Agent String')
    end

    it 'returns locale and timezone settings' do
      config.headed_browser[:locale] = 'de-DE'
      config.headed_browser[:timezone] = 'Europe/Berlin'
      headed_browser = described_class.new(config)
      
      options = headed_browser.get_customization_options
      
      expect(options[:locale]).to eq('de-DE')
      expect(options[:timezone_id]).to eq('Europe/Berlin')
    end
  end

  describe 'integration with browser automation' do
    it 'provides complete browser configuration to automation system' do
      config.headed_browser[:display_mode] = 'headed'
      headed_browser = described_class.new(config)
      
      # Mock browser automation
      automation = double('BrowserAutomation')
      allow(automation).to receive(:set_browser_options)
      allow(automation).to receive(:set_context_options)
      
      headed_browser.integrate_with_automation(automation)
      
      expect(automation).to have_received(:set_browser_options)
      expect(automation).to have_received(:set_context_options)
    end

    it 'handles mode switching during benchmark execution' do
      config.headed_browser[:display_mode] = 'headed'
      headed_browser = described_class.new(config)
      
      # Start with headed mode
      expect(headed_browser.headed?).to be true
      
      # Switch to headless mode
      result = headed_browser.switch_display_mode('headless')
      
      expect(result[:success]).to be true
      expect(result[:mode_changed]).to be true
      expect(headed_browser.headless?).to be true
    end
  end
end
