// zero_alloc_benchmark.rs
//
// Rust zero-allocation conservation benchmark.
// Tests same hypothesis: does allocation strategy dominate language choice?
//
// Build: cargo build --release
// Run:   ./target/release/zero_alloc_benchmark

use std::time::Instant;

// Xorshift128+ — same as C version
struct Rng {
    state: [u64; 2],
}

impl Rng {
    fn new(seed: u64) -> Self {
        Rng {
            state: [
                seed.wrapping_mul(0xDEADBEEFCAFEBABE).wrapping_add(42),
                seed.wrapping_mul(0x123456789ABCDEF0).wrapping_add(7),
            ],
        }
    }

    #[inline(always)]
    fn next_u64(&mut self) -> u64 {
        let mut x = self.state[0];
        let y = self.state[1];
        self.state[0] = y;
        x ^= x << 23;
        self.state[1] = x ^ y ^ (x >> 17) ^ (y >> 26);
        self.state[1].wrapping_add(y)
    }

    #[inline(always)]
    fn ternary(&mut self) -> i8 {
        let r = self.next_u64();
        if r < 6148914691236517206 {
            -1
        } else if r < 12297829382473034413 {
            0
        } else {
            1
        }
    }
}

fn benchmark_zero_alloc(n_agents: usize, n_trials: usize) -> (f64, f64) {
    let n_threads = num_cpus::get();
    let trials_per_thread = n_trials / n_threads;

    // Pre-allocate per-thread buffers — aligned, cache-friendly
    let buffers: Vec<Vec<i8>> = (0..n_threads)
        .map(|_| {
            let mut v = Vec::with_capacity(n_agents);
            // Don't need to initialize — we'll write before reading
            unsafe { v.set_len(n_agents); }
            v
        })
        .collect();

    let cancels: std::sync::Mutex<Vec<f64>> = std::sync::Mutex::new(vec![0.0; n_threads]);

    let start = Instant::now();

    std::thread::scope(|s| {
        for (tid, buf) in buffers.iter().enumerate() {
            let cancels = &cancels;
            let buf_ptr = buf.as_ptr() as *mut i8; // Safe within this scope
            
            s.spawn(move || {
                let mut rng = Rng::new(tid as u64);
                let mut local_cancel = 0.0f64;

                for _ in 0..trials_per_thread {
                    let mut sum: i64 = 0;
                    for i in 0..n_agents {
                        let v = rng.ternary();
                        unsafe { *buf_ptr.add(i) = v; }
                        sum += v as i64;
                    }
                    local_cancel += 1.0 - (sum.abs() as f64) / n_agents as f64;
                }

                cancels.lock().unwrap()[tid] = local_cancel;
            });
        }
    });

    let elapsed = start.elapsed();
    let elapsed_s = elapsed.as_secs_f64();

    let c = cancels.into_inner().unwrap();
    let mean_cancel: f64 = c.iter().sum::<f64>() / n_trials as f64;
    let throughput = (n_agents as f64 * n_trials as f64) / elapsed_s / 1e9;

    println!(
        "  n={:<8} trials={:<8} cancel={:.4} time={:.4}s throughput={:.1}B sig/s",
        n_agents, n_trials, mean_cancel, elapsed_s, throughput
    );

    (mean_cancel, elapsed_s)
}

fn main() {
    let n_threads = num_cpus::get();

    println!("═══════════════════════════════════════════════════════════════");
    println!("  Rust Zero-Allocation Benchmark — Xorshift128+ RNG");
    println!("  Threads: {} | Lock-free RNG | Pre-allocated buffers", n_threads);
    println!("═══════════════════════════════════════════════════════════════");
    println!();

    println!("─── Matching Julia Benchmark (n=10K, 100K trials) ───");
    benchmark_zero_alloc(10_000, 100_000);

    println!();
    println!("─── Scaling Test ───");

    let sizes: [(usize, usize); 6] = [
        (10, 1_000_000),
        (100, 1_000_000),
        (1_000, 100_000),
        (10_000, 100_000),
        (100_000, 10_000),
        (1_000_000, 100),
    ];

    for (n, trials) in sizes {
        benchmark_zero_alloc(n, trials);
    }

    println!();
    println!("─── Theory Check ───");
    for n in [10, 100, 1000, 10000, 100000, 1000000] {
        let delta = (1.0 / (n as f64).sqrt()) * (1.0 - 3.0 / (2.0 * n as f64));
        println!("  n={:<8} δ={:.6} efficiency={:.4}", n, delta, 1.0 - delta);
    }

    println!();
    println!("═══════════════════════════════════════════════════════════════");
    println!("  Complete");
    println!("═══════════════════════════════════════════════════════════════");
}
