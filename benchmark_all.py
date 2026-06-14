#!/usr/bin/env python3
"""
Cross-Language Conservation Law Benchmark Harness
==================================================
Runs all available implementations and produces a comparison table.

Each implementation computes the same thing:
  1. Monte Carlo fleet cancellation for various fleet sizes
  2. Conservation identity γ + η = C
  3. Throughput metric (signals/second)

Usage: python3 benchmark_all.py
"""

import subprocess
import time
import json
import sys
import os
import re
from pathlib import Path

REPO_ROOT = Path(__file__).parent

def run_cmd(cmd, cwd=None, timeout=120, env=None):
    """Run command and capture output."""
    try:
        result = subprocess.run(
            cmd, shell=True, cwd=cwd, timeout=timeout,
            capture_output=True, text=True, env=env
        )
        return result.stdout + result.stderr, result.returncode
    except subprocess.TimeoutExpired:
        return f"TIMEOUT after {timeout}s", -1
    except Exception as e:
        return f"ERROR: {e}", -1

def benchmark_c():
    """C implementation benchmark."""
    repo = REPO_ROOT.parent / "native-conservation-core"
    if not (repo / "conservation_core").exists():
        # Try building
        out, rc = run_cmd("make", cwd=str(repo), timeout=30)
        if rc != 0:
            return None
    out, rc = run_cmd("./conservation_core", cwd=str(repo), timeout=30)
    if rc != 0:
        return None
    return {"language": "C (OpenMP)", "output": out[:500]}

def benchmark_fortran():
    """Fortran implementation benchmark."""
    exe = REPO_ROOT / "fortran" / "conservation"
    if not exe.exists():
        out, rc = run_cmd(
            "gfortran -O3 -fopenmp -ffree-line-length-none -o conservation conservation.f90",
            cwd=str(REPO_ROOT / "fortran"), timeout=30
        )
        if rc != 0:
            return None
    out, rc = run_cmd("./conservation", cwd=str(REPO_ROOT / "fortran"), timeout=60)
    if rc != 0:
        return None
    
    # Parse results
    result = {"language": "Fortran 90 (OpenMP)"}
    for line in out.split('\n'):
        if '1000000' in line and '99' in line:
            result['large_fleet'] = line.strip()
    result["output"] = out[:500]
    return result

def benchmark_r():
    """R implementation benchmark."""
    r_script = REPO_ROOT / "r" / "conservation_law.R"
    if not r_script.exists():
        return None
    out, rc = run_cmd(f"Rscript {r_script}", timeout=60)
    if rc != 0:
        return None
    return {"language": "R", "output": out[:500]}

def benchmark_octave():
    """MATLAB/Octave implementation benchmark."""
    m_script = REPO_ROOT / "matlab" / "conservation_law.m"
    if not m_script.exists():
        return None
    out, rc = run_cmd(f"octave --no-gui --quiet {m_script}", timeout=60)
    if rc != 0:
        return None
    return {"language": "MATLAB/Octave", "output": out[:500]}

def benchmark_d():
    """D implementation benchmark."""
    exe = REPO_ROOT / "dlang" / "conservation"
    if not exe.exists():
        out, rc = run_cmd(
            "ldc2 -O3 -release -mcpu=native conservation.d",
            cwd=str(REPO_ROOT / "dlang"), timeout=30
        )
        if rc != 0:
            return None
    out, rc = run_cmd("./conservation", cwd=str(REPO_ROOT / "dlang"), timeout=60)
    if rc != 0:
        return None
    return {"language": "D (ldc2)", "output": out[:500]}

def benchmark_cobol():
    """COBOL implementation benchmark."""
    exe = REPO_ROOT / "cobol" / "conservation"
    if not exe.exists():
        out, rc = run_cmd(
            "cobc -x -free -o conservation CONSERVATION.cbl",
            cwd=str(REPO_ROOT / "cobol"), timeout=30
        )
        if rc != 0:
            return None
    out, rc = run_cmd("./conservation", cwd=str(REPO_ROOT / "cobol"), timeout=60)
    if rc != 0:
        return None
    return {"language": "COBOL (GnuCOBOL)", "output": out[:500]}

def benchmark_elixir():
    """Elixir implementation benchmark."""
    mix_dir = REPO_ROOT / "elixir"
    if not (mix_dir / "mix.exs").exists():
        return None
    # Compile
    run_cmd("mix compile", cwd=str(mix_dir), timeout=30)
    out, rc = run_cmd("mix run bench/runner.exs", cwd=str(mix_dir), timeout=120)
    if rc != 0:
        return None
    return {"language": "Elixir/OTP (BEAM)", "output": out[:800]}

def benchmark_julia():
    """Julia implementation benchmark."""
    jl_script = REPO_ROOT / "julia" / "conservation.jl"
    if not jl_script.exists():
        return None
    env = os.environ.copy()
    env["JULIA_NUM_THREADS"] = "20"
    env["PATH"] = "/home/phoenix/julia-1.10.4/bin:" + env.get("PATH", "")
    out, rc = run_cmd(
        f"julia {jl_script}",
        timeout=120, env=env
    )
    if rc != 0:
        return None
    return {"language": "Julia (Threads.@threads)", "output": out[:500]}

def benchmark_python_ctypes():
    """Python with C FFI benchmark."""
    # Use the native-conservation-core Python bindings
    py_script = REPO_ROOT.parent / "native-conservation-core" / "python" / "test_conservation.py"
    if py_script.exists():
        out, rc = run_cmd(f"python3 {py_script}", timeout=60)
        if rc == 0:
            return {"language": "Python→C (ctypes FFI)", "output": out[:500]}
    return None

def main():
    print("═" * 70)
    print("  Cross-Language Conservation Law Benchmark")
    print("  γ + η = C  across paradigms and compilers")
    print("═" * 70)
    print()

    benchmarks = [
        ("C", benchmark_c),
        ("Fortran", benchmark_fortran),
        ("D", benchmark_d),
        ("COBOL", benchmark_cobol),
        ("R", benchmark_r),
        ("Octave", benchmark_octave),
        ("Elixir", benchmark_elixir),
        ("Julia", benchmark_julia),
        ("Python→C", benchmark_python_ctypes),
    ]

    results = []
    for name, func in benchmarks:
        print(f"  Running {name}...", end=" ", flush=True)
        t0 = time.time()
        try:
            result = func()
            elapsed = time.time() - t0
            if result:
                print(f"✅ {elapsed:.1f}s")
                result["elapsed"] = elapsed
                results.append(result)
            else:
                print(f"⏭️  skipped (not available)")
        except Exception as e:
            elapsed = time.time() - t0
            print(f"❌ {elapsed:.1f}s ({e})")

    print()
    print("═" * 70)
    print(f"  {len(results)} implementations ran successfully")
    print("═" * 70)
    print()

    # Summary table
    for r in results:
        print(f"\n{'─' * 50}")
        print(f"  {r['language']}")
        print(f"{'─' * 50}")
        # Show last few meaningful lines
        lines = [l for l in r["output"].split('\n') if l.strip()][-10:]
        for line in lines:
            print(f"  {line}")

    # Save results
    output_file = REPO_ROOT / "benchmark_results.json"
    with open(output_file, 'w') as f:
        json.dump(results, f, indent=2)
    print(f"\nResults saved to {output_file}")

if __name__ == "__main__":
    main()
