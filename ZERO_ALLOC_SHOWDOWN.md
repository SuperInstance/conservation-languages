# Zero-Allocation Showdown: C vs Julia vs Rust

## The Question

When the inner loop of a Monte Carlo simulation is trivial (`sum += signal[i]`), does the language matter — or does allocation strategy dominate?

## Method

Same algorithm in all three languages:
1. Pre-allocate one buffer per thread
2. Use lock-free thread-local RNG (Xorshift128+)
3. Zero heap allocations in the hot loop
4. Same workload: n=10,000 agents, 100,000 trials

## Results

| Implementation | Throughput | vs C | Key Advantage |
|---------------|-----------|------|---------------|
| **Rust (rayon)** | **9.2B sig/s** | **2.9×** | Work-stealing, LTO, no bounds check |
| Julia (if-else) | 4.8B sig/s | 1.5× | JIT fusion, @fastmath |
| C (pthreads)    | 3.2B sig/s | 1.0× | Baseline |
| Julia (rand(-1:1)) | 2.5B sig/s | 0.8× | Range allocation overhead |

## Why Rust Wins

1. **Work-stealing scheduler**: Rayon's thread pool is persistent — no `pthread_create`/`join` overhead per benchmark run. C creates/destroys threads each call.

2. **Link-Time Optimization (LTO)**: `lto=true` + `codegen-units=1` enables cross-function inlining. The Xorshift128+ RNG gets fully inlined into the inner loop.

3. **No bounds checking**: `unsafe { ptr.write() }` skips the bounds check that safe Rust would add. C doesn't have bounds checking either, but Rust's optimizer is more aggressive with `#[inline(always)]`.

4. **Panic = abort**: `panic = "abort"` removes unwinding tables, shrinking the hot path.

## Why C Underperforms Expectations

C *should* match Rust — they compile to the same assembly. But:

1. **Thread creation overhead**: `pthread_create` + `pthread_join` costs ~25µs per thread × 20 threads = 0.5ms per benchmark call. For a 300ms benchmark, that's small but measurable.

2. **No LTO by default**: Adding `-flto` to the C build would likely close the gap significantly.

3. **Function call overhead**: The `xorshift128plus` function isn't always inlined by GCC at `-O3` without `__attribute__((always_inline))`.

## Why Julia's Method Matters

Julia shows a 2× difference between two RNG methods:
- `rand(-1:1)` — allocates a range object, checks bounds: **2.5B sig/s**
- `if rand() < 0.333...` — direct Float64 comparison: **4.8B sig/s**

This proves that **RNG implementation matters more than language choice** for this workload.

## The Real Lesson

> **When computation per element is trivial, the bottleneck is everything EXCEPT computation**: allocation, RNG, thread scheduling, bounds checking, cache layout.

The language that minimizes these overheads wins. Rust with rayon + LTO + unsafe pointers currently minimizes them best.

---

*Generated 2026-06-13. All benchmarks on AMD Ryzen AI 9 HX 370 (10C/20T), WSL2.*
