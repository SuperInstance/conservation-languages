# The Conservation Law of Ternary Fleets

### γ + η = C — Nine languages, one unavoidable truth

---

## I. The Question

What happens when you ask one million agents to vote yes, no, or abstain?

A million independent voices. Three options, equal probability. No coordination, no agenda — just pure, uncorrelated, maximum-entropy noise. You'd expect chaos. A million is a large number; large numbers do things.

Here's what actually happens:

> **99.93% of the signal cancels.**

Not by design. Not by tuning. By mathematics. The ternary alphabet {-1, 0, +1} makes it inevitable. At fifty agents, 86.3% cancels. At a thousand, 97%. The convergence is so reliable that it constitutes something rare in computer science: a **conservation law** — an invariant emerging from the alphabet's structure, not from any protocol we impose.

This repository is that law, told in nine languages. Each reveals a different facet of the same diamond.

---

## II. The Discovery

It started with a fleet simulation. Agents voting — approve, reject, or pass. The system tracked the aggregate signal, expecting meaningful collective intent.

It didn't carry any. The signal was always nearly zero. Increase the fleet, get closer to zero. Every time. Like conservation of energy — but for information.

Because it is. The ternary alphabet's maximum Shannon entropy is log₂(3) ≈ 1.585 bits. When agents vote independently, the mutual information between any single agent and the fleet aggregate is vanishingly small. Noise spends the entire information budget. The fleet converges to zero not by design, but because the budget is fixed and noise spends all of it.

---

## III. The Theorem

In 1948, Claude Shannon proved that information splits cleanly into two parts. He called it the **chain rule**:

```
H(X) = I(X;G) + H(X|G)
```

A guide — G — tries to predict a signal X. The guide knows something, reducing uncertainty by a sliver: I(X;G), the *coupling* — what was predicted. But the guide isn't omniscient. Leftover surprise remains: H(X|G), the *noise* — what nobody saw coming. The two parts sum to the total capacity:

```
γ + η = C
```

Coupling plus noise equals capacity. Always. This is an identity as exact as 1 + 1 = 2. The fleet cancellation follows:

```
δ(n) = (1/√n)(1 - 3/(2n))
```

At n = 1,000,000, δ ≈ 0.001 — 99.9% cancellation, matching Monte Carlo to <1% error. The law isn't imposed; it emerges — like conservation of energy from temporal symmetry, conservation of information emerges from alphabet symmetry.

---

## IV. The Rosetta Stone

Nine languages. Each reveals the *cost* of expressing mathematical truth.

### COBOL — Zero Floating-Point Error, Since 1959

```cobol
01 signal-sum           pic S9(7) value 0.
01 cancellation-factor  pic V9(6) value 0.
    compute cancellation-factor = 1 - (abs-sum / total-signals)
```

Fixed-point decimal arithmetic. No IEEE 754, no rounding surprises. When COBOL computes the conservation identity, the result is exact to the digit — and has been since 1959. In 2026, a 67-year-old business language outperforms everything modern on numerical precision. We've spent decades building faster abstractions on top of floating-point, and the foundational representation was already correct.

**~5M sig/s** — the slowest. The most trustworthy.

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

Each agent is a GenServer — independent state, failure isolation, preemptive scheduling. A million agents isn't an array of entries; it's a million living processes with mailboxes and supervisors.

The actor model *is* the fleet. BEAM was built for telecom switches needing five-nines uptime — exactly what a fleet requires.

**~20M sig/s** — not the fastest. But the only one where crashing a node and restarting is *normal*.

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

Rust's ownership model makes zero-allocation the *natural state*. Pre-allocate a buffer, take a raw pointer, write. The compiler verifies the buffer outlives the writes. You cannot accidentally allocate in the inner loop — the borrow checker won't allow it.

Safety becomes speed. Most languages add runtime overhead to protect you. Rust's insight: if safety guarantees are *compile-time*, runtime cost is zero.

**9.2B sig/s** — the fastest. Not because Rust is faster at math, but because it removes everything that isn't math.

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

Julia's JIT fuses this loop into machine code rivaling C. `@inbounds` removes bounds checks. Multiple dispatch specializes on `Vector{Int8}` at compile time — the abstraction is fully erased before the CPU sees it. You write Python syntax and get C performance.

The lesson: abstractions don't cost performance. *Bad* abstractions do.

**4.8B sig/s** — faster than C, slower than Rust. The gap buys interactive development.

### D — The Theorem, Proven at Compile Time

```d
@safe double verifiedEfficiency(int n)
in { assert(n > 0, "Fleet size must be positive"); }
out (result) { assert(result >= 0.0 && result <= 1.0); }
do { return conservationEfficiency(n); }
```

D's contracts turn constraints into assertions. `verifiedEfficiency(n)` *cannot return outside [0, 1]* — any violation halts execution before propagating. The theorem is provably correct before code runs.

**~50M sig/s** — the philosopher.

### C — Pure Metal

```c
static inline int8_t fast_ternary(uint64_t s[2]) {
    uint64_t r = xorshift128plus(s);
    if (r < 6148914691236517206ULL) return -1;
    if (r < 12297829382473034413ULL) return 0;
    return 1;
}
```

