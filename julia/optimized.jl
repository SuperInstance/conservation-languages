#!/usr/bin/env julia
# ═══════════════════════════════════════════════════════════════
# Optimized Julia — zero-allocation Monte Carlo
# Tests how close Julia gets to Rust when allocation is eliminated
# ═══════════════════════════════════════════════════════════════

using Printf
using Random
using Base.Threads

function optimized_mc_cancel(n_agents::Int, n_trials::Int)
    # Pre-allocate buffers per thread (zero allocation in hot path)
    buffers = [Vector{Int8}(undef, n_agents) for _ in 1:nthreads()]
    totals = zeros(Float64, nthreads())
    
    @threads for t in 1:n_trials
        tid = threadid()
        buf = buffers[tid]
        
        # Fill buffer in-place (no allocation)
        @inbounds for i in 1:n_agents
            r = rand()
            buf[i] = if r < 0.333333
                Int8(-1)
            elseif r < 0.666667
                Int8(0)
            else
                Int8(1)
            end
        end
        
        # Compute cancellation (no allocation)
        s = zero(Int64)
        @inbounds for i in 1:n_agents
            s += buf[i]
        end
        totals[tid] += 1.0 - abs(s) / n_agents
    end
    
    return sum(totals) / n_trials
end

function main()
    println("═══ Julia Zero-Allocation Benchmark ═══")
    println("Threads: $(nthreads())")
    println()
    
    # Warmup (JIT)
    optimized_mc_cancel(100, 10)
    
    println("─── Zero-Allocation Monte Carlo ───")
    @printf("%-10s %-12s %-12s %-8s %-12s\n", "Fleet", "Measured", "Theory", "Err%", "Throughput")
    println("-"^58)
    
    for n in [100, 1000, 10000, 100000, 1000000]
        trials = n > 100000 ? 10 : (n > 10000 ? 100 : 10000)
        
        t0 = time()
        mc = optimized_mc_cancel(n, trials)
        elapsed = time() - t0
        
        theory = 1.0 - (1.0/sqrt(n)) * (1.0 - 3.0/(2.0*n))
        err = abs(mc - theory) / theory * 100
        thru = n * trials / elapsed / 1e6
        
        @printf("%-10d %-12.4f %-12.4f %-8.2f %-12.1f Msig/s\n", n, mc, theory, err, thru)
    end
    
    println()
    println("═══ Complete ═══")
end

main()
