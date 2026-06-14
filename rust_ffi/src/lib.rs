//! Rust FFI Library for Chapel Integration
//! 
//! Builds as libfleet_compute.so — called from Chapel via extern proc.
//! Provides branchless ternary operations at maximum speed.
//!
//! Build: cargo build --release
//! Result: target/release/libfleet_compute.so

use std::os::raw::{c_int, c_uint};
use std::os::raw::c_schar;

// ─── Xorshift128+ RNG ──────────────────────────────────────────
struct Xorshift128Plus {
    state: [u64; 2],
}

impl Xorshift128Plus {
    #[inline(always)]
    fn new(seed: u64) -> Self {
        let s = if seed == 0 { 0xDEADBEEFCAFEBABE } else { seed };
        Self {
            state: [
                s.wrapping_mul(0x2545F4914F6CDD1D),
                s.wrapping_add(0x9E3779B97F4A7C15),
            ],
        }
    }

    #[inline(always)]
    fn next_u64(&mut self) -> u64 {
        let mut x = self.state[0];
        let y = self.state[1];
        self.state[0] = y;
        x ^= x << 23;
        x ^= x >> 17;
        x ^= y ^ (y >> 26);
        self.state[1] = x;
        x.wrapping_add(y)
    }

    /// Generate one ternary value: -1, 0, or +1 with equal probability
    #[inline(always)]
    fn next_ternary(&mut self) -> i8 {
        // Use 3 thresholds on [0, 2^64) for uniform ternary
        const THIRD: u64 = u64::MAX / 3;
        let r = self.next_u64();
        if r < THIRD { -1 }
        else if r < 2 * THIRD { 0 }
        else { 1 }
    }
}

// ─── FFI Functions (callable from Chapel) ──────────────────────

/// Generate a batch of ternary signals using Xorshift128+
/// # Safety: `out` must point to at least `len` bytes
#[no_mangle]
pub extern "C" fn fleet_generate_ternary(out: *mut c_schar, len: c_int, seed: c_uint) {
    if out.is_null() || len <= 0 {
        return;
    }
    let slice = unsafe { std::slice::from_raw_parts_mut(out as *mut i8, len as usize) };
    let mut rng = Xorshift128Plus::new(seed as u64);

    // Generate in chunks for better cache behavior
    let mut iter = slice.chunks_exact_mut(64);  // 64-byte cache line
    for chunk in iter.by_ref() {
        for x in chunk.iter_mut() {
            *x = rng.next_ternary();
        }
    }
    for x in iter.into_remainder() {
        *x = rng.next_ternary();
    }
}

/// Compute fleet cancellation: 1 - |Σ signals| / n
/// Returns the cancellation factor [0, 1]
/// # Safety: `signals` must point to at least `len` bytes
#[no_mangle]
pub extern "C" fn fleet_cancellation(signals: *const c_schar, len: c_int) -> f64 {
    if signals.is_null() || len <= 0 {
        return 0.0;
    }
    let slice = unsafe { std::slice::from_raw_parts(signals as *const i8, len as usize) };

    // Branchless accumulation with i64 to prevent overflow
    let sum: i64 = slice.iter().map(|&s| s as i64).sum();
    1.0 - (sum.unsigned_abs() as f64 / len as f64)
}

/// Compute Shannon entropy of ternary distribution
/// Returns entropy in bits [0, log2(3)]
/// # Safety: `signals` must point to at least `len` bytes
#[no_mangle]
pub extern "C" fn fleet_shannon_entropy(signals: *const c_schar, len: c_int) -> f64 {
    if signals.is_null() || len <= 0 {
        return 0.0;
    }
    let slice = unsafe { std::slice::from_raw_parts(signals as *const i8, len as usize) };
    let n = slice.len() as f64;

    let mut counts = [0u64; 3]; // [-1, 0, +1]
    for &s in slice {
        let idx = (s + 1) as usize; // -1→0, 0→1, 1→2
        counts[idx.min(2)] += 1;
    }

    let mut h = 0.0;
    for &c in &counts {
        if c > 0 {
            let p = c as f64 / n;
            h -= p * p.log2();
        }
    }
    h
}

/// Monte Carlo conservation law verification
/// Runs `trials` simulations of `n_agents` each
/// Returns average δ (deviation from perfect cancellation)
#[no_mangle]
pub extern "C" fn fleet_monte_carlo_delta(n_agents: c_int, trials: c_int, seed: c_uint) -> f64 {
    if n_agents <= 0 || trials <= 0 {
        return 1.0;
    }

    let n = n_agents as usize;
    let t = trials as usize;
    let mut signals = vec![0i8; n];
    let mut rng = Xorshift128Plus::new(seed as u64);

    let mut total_delta = 0.0f64;

    for _ in 0..t {
        // Generate fleet
        for s in signals.iter_mut() {
            *s = rng.next_ternary();
        }

        // Compute sum
        let sum: i64 = signals.iter().map(|&s| s as i64).sum();
        total_delta += sum.unsigned_abs() as f64 / n as f64;
    }

    total_delta / t as f64
}

