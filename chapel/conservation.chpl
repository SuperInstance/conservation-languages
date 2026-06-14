#!/usr/bin/env chapel
// ═══════════════════════════════════════════════════════════════
// SuperInstance Conservation Law — Chapel Implementation
// γ + η = C (Shannon chain rule: H(X) = I(X;G) + H(X|G))
//
// Chapel advantages: locale-aware parallelism, data shards
// distributed across nodes, built-in reductions, forall parallelism.
// Designed for Cray supercomputers.
// ═══════════════════════════════════════════════════════════════

config const nAgents = 10000;
config const nTrials = 10000;
config const verbose = true;

use Math;

// ─── Core Types ──────────────────────────────────────────────

record TernarySignal {
  var valence: int(8);  // -1, 0, +1
}

record ConservationState {
  var gamma: real;
  var eta: real;
  var C: real;
}

const LOG2_3 = log(3.0) / log(2.0);

// ─── Core Functions ─────────────────────────────────────────

proc conservation_delta(n: int): real {
  if n < 2 then return 1.0;
  return (1.0 / sqrt(n: real)) * (1.0 - 3.0 / (2.0 * n));
}

proc conservation_efficiency(n: int): real {
  return 1.0 - conservation_delta(n);
}

proc randomTernary(): int(8) {
  var r = rand_real();
  if r < 0.333333 then return -1;
  else if r < 0.666667 then return 0;
  else return 1;
}

// ─── Fleet Cancellation ─────────────────────────────────────

proc fleetCancellation(signals: [] int(8)): real {
  const n = signals.size;
  if n == 0 then return 0.0;
  
  var s: int = + reduce signals;
  return 1.0 - abs(s: real) / n: real;
}

// ─── Monte Carlo (Parallel with forall) ─────────────────────

proc monteCarloCancellation(nAgents: int, nTrials: int): real {
  var totalCancel: [0..here.maxTaskPar-1] real;
  
  coforall tid in 0..#here.maxTaskPar {
    var localSum = 0.0;
    var trialsPerTask = nTrials / here.maxTaskPar;
    var startTrial = tid * trialsPerTask;
    var endTrial = if tid == here.maxTaskPar-1 then nTrials
                   else (tid+1) * trialsPerTask;
    
    for t in startTrial..endTrial-1 {
      var signals: [0..#nAgents] int(8);
      for i in 0..#nAgents {
        signals[i] = randomTernary();
      }
      localSum += fleetCancellation(signals);
    }
    totalCancel[tid] = localSum;
  }
  
  return + reduce totalCancel / nTrials;
}

// ─── Conservation Entropy ───────────────────────────────────

proc ternaryEntropy(signals: [] int(8)): real {
  const n = signals.size;
  if n == 0 then return 0.0;
  
  var cnt_neg = + reduce [s in signals] (s == -1): int;
  var cnt_zero = + reduce [s in signals] (s == 0): int;
  var cnt_pos = + reduce [s in signals] (s == 1): int;
  
  var H = 0.0;
  for cnt in (cnt_neg, cnt_zero, cnt_pos) {
    var p = cnt: real / n: real;
    if p > 0.0 {
      H -= p * log(p) / log(2.0);
    }
  }
  return H;
}

// ─── Ternary Dot Product ────────────────────────────────────

proc ternaryDotProduct(a: [] int(8), b: [] int(8)): int {
  return + reduce [i in a.domain] a[i] * b[i];
}

// ─── Ternary Matrix Multiply ────────────────────────────────

proc ternaryMatmul(A: [] int(8), B: [] int(8), M: int, K: int, N: int): [] int {
  var C: [{0..#M, 0..#N}] int;
  
  forall (i, j) in {0..#M, 0..#N} {
    var s = 0;
    for k in 0..#K {
      s += A[i, k] * B[k, j];
    }
    C[i, j] = s;
  }
  return C;
}

// ─── Haar Wavelet ───────────────────────────────────────────

proc haarDecompose(signal: [] int(8)): (any, any) {
  const n = signal.size;
  const half = n / 2;
  var approx: [{0..#half}] real;
  var detail: [{0..#half}] real;
  const invSqrt2 = 1.0 / sqrt(2.0);
  
  forall i in 0..#half {
    approx[i] = (signal[2*i]: real + signal[2*i+1]: real) * invSqrt2;
    detail[i] = (signal[2*i]: real - signal[2*i+1]: real) * invSqrt2;
  }
  
  return (approx, detail);
}

// ─── Main ───────────────────────────────────────────────────

proc main() {
  writeln("═══ SuperInstance Conservation Law — Chapel ═══");
  writeln("Locales: ", Locales.size);
  writeln("Tasks/locale: ", here.maxTaskPar);
  writeln();

  writeln("─── Monte Carlo Fleet Cancellation ───");
  var sizes = [5, 10, 50, 100, 500, 1000, 5000, 10000];
  
  for n in sizes {
    var trials = if n > 5000 then 100 else nTrials;
    var t0 = time();
    var mc = monteCarloCancellation(n, trials);
    var t1 = time();
    
    var theory = conservationEfficiency(n);
    var err = abs(mc - theory) / theory * 100.0;
    
    writef("  n=%-6d  cancel=%.4d  theory=%.4d  error=%.2d%%  time=%.3drs\n",
           n, mc, theory, err, t1 - t0);
  }
  
  // Conservation identity
  writeln();
  writeln("─── Conservation Identity γ + η = C ───");
  var G: [{0..#nAgents}] int(8);
  for i in 0..#nAgents do G[i] = randomTernary();
  var X: [{0..#nAgents}] int(8);
  for i in 0..#nAgents {
    X[i] = if rand_real() < 0.5 then G[i] else randomTernary();
  }
  
  var C_val = ternaryEntropy(X);
  var H_G = ternaryEntropy(G);
  var joint: [0..2, 0..2] int;
  for i in 0..#nAgents {
    joint[X[i]+1, G[i]+1] += 1;
  }
  var H_XG = 0.0;
  for xi in 0..2 {
    for gi in 0..2 {
      var p = joint[xi, gi]: real / nAgents: real;
      if p > 0.0 {
        H_XG -= p * log(p) / log(2.0);
      }
    }
  }
  var eta = max(0.0, H_XG - H_G);
  var gamma = max(0.0, C_val - eta);
  
  writef("  γ = %.6r bits\n", gamma);
  writef("  η = %.6r bits\n", eta);
  writef("  C = %.6r bits\n", C_val);
  writef("  γ + η = %.6r bits\n", gamma + eta);
  writef("  H_max = %.6r bits\n", LOG2_3);
  
  writeln();
  writeln("═══ Chapel Complete ═══");
}
