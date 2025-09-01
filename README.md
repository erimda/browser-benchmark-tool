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

## Performance Optimization

- **Adaptive Timing**: Dynamically adjusts wait times between levels
- **Runtime Limits**: Configurable maximum runtime with early termination
- **Efficient Resource Usage**: Optimized memory and CPU usage
- **Fast Test Mode**: Reduced sleep times in test environment

## Development

### Running Tests
```bash
# Run all tests
bundle exec rspec

# Run specific test file
bundle exec rspec spec/browser_benchmark_tool/benchmark_spec.rb

# Run tests with progress output
bundle exec rspec --format progress
```

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
The test suite is optimized for fast execution:
- **Before**: ~50 minutes runtime
- **After**: ~3 minutes runtime (94% improvement)
- All tests passing (88 examples, 0 failures, 1 pending)

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
