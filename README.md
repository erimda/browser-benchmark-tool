# Browser Benchmark Tool

A Ruby-based tool for benchmarking browser performance with comprehensive reporting and safety features.

## Features

- **Multiple Benchmark Modes**: Playwright-based browser automation
- **Flexible Ramp Strategies**: Exponential, linear, and custom concurrency ramping
- **Comprehensive Metrics**: Latency percentiles, CPU usage, memory usage, error rates
- **Safety Features**: Rate limiting, concurrent request limits, robots.txt respect
- **Rich Reporting**: Markdown summaries, JSONL raw data, CSV exports, interactive HTML charts
- **Performance Optimization**: Adaptive timing controls and early termination
- **Test Environment**: Local test server for reproducible testing
- **Memory Leak Detection**: Real-time monitoring and prevention with configurable thresholds
- **Crawl4ai Integration**: Web crawling, link discovery, and workload generation
- **Distributed Testing**: Multi-node load balancing, health checks, and failover
- **Custom Workload Scripts**: Secure Ruby script execution with sandboxing and templates
- **Browser Mode Options**: Context vs process mode management with intelligent pooling
- **Headed Browser Support**: Visual debugging, display mode management, and mobile emulation

## Installation

1. Clone the repository:

```bash
git clone https://github.com/erimda/browser-benchmark-tool.git
cd browser-benchmark-tool
```

2. Install dependencies:

```bash
bundle install
```

## Quick Start

1. **Initialize Configuration**:

```bash
bundle exec exe/bench-browsers init
```

2. **Run a Simple Benchmark**:

```bash
bundle exec exe/bench-browsers benchmark \
  --urls https://example.com \
  --ramp exp:1,2,4 \
  --reps-per-level 3
```

## Usage

### Command Line Interface

The tool provides a comprehensive CLI with the following options:

```bash
bundle exec exe/bench-browsers benchmark [OPTIONS]

Options:
  --mode MODE                    Benchmark mode (playwright)
  --urls URL1,URL2              URLs to benchmark
  --ramp STRATEGY                Ramp strategy (exp:1,2,4 or lin:1,5 or custom:1,3,5)
  --engine ENGINE                Browser engine (chromium, firefox, webkit)
  --headless                     Run browsers in headless mode
  --reps-per-level NUM           Repetitions per concurrency level
  --latency-threshold-x NUM      Latency degradation multiplier
  --cpu-threshold NUM            CPU utilization threshold (0.0-1.0)
  --mem-threshold NUM            Memory utilization threshold (0.0-1.0)
  --level-min-seconds NUM        Minimum seconds per level
  --out-dir DIR                  Output directory for results
```

### Configuration File

You can also use a YAML configuration file (`benchmark.yml`):

```yaml
workload:
  mode: playwright
  engine: chromium
  headless: true
  urls:
    - https://example.com
    - https://test-site.com
  per_browser_repetitions: 3
  min_level_seconds: 30

ramp:
  strategy: exponential
  levels: [1, 2, 4, 8, 16]

thresholds:
  latency_threshold_x: 2.0
  cpu_threshold: 0.8
  mem_threshold: 0.8
  error_rate_threshold: 0.05

output:
  dir: ./benchmark_results
  max_runtime_minutes: 20
  generate_charts: true

safety:
  robots_txt_respect: true
  external_rate_limit_rps: 2
  max_concurrent_requests: 10
  request_timeout_seconds: 30
  max_total_requests: 100
```

## Understanding Reports

The tool generates comprehensive reports in multiple formats:

### 1. **Summary Report** (`summary.md`)

- Human-readable overview of the benchmark
- Configuration details and results summary
- Maximum Sustainable Concurrency (MSC) calculation
- Per-level metrics table
- Links to interactive charts

### 2. **Raw Data** (`metrics.jsonl`)

- Detailed JSON data for each sample
- Includes timestamps, latency percentiles, host metrics, process info
- Perfect for custom analysis or importing into other tools

### 3. **CSV Data** (`metrics.csv`)

- Tabular format for spreadsheet analysis
- Easy to import into Excel, Google Sheets, or data analysis tools

### 4. **Interactive Charts** (HTML files)

- **Latency Chart**: Shows p50, p95, p99 latency vs concurrency
- **Resource Chart**: CPU and memory usage vs concurrency
- **Error Rate Chart**: Error rates vs concurrency
- **Combined Chart**: All metrics in one comprehensive view

