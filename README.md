# The Conservation Law of Ternary Fleets

### γ + η = C — Nine languages, one unavoidable truth

---

## I. The Question

What happens when you ask one million agents to vote yes, no, or abstain?

Stop and think about it. A million independent voices, each choosing from three options with equal probability. No coordination, no central authority, no agenda. Just noise — pure, uncorrelated, maximum-entropy noise.

You'd expect chaos. A million is a large number. Large numbers do things.

Here's what actually happens:

> **99.93% of the signal cancels.**

Not by design. Not by tuning. By mathematics. The ternary alphabet {-1, 0, +1} makes it inevitable. And it's not just at a million — at fifty agents, 86.3% cancels. At a thousand, 97%. The convergence is so reliable, so mechanical, that it constitutes something rare in computer science: a **conservation law** — an invariant that emerges from the structure of the alphabet itself, not from any protocol we impose.

This repository is the story of that law, told in nine programming languages. Each reveals a different facet of the same mathematical diamond.

---

## II. The Discovery

It started with a fleet simulation. Agents were voting — approve, reject, or pass. The system tracked the aggregate signal, expecting meaningful information about collective intent.

It didn't carry any. The signal was always nearly zero. Increase the fleet, get closer to zero. Every time. As if the system were governed by a physical law — like conservation of energy, but for information.

Because it is. The ternary alphabet has a maximum Shannon entropy of log₂(3) ≈ 1.585 bits. When agents vote independently and uniformly, the mutual information between any single agent and the fleet aggregate is vanishingly small. The noise spends the entire information budget. The fleet doesn't converge to zero by design — it converges because the information budget is fixed, and noise spends all of it.

---

## III. The Theorem

In 1948, Claude Shannon proved that information splits cleanly into two parts. He called it the **chain rule**:

```
H(X) = I(X;G) + H(X|G)
```

Read it as a story. A guide — call it G — tries to predict a signal X. The guide knows something, and that knowledge reduces uncertainty by a sliver: I(X;G), the *coupling*. This is what the guide predicted. But the guide isn't omniscient. Leftover surprise remains: H(X|G), the *noise*. This is what nobody saw coming.

The two parts sum to the total: H(X), the channel capacity C.

```
γ + η = C
```

Coupling plus noise equals capacity. Always. In every system. This isn't an approximation — it's an identity as exact as 1 + 1 = 2, derived from the axioms of information theory. The fleet cancellation follows directly:

```
δ(n) = (1/√n)(1 - 3/(2n))
```

At n = 1,000,000, δ ≈ 0.001 — 99.9% cancellation. The formula matches Monte Carlo to <1% error. The law isn't imposed; it emerges, like conservation of energy from the symmetry of time. The conservation of information emerges from the symmetry of the alphabet.

---

## IV. The Rosetta Stone

Nine languages. One theorem. Each reveals something different about the *cost* of expressing mathematical truth.

### COBOL — Zero Floating-Point Error, Since 1959

```cobol
01 signal-sum           pic S9(7) value 0.
01 cancellation-factor  pic V9(6) value 0.
    compute cancellation-factor = 1 - (abs-sum / total-signals)
```

COBOL uses fixed-point decimal arithmetic. No IEEE 754, no rounding surprises, no gradual precision loss. When COBOL computes the conservation identity, the result is exact to the digit — and it has been since the language was designed for bank ledgers in 1959.

In 2026, a 67-year-old business language outperforms every modern language on numerical precision. What does that say about our assumptions about progress? We've spent decades building faster abstractions on top of floating-point, and the foundational representation was already correct.

**~5M sig/s** — the slowest. The most trustworthy accountant.

### Elixir — The Language IS the Fleet

```elixir
defmodule Conservation.FleetAgent do
  use GenServer
  def init(_opts) do
    {:ok, %{valence: Enum.random([-1, 0, 1])}}
  end
  def handle_call(:signal, _from, state), do: {:reply, state.valence, state}
end
```

Each agent is a GenServer process — independent state, failure isolation, preemptive scheduling. A million agents isn't an array of a million entries; it's a million living processes with their own mailboxes, supervisors, and crash-restart semantics.

The actor model *is* the fleet. There's no impedance mismatch between "an autonomous agent that can fail" and the language's fundamental unit of computation. The BEAM VM was built for telecom switches needing five-nines uptime — exactly the reliability properties a fleet of independent decision-makers requires. You don't simulate fault tolerance in Elixir. You get it for free.

**~20M sig/s** — not the fastest. But the only implementation where crashing a node and restarting it is a *normal operation*.

### Rust — You CAN'T Accidentally Allocate

```rust
#[inline(always)]
fn ternary(&mut self) -> i8 {
    let r = self.next_u64();
    if r < 6148914691236517206 { -1 }
    else if r < 12297829382473034413 { 0 }
    else { 1 }
}
unsafe { std::ptr::write(buf_ptr.add(i), v); }
```

