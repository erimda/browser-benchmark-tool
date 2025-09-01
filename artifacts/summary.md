# Browser Benchmark Summary

## Configuration
- **Mode:** simulated
- **Engine:** chromium
- **Headless:** true
- **Ramp Strategy:** exponential
- **Levels:** 1, 2
- **URLs:** https://httpbin.org/get

## Results
- **Maximum Sustainable Concurrency (MSC):** 2
- **Stop Reason:** No degradation detected
- **Total Levels Tested:** 4

## Per-Level Metrics
| Level | Attempted | Successful | Failed | Error Rate | P95 (ms) | CPU % | Memory % |
|-------|-----------|------------|--------|------------|----------|-------|----------|
| 1 | 1 | 1 | 0 | 0.0% | 1541.9 | 50.0% | 60.0% |
| 1 | 1 | 1 | 0 | 0.0% | 534.2 | 50.0% | 60.0% |
| 2 | 2 | 2 | 0 | 0.0% | 526.6 | 50.0% | 60.0% |
| 2 | 2 | 0 | 2 | 100.0% | 0 | 50.0% | 60.0% |

## Thresholds
- **Latency Multiplier:** 2.0× baseline p95
- **CPU Threshold:** 80.0%
- **Memory Threshold:** 80.0%
- **Error Rate Threshold:** 5.0%

## Charts
Interactive charts have been generated:
- [Latency Chart](latency_chart.html) - Shows p50, p95, p99 latency vs concurrency
- [Resource Chart](resource_chart.html) - Shows CPU and memory usage vs concurrency
- [Error Rate Chart](error_rate_chart.html) - Shows error rates vs concurrency
- [Combined Chart](combined_chart.html) - All metrics in one comprehensive view