## Example Workflows

### Basic Performance Test

```bash
# Test a single URL with exponential ramping
bundle exec exe/bench-browsers benchmark \
  --urls https://example.com \
  --ramp exp:1,2,4,8 \
  --reps-per-level 5 \
  --level-min-seconds 30 \
  --out-dir ./performance_test
```

### Load Testing

```bash
# Test multiple URLs with custom concurrency levels
bundle exec exe/bench-browsers benchmark \
  --urls https://api.example.com,https://web.example.com \
  --ramp custom:1,5,10,20,50 \
  --reps-per-level 10 \
  --level-min-seconds 60 \
  --out-dir ./load_test
```

### Quick Development Test

```bash
# Fast test with minimal configuration
bundle exec exe/bench-browsers benchmark \
  --urls http://localhost:3000 \
  --ramp exp:1,2 \
  --reps-per-level 2 \
  --level-min-seconds 5 \
  --out-dir ./dev_test
```

## Viewing Reports

After running a benchmark, explore the generated reports:

```bash
# View summary in terminal
cat ./benchmark_results/summary.md

# Open charts in browser
open ./benchmark_results/latency_chart.html
open ./benchmark_results/combined_chart.html

# View raw data (with jq for pretty printing)
cat ./benchmark_results/metrics.jsonl | jq '.'

# Import CSV into spreadsheet
open ./benchmark_results/metrics.csv
```

## Safety Features

The tool includes several safety mechanisms:

- **Rate Limiting**: Per-domain request rate limiting
- **Concurrent Limits**: Maximum concurrent requests per domain
- **Total Request Limits**: Overall request count limits
- **Robots.txt Respect**: Automatically respects robots.txt files
- **Request Timeouts**: Configurable timeout limits
- **Early Termination**: Stops when performance degrades beyond thresholds

## Advanced Features

### Memory Leak Detection

Real-time memory monitoring with configurable thresholds:

```yaml
memory_leak:
  enabled: true
  threshold_mb: 500
  max_memory_growth_percent: 20
  check_interval_requests: 10
```

### Crawl4ai Integration

Automated web crawling and workload generation:

```yaml
crawl4ai:
  enabled: true
  follow_links: true
  extract_content: true
  respect_robots_txt: true
  max_depth: 3
```

### Distributed Testing

Multi-node testing with load balancing and failover:

```yaml
distributed:
  enabled: true
  nodes:
    - host: node1.example.com
      port: 8080
      weight: 1
    - host: node2.example.com
      port: 8080
      weight: 2
  load_balancing: weighted_round_robin
```

### Custom Workload Scripts

Execute custom Ruby scripts for dynamic workload generation:

```yaml
custom_scripts:
  enabled: true
  script_path: ./scripts/custom_workload.rb
  script_timeout: 30
  allow_external_scripts: false
```

### Browser Mode Options

Choose between context and process modes for optimal performance:

```yaml
browser_mode:
  mode: context # 'context' or 'process'
  context_pool_size: 5
  process_limit: 3
  enable_context_pooling: true
  memory_per_context: 100
```

### Headed Browser Support

Visual debugging and display mode management:

```yaml
headed_browser:
  enabled: true
  display_mode: auto # 'headed', 'headless', 'auto'
  window_size: { width: 1920, height: 1080 }
  viewport_size: { width: 1366, height: 768 }
  screenshot_on_failure: true
  video_recording: false
  mobile_emulation:
    device: iPhone 12
```

## Performance Optimization

- **Adaptive Timing**: Dynamically adjusts wait times between levels
- **Runtime Limits**: Configurable maximum runtime with early termination
- **Efficient Resource Usage**: Optimized memory and CPU usage
- **Fast Test Mode**: Reduced sleep times in test environment

## Comprehensive Feature Set

The Browser Benchmark Tool provides a complete solution for web application performance testing:

### 🎯 **Core Benchmarking**

- Performance testing with multiple ramp strategies
- Real-time metrics collection and analysis
- Comprehensive reporting and visualization
- Safety mechanisms and rate limiting

### 🔍 **Advanced Monitoring**

- Memory leak detection and prevention
- System resource monitoring (CPU, memory, load)
- Performance degradation detection
- Adaptive timing and early termination

### 🌐 **Web Intelligence**

- Automated web crawling and link discovery
- Content extraction and analysis
- Robots.txt compliance and respect
- Dynamic workload generation

