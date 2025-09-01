# Browser Benchmark Summary

## Configuration
- **Mode:** playwright
- **Engine:** chromium
- **Headless:** true
- **Ramp Strategy:** exponential
- **Levels:** 1, 2
- **URLs:** http://localhost:8080/ok

## Results
- **Maximum Sustainable Concurrency (MSC):** 2
- **Stop Reason:** No degradation detected
- **Total Levels Tested:** 4

## Per-Level Metrics
| Level | Attempted | Successful | Failed | Error Rate | P95 (ms) | CPU % | Memory % |
|-------|-----------|------------|--------|------------|----------|-------|----------|
| 1 | 1 | 1 | 0 | 0.0% | 816.1 | 40.0% | 46.7% |
| 1 | 1 | 1 | 0 | 0.0% | 623.8 | 49.9% | 49.7% |
| 2 | 1 | 1 | 0 | 0.0% | 502.3 | 23.9% | 43.4% |
| 2 | 1 | 1 | 0 | 0.0% | 437.6 | 37.4% | 39.2% |

## Thresholds
- **Latency Multiplier:** 2.0× baseline p95
- **CPU Threshold:** 90.0%
- **Memory Threshold:** 80.0%
- **Error Rate Threshold:** 5.0%

## Charts
Interactive charts have been generated:
- [Latency Chart](latency_chart.html) - Shows p50, p95, p99 latency vs concurrency
- [Resource Chart](resource_chart.html) - Shows CPU and memory usage vs concurrency
- [Error Rate Chart](error_rate_chart.html) - Shows error rates vs concurrency
- [Combined Chart](combined_chart.html) - All metrics in one comprehensive view

