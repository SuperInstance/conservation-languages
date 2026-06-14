/*
 * zero_alloc_benchmark.c
 *
 * Tests the zero-allocation hypothesis from Julia experiments.
 * Julia hit 8.1B sig/s with pre-allocated per-thread buffers.
 * Can C match or beat it with the same strategy?
 *
 * Hypothesis: when inner loop is trivial (sum += signal[i]),
 * allocation strategy dominates. Language barely matters.
 *
 * Build: gcc -O3 -fopenmp -march=native -o zero_alloc zero_alloc_benchmark.c -lm
 */
#define _GNU_SOURCE
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>
#include <time.h>
#include <pthread.h>
#include <stdint.h>

typedef struct {
    int8_t* signals;
    int n_agents;
    int n_trials;
    int thread_id;
    double local_cancel_sum;
    double elapsed;
} thread_arg_t;

/* Xorshift128+ — lock-free, thread-local RNG */
static inline uint64_t xorshift128plus(uint64_t s[2]) {
    uint64_t x = s[0];
    uint64_t y = s[1];
    s[0] = y;
    x ^= x << 23;
    s[1] = x ^ y ^ (x >> 17) ^ (y >> 26);
    return s[1] + y;
}

static inline int8_t fast_ternary(uint64_t s[2]) {
    uint64_t r = xorshift128plus(s);
    /* UINT64_MAX / 3 ≈ 6148914691236517206 */
    if (r < 6148914691236517206ULL) return -1;
    if (r < 12297829382473034413ULL) return 0;
    return 1;
}

void* worker_thread(void* arg) {
    thread_arg_t* ta = (thread_arg_t*)arg;

    uint64_t s[2] = {
        (uint64_t)ta->thread_id * 0xDEADBEEFCAFEBABEULL + 42,
        (uint64_t)ta->thread_id * 0x123456789ABCDEF0ULL + 7
    };

    int8_t* buf = ta->signals;
    int n = ta->n_agents;
    double cancel_sum = 0.0;

    struct timespec t0, t1;
    clock_gettime(CLOCK_THREAD_CPUTIME_ID, &t0);

    for (int t = 0; t < ta->n_trials; t++) {
        /* Generate + sum in one pass — cache-friendly */
        int sum = 0;
        for (int i = 0; i < n; i++) {
            int8_t val = fast_ternary(s);
            buf[i] = val;
            sum += val;
        }
        cancel_sum += 1.0 - (double)abs(sum) / (double)n;
    }

    clock_gettime(CLOCK_THREAD_CPUTIME_ID, &t1);
    ta->elapsed = (t1.tv_sec - t0.tv_sec) + (t1.tv_nsec - t0.tv_nsec) / 1e9;
    ta->local_cancel_sum = cancel_sum;
    return NULL;
}

double run_benchmark(int n_agents, int n_trials, int n_threads) {
    /* Pre-allocate ONE buffer per thread */
    int8_t** buffers = malloc(n_threads * sizeof(int8_t*));
    for (int i = 0; i < n_threads; i++)
        buffers[i] = aligned_alloc(64, n_agents * sizeof(int8_t));  /* cache-aligned */

    pthread_t* threads = malloc(n_threads * sizeof(pthread_t));
    thread_arg_t* args = calloc(n_threads, sizeof(thread_arg_t));

    int trials_per_thread = n_trials / n_threads;

    struct timespec t0, t1;
    clock_gettime(CLOCK_MONOTONIC, &t0);

    for (int i = 0; i < n_threads; i++) {
        args[i].signals = buffers[i];
        args[i].n_agents = n_agents;
        args[i].n_trials = trials_per_thread;
        args[i].thread_id = i;
        pthread_create(&threads[i], NULL, worker_thread, &args[i]);
    }

    double total_cancel = 0.0;
    double max_thread_time = 0.0;
    for (int i = 0; i < n_threads; i++) {
        pthread_join(threads[i], NULL);
        total_cancel += args[i].local_cancel_sum;
        if (args[i].elapsed > max_thread_time)
            max_thread_time = args[i].elapsed;
    }

    clock_gettime(CLOCK_MONOTONIC, &t1);
    double wall_elapsed = (t1.tv_sec - t0.tv_sec) + (t1.tv_nsec - t0.tv_nsec) / 1e9;

    double mean_cancel = total_cancel / (double)(trials_per_thread * n_threads);
    double total_ops = (double)n_agents * (double)n_trials;

    printf("  n=%-8d  trials=%-8d  cancel=%.4f  wall=%.4fs  cpu_max=%.4fs  throughput=%.1fM sig/s (wall)  %.1fM sig/s (cpu)\n",
           n_agents, n_trials, mean_cancel,
           wall_elapsed, max_thread_time,
           total_ops / wall_elapsed / 1e6,
           total_ops / max_thread_time / 1e6);

    /* Cleanup */
    for (int i = 0; i < n_threads; i++) free(buffers[i]);
    free(buffers);
    free(threads);
    free(args);

    return wall_elapsed;
}

int main() {
    int n_threads = 20;

    printf("═══════════════════════════════════════════════════════════════\n");
    printf("  Zero-Allocation C Benchmark — Xorshift128+ RNG\n");
    printf("  Testing: can C match Julia's 8.1B sig/s?\n");
    printf("  Threads: %d | Cache-aligned buffers | Lock-free RNG\n", n_threads);
    printf("═══════════════════════════════════════════════════════════════\n\n");

    printf("─── Matching Julia Benchmark (n=10K, 100K trials) ───\n");
    run_benchmark(10000, 100000, n_threads);

    printf("\n─── Scaling Test ───\n");
    int sizes[] = {10, 100, 1000, 10000, 100000, 1000000};
    int trial_counts[] = {1000000, 1000000, 1000000, 100000, 10000, 100};

    for (int i = 0; i < 6; i++) {
        run_benchmark(sizes[i], trial_counts[i], n_threads);
    }

    printf("\n─── Theory Check ───\n");
    for (int i = 0; i < 6; i++) {
        int n = sizes[i];
        double delta = (1.0 / sqrt((double)n)) * (1.0 - 3.0 / (2.0 * n));
        printf("  n=%-8d  δ=%.6f  efficiency=%.4f\n", n, delta, 1.0 - delta);
    }

    printf("\n═══════════════════════════════════════════════════════════════\n");
    printf("  Complete\n");
    printf("═══════════════════════════════════════════════════════════════\n");

    return 0;
}