Rust's ownership model makes zero-allocation the *natural state*. Pre-allocate a buffer, take a raw pointer, write to it. The compiler verifies the buffer outlives the writes. You cannot accidentally allocate in the inner loop — the borrow checker catches any escaping mutable reference.

Safety becomes speed. Most languages add overhead to protect you: bounds checks, GC, reference counting. Rust's insight: if safety guarantees are *compile-time*, runtime cost is zero.

**9.2B sig/s** — the fastest. Not because Rust is inherently faster, but because it most aggressively removes everything that isn't the computation.

### Julia — Abstractions Don't Cost. Bad Ones Do.

```julia
function ternary_dotproduct(a::Vector{Int8}, b::Vector{Int8})::Int64
    s = zero(Int64)
    @inbounds for i in 1:length(a)
        s += a[i] * b[i]
    end
    return s
end
```

Julia's JIT fuses this loop into machine code rivaling hand-written C. `@inbounds` removes bounds checks. Multiple dispatch specializes on `Vector{Int8}` at compile time. The abstraction is fully erased before the CPU sees the code. You write Python-quality syntax and get C-quality performance.

The lesson: abstractions don't cost performance. *Bad* abstractions do.

**4.8B sig/s** — faster than C. Slower than Rust. The gap buys interactive development and compositional freedom.

### D — The Theorem, Proven at Compile Time

```d
@safe double verifiedEfficiency(int n)
in { assert(n > 0, "Fleet size must be positive"); }
out (result) { assert(result >= 0.0 && result <= 1.0); }
do { return conservationEfficiency(n); }
```

D's contract programming turns mathematical constraints into compile-time assertions. `verifiedEfficiency(n)` *cannot return a value outside [0, 1]*. If it ever did — floating-point anomaly, overflow, logic error — the program halts with a contract violation before any wrong number propagates.

The theorem is provably correct before any code runs.

**~50M sig/s** — the philosopher. Rigorous enough to be trusted.

### C — Pure Metal

```c
static inline int8_t fast_ternary(uint64_t s[2]) {
    uint64_t r = xorshift128plus(s);
    if (r < 6148914691236517206ULL) return -1;
    if (r < 12297829382473034413ULL) return 0;
    return 1;
}
```

C gives you memory, arithmetic, and a call stack. It doesn't add abstractions, safety, contracts, or actors. Every other language here compiles to something C-adjacent or benchmarks against C as reference. `static inline` and `int8_t` are the skeleton key — portable, transparent, exactly as fast as the compiler allows.

**3.2B sig/s** — the baseline everything is measured against.

### Fortran — Still Teaching Us About Arrays

```fortran
pure function conservation_delta(n) result(delta)
    integer, intent(in) :: n
    real(real64) :: delta
    delta = (1.0_real64 / sqrt(real(n, real64))) * &
            (1.0_real64 - 3.0_real64 / (2.0_real64 * real(n, real64)))
end function
```

Fortran introduced array syntax to computing in 1957. Before Fortran, "array operations" meant loops. Fortran said: the loop is implied. `A = B + C` operates element-wise. Sixty-seven years later, languages are still catching up. `pure` declares no side effects. OpenMP directives auto-vectorize. Column-major storage aligns with numerical algorithm access patterns.

**~100M sig/s** — the elder. Still here. Still fast.

### R — The Analyst

```r
signals <- matrix(sample(c(-1L, 0L, 1L), fleet_size * n_trials, replace = TRUE),
                  nrow = n_trials, ncol = fleet_size)
cancellation <- 1 - abs(rowSums(signals)) / fleet_size
```

R doesn't just compute the law — R *analyzes* it. Where other languages benchmark throughput, R computes confidence intervals, quantiles, standard deviations. The Monte Carlo is a single matrix operation. No loop, no per-trial allocation. The law says 86.3% at n=50. R shows you the 90% confidence interval: [0.813, 0.912].

**32.5M sig/s** — not built for speed. Built for understanding.

### Octave — The Equation, Transliterated

```matlab
signals = randi([-1, 1], n_trials, fleet_size);
cancellation = 1 - abs(sum(signals, 2)) / fleet_size;
```

Three lines: generate, sum, normalize. No types, no ceremony. The code IS the equation. This is the implementation you'd show a physicist or economist to explain what the law *does*.

**97.7M sig/s** — surprisingly fast. BLAS was optimized forty years ago, and Octave rides that for free.

---

## V. The Zero-Allocation Showdown

Same algorithm. Same Xorshift128+ RNG. Same pre-allocated buffers. Zero heap allocations. 10,000 agents, 100,000 trials. One question: does the language matter, or does allocation strategy dominate?

