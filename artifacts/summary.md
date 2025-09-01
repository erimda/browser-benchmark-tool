# Browser Benchmark Summary

## Configuration
- **Mode:** playwright
- **Engine:** chromium
- **Headless:** true
- **Ramp Strategy:** exp:1,2
- **Levels:** 1, 2, 4, 8, 16, 32
- **URLs:** https://httpbin.org/delay/0.5

## Results
- **Maximum Sustainable Concurrency (MSC):** 32
- **Stop Reason:** No degradation detected
- **Total Levels Tested:** 12

## Per-Level Metrics
| Level | Attempted | Successful | Failed | Error Rate | P95 (ms) | CPU % | Memory % |
|-------|-----------|------------|--------|------------|----------|-------|----------|
| 1 | 1 | 1 | 0 | 0.0% | 1381.1 | 45.8% | 54.0% |
| 1 | 1 | 1 | 0 | 0.0% | 531.9 | 24.8% | 42.4% |
| 2 | 1 | 1 | 0 | 0.0% | 816.7 | 43.9% | 47.7% |
| 2 | 1 | 1 | 0 | 0.0% | 736.3 | 39.8% | 41.8% |
| 4 | 1 | 1 | 0 | 0.0% | 461.3 | 36.0% | 55.0% |
| 4 | 1 | 1 | 0 | 0.0% | 604.2 | 26.6% | 54.2% |
| 8 | 1 | 1 | 0 | 0.0% | 617.9 | 21.5% | 40.7% |
| 8 | 1 | 1 | 0 | 0.0% | 725.2 | 28.6% | 42.6% |
| 16 | 1 | 1 | 0 | 0.0% | 597.1 | 35.1% | 46.5% |
| 16 | 1 | 1 | 0 | 0.0% | 846.0 | 32.1% | 49.2% |
| 32 | 1 | 1 | 0 | 0.0% | 682.8 | 20.8% | 48.3% |
| 32 | 1 | 1 | 0 | 0.0% | 790.0 | 32.4% | 43.5% |

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