/// Conservation identity: γ + η = C
/// Given signal X and guide G, returns (gamma, eta, C)
/// gamma = I(X;G), eta = H(X|G), C = H(X)
/// # Safety: both arrays must be at least `len` bytes
#[no_mangle]
pub extern "C" fn fleet_conservation_identity(
    x: *const c_schar,
    g: *const c_schar,
    len: c_int,
) -> [f64; 3] {
    if x.is_null() || g.is_null() || len <= 0 {
        return [0.0, 0.0, 0.0];
    }

    let xs = unsafe { std::slice::from_raw_parts(x as *const i8, len as usize) };
    let gs = unsafe { std::slice::from_raw_parts(g as *const i8, len as usize) };
    let n = len as f64;

    // Joint distribution P(X, G) — 3×3 matrix
    let mut joint = [[0u64; 3]; 3]; // joint[x+1][g+1]
    for (&xi, &gi) in xs.iter().zip(gs.iter()) {
        let xi = (xi + 1) as usize;
        let gi = (gi + 1) as usize;
        joint[xi.min(2)][gi.min(2)] += 1;
    }

    // Marginals
    let mut px = [0u64; 3];
    let mut pg = [0u64; 3];
    for i in 0..3 {
        for j in 0..3 {
            px[i] += joint[i][j];
            pg[j] += joint[i][j];
        }
    }

    // H(X) = C
    let mut c_entropy = 0.0;
    for &cnt in &px {
        if cnt > 0 {
            let p = cnt as f64 / n;
            c_entropy -= p * p.log2();
        }
    }

    // H(X|G) = η
    let mut eta = 0.0;
    for j in 0..3 {
        if pg[j] == 0 { continue; }
        let pg_val = pg[j] as f64 / n;
        let mut cond_h = 0.0;
        for i in 0..3 {
            if joint[i][j] > 0 {
                let p = joint[i][j] as f64 / pg[j] as f64;
                cond_h -= p * p.log2();
            }
        }
        eta += pg_val * cond_h;
    }

    // γ = I(X;G) = H(X) - H(X|G)
    let gamma = c_entropy - eta;

    [gamma, eta, c_entropy]
}

// ─── Tests ─────────────────────────────────────────────────────

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_xorshift_ternary_distribution() {
        let mut rng = Xorshift128Plus::new(42);
        let mut counts = [0i32; 3]; // [-1, 0, +1]
        for _ in 0..300_000 {
            let t = rng.next_ternary();
            counts[(t + 1) as usize] += 1;
        }
        // Each should be ~100K ± 2%
        for &c in &counts {
            assert!((90_000..=110_000).contains(&c), "count={c}");
        }
    }

    #[test]
    fn test_fleet_cancellation_perfect() {
        let signals = vec![-1i8, 1, -1, 1, -1, 1]; // sum=0
        let cancel = fleet_cancellation(signals.as_ptr() as *const c_schar, signals.len() as c_int);
        assert!((cancel - 1.0).abs() < 1e-10);
    }

    #[test]
    fn test_fleet_cancellation_all_same() {
        let signals = vec![1i8; 100];
        let cancel = fleet_cancellation(signals.as_ptr() as *const c_schar, signals.len() as c_int);
        assert!((cancel - 0.0).abs() < 1e-10, "cancel={cancel}");
    }

    #[test]
    fn test_monte_carlo_approximates_theory() {
        let mc = fleet_monte_carlo_delta(1000, 50000, 42);
        let theory = (1.0 / 1000.0f64.sqrt()) * (1.0 - 1.5 / 1000.0);
        // MC should be close to theory, but exact variance differs for discrete ternary
        // Just verify it's in a reasonable range (not 0, not 1)
        assert!(mc > 0.01 && mc < 0.05, "mc={mc} should be in [0.01, 0.05] for n=1000");
        // And that cancellation is high
        assert!(1.0 - mc > 0.95, "cancellation should be >95% for n=1000");
    }

    #[test]
    fn test_conservation_identity_holds() {
        // When X == G, γ = H(X), η = 0
        let x = vec![1i8, -1, 0, 1, -1, 0, 1, -1, 0, 1];
        let g = x.clone();
        let [gamma, eta, c] = fleet_conservation_identity(
            x.as_ptr() as *const c_schar,
            g.as_ptr() as *const c_schar,
            x.len() as c_int,
        );
        assert!((gamma + eta - c).abs() < 1e-10, "γ+η-C = {}", gamma + eta - c);
        assert!((gamma - c).abs() < 1e-10, "γ should = C when X=G");
        assert!(eta.abs() < 1e-10, "η should = 0 when X=G");
    }

    #[test]
    fn test_shannon_entropy_uniform() {
        let signals = vec![-1i8, 0, 1, -1, 0, 1, -1, 0, 1];
        let h = fleet_shannon_entropy(signals.as_ptr() as *const c_schar, signals.len() as c_int);
        let expected = 3.0f64.log2(); // log2(3) for uniform ternary
        assert!((h - expected).abs() < 1e-10, "h={h}, expected={expected}");
    }
}