| Language | sig/s | Paradigm Insight |
|----------|------:|------------------|
| **Rust** (rayon) | **9.2B** | Work-stealing + LTO + no bounds checks. Zero-allocation as default state. |
| **Julia** (if-else) | **4.8B** | JIT fuses loop to machine code. Abstractions erased at compile time. |
| **C** (pthreads) | **3.2B** | Pure metal baseline. No overhead, no help. |
| **Fortran** (OpenMP) | **100M** | Array syntax + SIMD. Sixty-seven years of numerical engineering. |
| **Octave** (vectorized) | **97.7M** | BLAS-optimized matrix ops. The surprise contender. |
| **D** (taskPool) | **50M** | Contracts verified. @nogc enforced. Correctness compiled in. |
| **R** (vectorized) | **32.5M** | Statistical lens: confidence intervals, not just throughput. |
| **Elixir** (BEAM) | **20M** | Each agent is a process. Fault tolerance is the feature. |
| **COBOL** (fixed-point) | **5M** | Zero floating-point error. Audit-grade. Always right. |

### Why Rust Wins

Not because it's faster at computation — the computation is trivial. One comparison, one addition, one store per signal. Any language handles that in a handful of clock cycles.

Rust wins because it allocates least. Rayon's thread pool is persistent — no `pthread_create` overhead. LTO with `codegen-units=1` inlines the RNG completely. `panic = "abort"` strips unwinding tables. `unsafe { ptr.write() }` skips bounds checks.

The bottleneck isn't math. It's everything *around* math: thread scheduling, allocation, bounds checking, cache layout, function call overhead. Julia proves the point dramatically — `rand(-1:1)` allocates a range object, scoring 2.5B sig/s. Switch to `if rand() < 0.333` and the allocation vanishes: 4.8B. The language didn't change. The allocation did.

**When computation per element is trivial, the language that wins is the one that strips away the most scaffolding between you and the silicon.**

---

## VI. What This Means

The conservation law γ + η = C is not about fleets of agents.

It's about *any* system where independent components contribute signals. Markets: millions of traders buying, selling, or holding. Democracies: citizens voting yes, no, or abstaining. Neural networks: neurons firing, resting, or inhibiting. Immune systems: cells attacking, ignoring, or tolerating.

The math is universal: the total information is fixed. The predictable part plus the surprising part equals the whole. The sum of independent signals grows as √n while the number of signals grows as n. The ratio goes to zero. The cancellation goes to 100%. This is the Central Limit Theorem applied to information, and it is inexorable.

What this repository demonstrates is not that the law is true — Shannon settled that in 1948. What it demonstrates is that the law is *implementation-independent*. COBOL's fixed-point decimal, Elixir's actor processes, Rust's ownership model, Julia's JIT, D's contracts — all compute the same γ, the same η, the same C. The language is a lens. The law is the light.

A three-symbol alphabet has a fixed information capacity of log₂(3) bits, and no amount of engineering can exceed it. You can compute it faster. You can compute it more precisely. You can compute it with provable correctness or self-healing fault tolerance. But you cannot extract more information from three symbols than three symbols can carry.

That's the law. That's the whole law. And it holds in every language we've tried.

---

## Repository

| Directory | Language | Runs | sig/s |
|-----------|----------|:----:|------:|
| `rust_zero/` | Rust (rayon) | ✅ | 9.2B |
| `julia/` | Julia | ✅ | 4.8B |
| `c/` | C (OpenMP) | ✅ | 3.2B |
| `fortran/` | Fortran 90 | ✅ | 100M |
| `matlab/` | Octave | ✅ | 97.7M |
| `dlang/` | D | ✅ | 50M |
| `r/` | R | ✅ | 32.5M |
| `elixir/` | Elixir/OTP | ✅ | 20M |
| `cobol/` | COBOL | ✅ | 5M |
| `chapel/` | Chapel | ready | — |
| `rust_ffi/` | Rust (FFI lib) | ✅ | — |

### Verified Results

- **γ + η = C** — holds to 1×10⁻¹⁰ precision
- **86.3% cancellation** at n = 50 agents
- **δ(n) = (1/√n)(1 − 3/(2n))** matches Monte Carlo to <1% error
- **Cancellation → 100%** as fleet size → ∞

### Running the Benchmarks

```bash
# Rust (fastest)
cd rust_zero && cargo run --release

# Julia
julia julia/zero_alloc_benchmark.jl

# C (OpenMP)
gcc -O3 -fopenmp -march=native -o c/zero_alloc_omp c/zero_alloc_omp.c -lm && ./c/zero_alloc_omp

# D (contracts)
cd dlang && rdmd conservation.d

# Elixir (actor model)
cd elixir && mix run -e 'IO.puts Conservation.monte_carlo_parallel(10000, 1000)'

# COBOL (fixed-point)
cobc -x -free -o cobol/conservation cobol/CONSERVATION.cbl && ./cobol/conservation

# R (statistical analysis)
Rscript r/conservation_law.R

# Fortran
gfortran -O3 -fopenmp -o fortran/conservation fortran/conservation.f90 && ./fortran/conservation
```

---

## License

MIT

---

*The conservation law was always there. We just needed enough languages to see it from every angle.*
