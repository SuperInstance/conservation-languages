#!/usr/bin/env julia
# ═══════════════════════════════════════════════════════════════
# SuperInstance Conservation Law — Julia Implementation
# γ + η = C (Shannon chain rule: H(X) = I(X;G) + H(X|G))
#
# Julia advantages: multiple dispatch, @threads parallelism,
# @inbounds/@fastmath, JIT compilation = C speed with Python syntax
# ═══════════════════════════════════════════════════════════════

module Conservation

export conservation_delta, conservation_efficiency
export fleet_cancellation, monte_carlo_cancellation
export ternary_dotproduct, ternary_matmul
export conservation_entropy, conservation_analyze
export haar_decompose, ternary_signals

const LOG2_3 = log2(3)

"""
    conservation_delta(n::Int) -> Float64

Theoretical cancellation delta: δ(n) = (1/√n)(1 - 3/(2n))
"""
function conservation_delta(n::Int)::Float64
    n < 2 && return 1.0
    return (1.0 / sqrt(n)) * (1.0 - 3.0 / (2.0 * n))
end

"""
    conservation_efficiency(n::Int) -> Float64

Conservation efficiency = 1 - δ(n)
"""
conservation_efficiency(n::Int)::Float64 = 1.0 - conservation_delta(n)

"""
    ternary_signals(n::Int) -> Vector{Int8}

Generate n random ternary signals {-1, 0, +1} with uniform probability.
"""
function ternary_signals(n::Int)::Vector{Int8}
    return Int8[rand([-1, 0, 1]) for _ in 1:n]
end

"""
    ternary_dotproduct(a::Vector{Int8}, b::Vector{Int8}) -> Int64

Branchless ternary dot product.
"""
function ternary_dotproduct(a::Vector{Int8}, b::Vector{Int8})::Int64
    n = length(a)
    s = zero(Int64)
    @inbounds for i in 1:n
        s += a[i] * b[i]
    end
    return s
end

"""
    ternary_matmul(A::Matrix{Int8}, B::Matrix{Int8}) -> Matrix{Int64}

Cache-blocked ternary matrix multiply.
"""
function ternary_matmul(A::Matrix{Int8}, B::Matrix{Int8})::Matrix{Int64}
    M, K = size(A)
    K2, N = size(B)
    @assert K == K2 "Dimension mismatch"
    C = zeros(Int64, M, N)
    
    block = 64  # Cache block size
    @inbounds for ii in 1:block:M
        iend = min(ii + block - 1, M)
        for jj in 1:block:N
            jend = min(jj + block - 1, N)
            for kk in 1:block:K
                kend = min(kk + block - 1, K)
                for i in ii:iend
                    for j in jj:jend
                        s = zero(Int64)
                        @fastmath for k in kk:kend
                            s += A[i,k] * B[k,j]
                        end
                        C[i,j] += s
                    end
                end
            end
        end
    end
    return C
end

"""
    fleet_cancellation(signals::Vector{Int8}) -> Float64

Fleet cancellation factor: 1 - |Σ signals| / n
"""
function fleet_cancellation(signals::Vector{Int8})::Float64
    n = length(signals)
    n == 0 && return 0.0
    s = zero(Int64)
    @inbounds for i in 1:n
        s += signals[i]
    end
    return 1.0 - abs(s) / n
end

"""
    conservation_entropy(signals::Vector{Int8}) -> Float64

Shannon entropy H(X) for ternary distribution {-1, 0, +1}.
Maximum: log₂(3) ≈ 1.585 bits.
"""
function conservation_entropy(signals::Vector{Int8})::Float64
    n = length(signals)
    n == 0 && return 0.0
    
    cnt_neg = cnt_zero = cnt_pos = 0
    @inbounds for i in 1:n
        if signals[i] == -1; cnt_neg += 1
        elseif signals[i] == 0; cnt_zero += 1
        else; cnt_pos += 1; end
    end
    
    H = 0.0
    for cnt in (cnt_neg, cnt_zero, cnt_pos)
        p = cnt / n
        if p > 0
            H -= p * log2(p)
        end
    end
    return H
end

