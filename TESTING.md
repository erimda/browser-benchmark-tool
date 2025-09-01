# Testing Guide

This project uses a multi-tier testing strategy to balance thoroughness with execution speed.

## Test Types

### 🚀 Unit Tests (Fast - ~1-2 seconds)
- **Purpose**: Test individual components in isolation
- **Dependencies**: Mocked/Stubbed
- **Speed**: Very fast execution
- **Files**: `*_unit_spec.rb`

**What they test:**
- Individual method behavior
- Error handling
- Configuration validation
- Component initialization

**Example:**
```bash
# Run only unit tests
bundle exec rspec spec/browser_benchmark_tool/benchmark_unit_spec.rb
```

### 🔧 Component Tests (Medium - ~5-10 seconds)
- **Purpose**: Test components with real dependencies but no full workflows
- **Dependencies**: Real HTTP, local test server
- **Speed**: Medium execution
- **Files**: `*_spec.rb` (excluding unit/integration/performance)

**What they test:**
- Component integration
- Real HTTP requests
- Local test server functionality
- Safety features

**Example:**
```bash
# Run component tests
bundle exec rspec spec/browser_benchmark_tool/test_server_spec.rb
bundle exec rspec spec/browser_benchmark_tool/safety_manager_spec.rb
```

### 🔗 Integration Tests (Slow - ~30-60 seconds)
- **Purpose**: Test complete workflows end-to-end
- **Dependencies**: Full benchmark execution
- **Speed**: Slow execution
- **Files**: `*_integration_spec.rb`

**What they test:**
- Complete benchmark workflow
- Report generation
- Chart creation
- End-to-end functionality

**Example:**
```bash
# Run integration tests
bundle exec rspec spec/browser_benchmark_tool/benchmark_integration_spec.rb
```

### 📊 Performance Tests (Slowest - ~2-3 minutes)
- **Purpose**: Test actual performance characteristics
- **Dependencies**: Real benchmarks with timing validation
- **Speed**: Slowest execution
- **Files**: `*_performance_spec.rb`

**What they test:**
- Performance optimization
- Early termination
- Resource management
- Timing characteristics

**Example:**
```bash
# Run performance tests
bundle exec rspec spec/browser_benchmark_tool/benchmark_performance_spec.rb
```

## Running Tests

### Default (Fast Tests Only)
```bash
bundle exec rspec
# Runs only unit tests by default
```

### Run Specific Test Types
```bash
# Unit tests only
bundle exec rspec --tag fast

# Component tests only
bundle exec rspec --tag component

# Integration tests only
bundle exec rspec --tag slow

# Performance tests only
bundle exec rspec --tag performance
```

### Environment Variables
```bash
# Run slow tests
RUN_SLOW_TESTS=1 bundle exec rspec

# Run performance tests
RUN_PERFORMANCE_TESTS=1 bundle exec rspec

# Run integration tests
RUN_INTEGRATION_TESTS=1 bundle exec rspec

# Run all tests
RUN_ALL_TESTS=1 bundle exec rspec
```

### Run Specific Files
```bash
# Unit tests
bundle exec rspec spec/browser_benchmark_tool/benchmark_unit_spec.rb

# Component tests
bundle exec rspec spec/browser_benchmark_tool/test_server_spec.rb

# Integration tests
bundle exec rspec spec/browser_benchmark_tool/benchmark_integration_spec.rb

# Performance tests
bundle exec rspec spec/browser_benchmark_tool/benchmark_performance_spec.rb
```

## Test Configuration

### Test Environment
- Tests run with `ENV['RACK_ENV'] = 'test'`
- Simulated mode for faster execution
- Reduced delays and timeouts
- Temporary artifacts directory

### Test Artifacts
- Tests create artifacts in `./artifacts/`
- Automatically cleaned up after test suite
- Includes reports, charts, and metrics

## Development Workflow

### During Development
1. **Start with unit tests** - Fast feedback on component logic
2. **Add component tests** - Verify component integration
3. **Run integration tests** - Ensure end-to-end functionality
4. **Run performance tests** - Validate performance characteristics

### Before Committing
```bash
# Run all tests to ensure nothing is broken
RUN_ALL_TESTS=1 bundle exec rspec

# Or run specific types if you're confident
bundle exec rspec --tag fast,component
```

### CI/CD Pipeline
- Run unit and component tests on every commit
- Run integration tests on pull requests
- Run performance tests on releases

## Test Naming Convention

- `*_unit_spec.rb` - Unit tests with mocked dependencies
- `*_spec.rb` - Component tests (default)
- `*_integration_spec.rb` - Integration tests
- `*_performance_spec.rb` - Performance tests

## Benefits of This Approach

✅ **Fast Development**: Unit tests provide quick feedback  
✅ **Thorough Coverage**: Integration tests catch real issues  
✅ **Performance Validation**: Performance tests ensure optimizations work  
✅ **Flexible Execution**: Run only what you need  
✅ **CI/CD Friendly**: Different test types for different stages  

## Troubleshooting

### Tests Running Too Slow
- Check if you're running performance or integration tests
- Use `--tag fast` to run only unit tests
- Set `RUN_SLOW_TESTS=0` to exclude slow tests

### Missing Dependencies
- Ensure all gems are installed: `bundle install`
- Check if test server ports are available
- Verify network access for external test URLs

### Test Failures
- Check test environment variables
- Ensure test artifacts directory is writable
- Verify component initialization
