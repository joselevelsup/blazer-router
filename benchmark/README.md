# HTTP Router Benchmark

Compares two HTTP routers (e.g. pattern-matching vs. a custom router) under
real HTTP load, using a methodology designed to separate genuine performance
differences from ordinary machine noise.

## What this measures

Given two running HTTP servers — identical in every way except for the
router implementation — this benchmark:

- Sends a realistic mix of request paths (static, param, nested, 404) to
  each server using [`wrk`](https://github.com/wg/wrk)
- Runs at several concurrency levels (10, 50, 100, 500 connections) to see
  how each router behaves under light and heavy load
- Repeats each (router, concurrency) combination multiple times, in
  randomized, interleaved order, so no single run's noise (a GC pause, a
  background process, thermal throttling) can bias the result toward one
  router
- Reports mean, median, standard deviation, min, and max — not just a
  single number — plus a rough statistical comparison per concurrency
  level, so you can tell whether an observed gap is a real difference or
  just noise

## Files

| File | Purpose |
|---|---|
| `benchmark.sh` | Main script — runs the benchmark and writes a results log |
| `paths.lua` | `wrk` script defining the mix of request paths to test |
| `results_<timestamp>.log` | Generated after each run — raw `wrk` output plus summary stats |

## Requirements

- **`wrk`** — HTTP load generator the script drives (required)

## Setup

1. Have both routers running as separate HTTP servers, each on its own
   port (e.g. `http://localhost:8080` and `http://localhost:8081`).
2. Make sure `benchmark.sh` and `paths.lua` are in the same directory.
3. Edit `paths.lua` if you want to test a different set of routes — by
   default it includes a static route, single-param, nested-param, a
   static file path, and one intentional 404. Match this to your actual
   route table for realistic results.
4. Make the script executable (one-time):
   ```bash
   chmod +x benchmark.sh
   ```

## Running the benchmark

Basic run (5 reps per concurrency level, 20s per run, 4 threads):
```bash
./benchmark.sh http://localhost:8080 http://localhost:8081
```

Custom reps / duration / threads:
```bash
./benchmark.sh http://localhost:8080 http://localhost:8081 5 20s 4
```
Arguments, in order: router A URL, router B URL, reps per combo, duration
per run, thread count.


## Reading the results

The script prints progress live and saves everything to
`results_<timestamp>.log`, including:

- **Raw `wrk` output** for every single run, for full detail
- **A summary table** per concurrency level: N, mean, median, stdev, min,
  max for each router
- **A head-to-head verdict** per concurrency level using a rough Welch's-t
  comparison:
  - `|t| > 2` → labeled "likely faster" for whichever router has the
    higher mean
  - `|t| <= 2` → labeled "no clear difference (within noise)"

This is a heuristic, not a rigorous p-value — treat borderline results
(t close to 2) with skepticism, especially with the default of 5 reps.
If a result matters, increase reps and see if the verdict holds.

### What "no clear difference" means

If most or all concurrency levels come back "no clear difference," and any
"likely faster" verdicts don't point the same direction consistently, the
honest conclusion is that the two routers perform equivalently at the
route-table size and concurrency levels you tested — not that one has a
hidden edge the test failed to catch.

### Before trusting the numbers

Check the `Non-2xx or 3xx responses` count in the raw output against what
you'd expect from `paths.lua`. If it's higher than expected, some routes
may not be matching correctly (or aren't implemented) on one or both
servers — errors are often cheaper to serve than real responses and can
skew throughput numbers.

## Notes on interpreting small differences

- At a small route table (a handful of routes), routing cost is likely a
  tiny fraction of total request time compared to socket I/O, parsing, and
  response encoding — so both routers may look nearly identical regardless
  of their actual algorithmic differences.
- If you want to see whether one routing approach scales better than the
  other, the highest-leverage change is to grow the route table (e.g. to
  50-200+ routes) and rerun, rather than adding more reps at the current
  size.
- Differences under ~3% are easy to lose in machine noise even with this
  script's precautions. Treat single-digit percentage gaps cautiously
  unless they're consistent across every concurrency level and hold up
  over multiple full runs of the script.
