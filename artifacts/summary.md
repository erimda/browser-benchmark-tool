# Browser Benchmark Summary

## Configuration
- **Mode:** playwright
- **Engine:** chromium
- **Headless:** true
- **Ramp Strategy:** exponential
- **Levels:** 1, 2
- **URLs:** https://httpbin.org/delay/0.5

## Results
- **Maximum Sustainable Concurrency (MSC):** 2
- **Stop Reason:** No degradation detected
- **Total Levels Tested:** 2

## Per-Level Metrics
| Level | Attempted | Successful | Failed | Error Rate | P95 (ms) | CPU % | Memory % |
|-------|-----------|------------|--------|------------|----------|-------|----------|
| 1 | 2 | 2 | 0 | 0.0% | 2667.7 | 44.2% | 38.7% |
| 2 | 4 | 4 | 0 | 0.0% | 2429.0 | 30.3% | 53.1% |

## Thresholds
- **Latency Multiplier:** 2.0× baseline p95
- **CPU Threshold:** 90.0%
- **Memory Threshold:** 80.0%
- **Error Rate Threshold:** 1.0%

## Charts
Interactive charts have been generated:
- [Latency Chart](latency_chart.html) - Shows p50, p95, p99 latency vs concurrency
- [Resource Chart](resource_chart.html) - Shows CPU and memory usage vs concurrency
- [Error Rate Chart](error_rate_chart.html) - Shows error rates vs concurrency
- [Combined Chart](combined_chart.html) - All metrics in one comprehensive view