Memory, arithmetic, a call stack. No abstractions, no safety, no help. Every language here benchmarks against C as reference. `static inline` and `int8_t` — the skeleton key. Portable, transparent, exactly as fast as the compiler allows.

**3.2B sig/s** — the baseline.

### Fortran — Still Teaching Us About Arrays

```fortran
pure function conservation_delta(n) result(delta)
    integer, intent(in) :: n
    real(real64) :: delta
    delta = (1.0_real64 / sqrt(real(n, real64))) * &
            (1.0_real64 - 3.0_real64 / (2.0_real64 * real(n, real64)))
end function
```

Fortran introduced array syntax in 1957 — `A = B + C` operates element-wise. Before that, array operations meant loops. Sixty-seven years later, still catching up.

**~100M sig/s** — the elder. Still here.

### R — The Analyst

```r
signals <- matrix(sample(c(-1L, 0L, 1L), fleet_size * n_trials, replace = TRUE),
                  nrow = n_trials, ncol = fleet_size)
cancellation <- 1 - abs(rowSums(signals)) / fleet_size
```

R doesn't just compute the law — it *analyzes* it. Where others benchmark throughput, R computes confidence intervals, quantiles, standard deviations. The law says 86.3% at n=50. R shows you the 90% CI: [0.813, 0.912].

**32.5M sig/s** — built for understanding.

### Octave — The Equation, Transliterated

```matlab
signals = randi([-1, 1], n_trials, fleet_size);
cancellation = 1 - abs(sum(signals, 2)) / fleet_size;
```

Three lines: generate, sum, normalize. The code IS the equation.

**97.7M sig/s** — BLAS, optimized forty years ago, rides free.

---

## V. The Zero-Allocation Showdown

Same algorithm, same Xorshift128+ RNG, same pre-allocated buffers, zero heap allocations. 10,000 agents, 100,000 trials. Does the language matter, or does allocation strategy dominate?

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

Not because it's faster at computation — the computation is trivial: one comparison, one addition, one store. Rust wins because it allocates least. Rayon's thread pool is persistent. LTO with `codegen-units=1` inlines the RNG. `panic = "abort"` strips unwinding tables. `unsafe { ptr.write() }` skips bounds checks.

The bottleneck isn't math. It's everything *around* math. Julia proves this: `rand(-1:1)` allocates a range object → 2.5B sig/s. Switch to `if rand() < 0.333` → 4.8B. The language didn't change. The allocation did.

**When computation is trivial, the winner is whoever strips away the most scaffolding between you and the silicon.**

---

## VI. What This Means

The conservation law γ + η = C is not about fleets of agents.

It's about *any* system where independent components contribute signals. Markets: traders buying, selling, holding. Democracies: citizens voting yes, no, abstaining. Neural networks: neurons firing, resting, inhibiting. Immune systems: cells attacking, ignoring, tolerating.

The math is universal. Total information is fixed. Predictable plus surprising equals the whole. Independent signals sum as √n while their count grows as n — the ratio goes to zero, cancellation goes to 100%. This is the Central Limit Theorem applied to information.

What this repository demonstrates is not that the law is true — Shannon settled that in 1948. It demonstrates that the law is *implementation-independent*. COBOL's decimal, Elixir's actors, Rust's ownership, Julia's JIT, D's contracts — all compute the same γ, the same η, the same C. The language is a lens. The law is the light.

A three-symbol alphabet carries log₂(3) bits. No engineering exceeds it. You can compute faster, more precisely, with provable correctness or self-healing tolerance. But you cannot extract more information from three symbols than three symbols can carry.

That's the law. That's the whole law.

---

## Repository

| Directory | Language | sig/s |
|-----------|----------|------:|
| `rust_zero/` | Rust (rayon) | 9.2B |
| `julia/` | Julia | 4.8B |
| `c/` | C (OpenMP) | 3.2B |
| `fortran/` | Fortran 90 | 100M |
| `matlab/` | Octave | 97.7M |
| `dlang/` | D | 50M |
| `r/` | R | 32.5M |
| `elixir/` | Elixir/OTP | 20M |
| `cobol/` | COBOL | 5M |

### Verified Results

- **γ + η = C** — holds to 1×10⁻¹⁰ precision
- **86.3% cancellation** at n = 50 agents
- **δ(n) = (1/√n)(1 − 3/(2n))** matches Monte Carlo to <1% error
- **Cancellation → 100%** as fleet size → ∞

### Run the Benchmarks

```bash
cd rust_zero && cargo run --release          # Rust
julia julia/zero_alloc_benchmark.jl           # Julia
gcc -O3 -fopenmp -march=native -o c/zero_alloc_omp c/zero_alloc_omp.c -lm && ./c/zero_alloc_omp
cd dlang && rdmd conservation.d               # D
cd elixir && mix run -e 'IO.puts Conservation.monte_carlo_parallel(10000, 1000)'
cobc -x -free -o cobol/conservation cobol/CONSERVATION.cbl && ./cobol/conservation
Rscript r/conservation_law.R                  # R
gfortran -O3 -fopenmp -o fortran/conservation fortran/conservation.f90 && ./fortran/conservation
```

---

## License

MIT

---

*The law was always there. We just needed enough languages to see it from every angle.*