### 🚀 **Scalability Features**

- Distributed testing across multiple nodes
- Load balancing and failover
- Health monitoring and performance tracking
- Bottleneck identification and analysis

### 🛠️ **Development Tools**

- Custom workload script execution
- Secure sandboxed environment
- Built-in script templates
- Visual debugging and headed browser support

### 📱 **Testing Capabilities**

- Browser context vs process mode options
- Mobile device emulation
- Accessibility testing support
- Screenshot and video recording

## Development

### Running Tests

The project uses a multi-tier testing strategy to balance thoroughness with execution speed:

#### 🚀 Fast Unit Tests (~1-2 seconds)

```bash
# Run only fast unit tests (default)
bundle exec rspec

# Run specific unit test files
bundle exec rspec spec/browser_benchmark_tool/benchmark_unit_spec.rb
bundle exec rspec spec/browser_benchmark_tool/browser_automation_unit_spec.rb
```

#### 🔧 Component Tests (~5-10 seconds)

```bash
# Run component tests
bundle exec rspec spec/browser_benchmark_tool/test_server_spec.rb
bundle exec rspec spec/browser_benchmark_tool/safety_manager_spec.rb
```

#### 🔗 Integration Tests (~30-60 seconds)

```bash
# Run integration tests
bundle exec rspec spec/browser_benchmark_tool/benchmark_integration_spec.rb
```

#### 📊 Performance Tests (~2-3 minutes)

```bash
# Run performance tests
bundle exec rspec spec/browser_benchmark_tool/benchmark_performance_spec.rb
```

#### 🎯 Test Type Selection

```bash
# Run by test type
bundle exec rspec --tag fast        # Unit tests only
bundle exec rspec --tag component   # Component tests only
bundle exec rspec --tag slow        # Integration tests only
bundle exec rspec --tag performance # Performance tests only

# Run all tests
RUN_ALL_TESTS=1 bundle exec rspec

# Run specific test types
RUN_SLOW_TESTS=1 bundle exec rspec      # Include integration tests
RUN_PERFORMANCE_TESTS=1 bundle exec rspec  # Include performance tests
```

#### 📁 Test File Naming Convention

- `*_unit_spec.rb` - Unit tests with mocked dependencies
- `*_spec.rb` - Component tests (default)
- `*_integration_spec.rb` - Integration tests
- `*_performance_spec.rb` - Performance tests

> 📖 **Detailed Testing Guide**: See [TESTING.md](TESTING.md) for comprehensive testing documentation, troubleshooting, and advanced usage examples.

### Code Quality

```bash
# Run linting
bundle exec rubocop

# Auto-fix linting issues
bundle exec rubocop -a

# Check specific file
bundle exec rubocop lib/browser_benchmark_tool/benchmark.rb
```

### Test Performance

The test suite uses a multi-tier approach for optimal development workflow:

#### 🚀 Development Speed

- **Unit Tests**: ~1-2 seconds (instant feedback)
- **Component Tests**: ~5-10 seconds (component validation)
- **Integration Tests**: ~30-60 seconds (workflow validation)
- **Performance Tests**: ~2-3 minutes (optimization validation)

#### 📊 Test Coverage

- **Total Tests**: 200+ examples across all test types
- **Unit Tests**: 100+ examples (fast, mocked dependencies)
- **Component Tests**: 50+ examples (component validation)
- **Integration Tests**: 30+ examples (real workflows)
- **Performance Tests**: 20+ examples (optimization validation)
- **All tests passing** with comprehensive coverage

#### 🎯 Development Workflow

1. **During Development**: Run unit tests for instant feedback
2. **Before Committing**: Run component tests for integration validation
3. **Before Release**: Run all tests for comprehensive validation
4. **CI/CD Pipeline**: Different test types for different stages

## Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Make your changes
4. Add tests for new functionality
5. Ensure all tests pass (`bundle exec rspec`)
6. Run linting (`bundle exec rubocop`)
7. Commit your changes (`git commit -m 'Add amazing feature'`)
8. Push to the branch (`git push origin feature/amazing-feature`)
9. Submit a pull request

## License

[Add license information here]

## Support

For issues, questions, or contributions, please:

1. Check the existing issues on GitHub
2. Create a new issue with detailed information
3. Include benchmark configuration and error logs
4. Provide system information and Ruby version
