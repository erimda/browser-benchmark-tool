# frozen_string_literal: true

require 'spec_helper'

RSpec.describe BrowserBenchmarkTool do
  it 'has a version number' do
    expect(BrowserBenchmarkTool::VERSION).not_to be_nil
  end

  it 'does something useful' do
    expect(BrowserBenchmarkTool::VERSION).to be_a(String)
    expect(BrowserBenchmarkTool::VERSION).to match(/\d+\.\d+\.\d+/)
  end
end
