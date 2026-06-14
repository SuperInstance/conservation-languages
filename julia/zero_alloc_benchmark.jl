#!/usr/bin/env julia
# ═══════════════════════════════════════════════════════════════
# Zero-Allocation Julia Conservation Benchmark
# Tests whether Julia's 8.1B sig/s result is reproducible
# ═══════════════════════════════════════════════════════════════

using Printf
using Random

function benchmark_zero_alloc(n_agents::Int, n_trials::Int)
    nthreads = Threads.nthreads()
    
    # Pre-allocate per-thread buffers
    buffers = [Vector{Int8}(undef, n_agents) for _ in 1:nthreads]
    sums = zeros(Int64, nthreads)
    cancels = zeros(Float64, nthreads)
    
    trials_per_thread = n_trials ÷ nthreads
    
    t0 = time()
    
    Threads.@threads for tid in 1:nthreads
        buf = buffers[tid]
        local_sum = 0
        local_cancel = 0.0
        
        @inbounds for t in 1:trials_per_thread
            # Generate signals
            s = 0
            @fastmath for i in 1:n_agents
                v = rand(-1:1)
                buf[i] = v
                s += v
            end
            local_cancel += 1.0 - abs(s) / n_agents
        end
        
        cancels[tid] = local_cancel
    end
    
    t1 = time()
    elapsed = t1 - t0
    mean_cancel = sum(cancels) / n_trials
    throughput = Float64(n_agents) * Float64(n_trials) / elapsed / 1e9
    
    @printf("  n=%-8d  trials=%-8d  cancel=%.4f  time=%.4fs  throughput=%.1fB sig/s\n",
            n_agents, n_trials, mean_cancel, elapsed, throughput)
    
    return elapsed
end

# Also test with pre-seeded RNG per thread
function benchmark_fast(n_agents::Int, n_trials::Int)
    nthreads = Threads.nthreads()
    
    # Pre-allocate everything
    buffers = [Vector{Int8}(undef, n_agents) for _ in 1:nthreads]
    cancels = zeros(Float64, nthreads)
    trials_per_thread = n_trials ÷ nthreads
    
    t0 = time()
    
    Threads.@threads for tid in 1:nthreads
        buf = buffers[tid]
        local_cancel = 0.0
        
        @inbounds for t in 1:trials_per_thread
            # Generate ternary signals using bit manipulation
            # rand(Int8) gives random byte, map to ternary
            s = 0
            @fastmath for i in 1:n_agents
                # Use modulo-free ternary generation
                r = rand()
                v = if r < 0.333333
                    -1
                elseif r < 0.666667
                    0
                else
                    1
                end
                buf[i] = v
                s += v
            end
            local_cancel += 1.0 - abs(s) / n_agents
        end
        cancels[tid] = local_cancel
    end
    
    t1 = time()
    elapsed = t1 - t0
    mean_cancel = sum(cancels) / n_trials
    throughput = Float64(n_agents) * Float64(n_trials) / elapsed / 1e9
    
    @printf("  n=%-8d  trials=%-8d  cancel=%.4f  time=%.4fs  throughput=%.1fB sig/s\n",
            n_agents, n_trials, mean_cancel, elapsed, throughput)
    
    return elapsed
end

println("═══════════════════════════════════════════════════════════════")
println("  Julia Zero-Allocation Benchmark (Reproducibility Check)")
println("  Threads: ", Threads.nthreads())
println("═══════════════════════════════════════════════════════════════")
println()

println("─── Method 1: rand(-1:1) ───")
benchmark_zero_alloc(10000, 100000)
println()

println("─── Method 2: if-else rand() ───")
benchmark_fast(10000, 100000)
println()

println("─── Scaling Test (Method 1) ───")
for (n, trials) in [(10, 1_000_000), (100, 1_000_000), (1000, 100_000), (10000, 100_000), (100000, 10_000), (1000000, 100)]
    benchmark_zero_alloc(n, trials)
end

println()
println("═══════════════════════════════════════════════════════════════")
println("  Complete")
println("═══════════════════════════════════════════════════════════════")