"""
    conservation_analyze(X::Vector{Int8}, G::Vector{Int8}) -> NamedTuple

Conservation analysis: γ + η = C
Returns (gamma=I(X;G), eta=H(X|G), C=H(X))
"""
function conservation_analyze(X::Vector{Int8}, G::Vector{Int8})
    n = length(X)
    C_val = conservation_entropy(X)
    H_G = conservation_entropy(G)
    
    # Joint entropy H(X, G)
    joint = zeros(Int, 3, 3)
    @inbounds for i in 1:n
        joint[X[i]+2, G[i]+2] += 1
    end
    
    H_XG = 0.0
    for xi in 1:3, gi in 1:3
        p = joint[xi, gi] / n
        if p > 0
            H_XG -= p * log2(p)
        end
    end
    
    eta = max(0.0, H_XG - H_G)
    gamma = max(0.0, C_val - eta)
    
    return (gamma=gamma, eta=eta, C=C_val, H_max=LOG2_3)
end

"""
    monte_carlo_cancellation(n_agents::Int, n_trials::Int) -> Float64

Parallel Monte Carlo fleet cancellation using Threads.@threads.
"""
function monte_carlo_cancellation(n_agents::Int, n_trials::Int)::Float64
    total_cancel = zeros(Float64, Threads.nthreads())
    
    Threads.@threads for t in 1:n_trials
        tid = Threads.threadid()
        signals = Int8[rand([-1, 0, 1]) for _ in 1:n_agents]
        total_cancel[tid] += fleet_cancellation(signals)
    end
    
    return sum(total_cancel) / n_trials
end

"""
    haar_decompose(signal::Vector) -> NamedTuple

Single-level Haar wavelet decomposition.
approximation = (even + odd) / √2
detail = (even - odd) / √2
"""
function haar_decompose(signal)
    n = length(signal)
    half = n ÷ 2
    approx = Vector{Float64}(undef, half)
    detail = Vector{Float64}(undef, half)
    inv_sqrt2 = 1.0 / sqrt(2.0)
    
    @inbounds for i in 1:half
        a = Float64(signal[2i - 1])
        b = Float64(signal[2i])
        approx[i] = (a + b) * inv_sqrt2
        detail[i] = (a - b) * inv_sqrt2
    end
    
    return (approx=approx, detail=detail)
end

end # module

using .Conservation
using Printf
using Random

# ═══ Main Benchmark (run as script) ═══
if abspath(PROGRAM_FILE) == @__FILE__
    println("═══ SuperInstance Conservation Law — Julia ═══")
    println("Julia threads: $(Threads.nthreads())")
    println()
    
    println("─── Monte Carlo Fleet Cancellation ───")
    sizes = [5, 10, 50, 100, 500, 1000, 5000, 10000]
    @printf("%-8s %-12s %-12s %-8s %-10s\n", "Fleet", "Empirical", "Theory", "Error%", "Time(ms)")
    println(repeat("-", 55))
    
    for n in sizes
        t0 = time()
        mc = monte_carlo_cancellation(n, 10000)
        t1 = time()
        
        theo = conservation_efficiency(n)
        err = abs(mc - theo) / theo * 100
        
        @printf("%-8d %-12.4f %-12.4f %-8.2f %-10.1f\n",
                n, mc, theo, err, (t1-t0)*1000)
    end
    
    # Conservation identity
    println()
    println("─── Conservation Identity γ + η = C ───")
    Random.seed!(42)
    G = ternary_signals(10000)
    X = Int8[g == 1 && rand() < 0.5 ? 1 : rand([-1, 0, 1]) for (i, g) in enumerate(G)]
    tc = conservation_analyze(X, G)
    @printf("γ = %.6f bits\n", tc.gamma)
    @printf("η = %.6f bits\n", tc.eta)
    @printf("C = %.6f bits\n", tc.C)
    @printf("γ + η = %.6f ≈ C = %.6f %s\n", 
            tc.gamma + tc.eta, tc.C,
            abs(tc.gamma + tc.eta - tc.C) < 1e-10 ? "✓" : "✗")
    
    # Stress test
    println()
    println("─── Stress Test: 1,000,000 agents ───")
    t0 = time()
    mc = monte_carlo_cancellation(1_000_000, 10)
    t1 = time()
    @printf("Cancellation: %.4f%% in %.3fs\n", mc * 100, t1 - t0)
    
    println()
    println("═══ Julia Complete ═══")
end
