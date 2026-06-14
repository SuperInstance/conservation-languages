/*
 * zero_alloc_omp.c — OpenMP version with persistent thread pool
 *
 * OpenMP keeps a thread pool alive between parallel regions,
 * avoiding the pthread_create/join overhead per call.
 *
 * Build: gcc -O3 -fopenmp -march=native -o zero_alloc_omp zero_alloc_omp.c -lm
 */
#define _GNU_SOURCE
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>
#include <time.h>
#include <stdint.h>
#include <omp.h>

/* Xorshift128+ — inlined */
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
    if (r < 6148914691236517206ULL) return -1;
    if (r < 12297829382473034413ULL) return 0;
    return 1;
}

int main() {
    int n_threads = omp_get_max_threads();
    int sizes[] = {10, 100, 1000, 10000, 100000, 1000000};
    int trial_counts[] = {1000000, 1000000, 100000, 100000, 10000, 100};
    int n_tests = 6;

    printf("═══════════════════════════════════════════════════════════════\n");
    printf("  C Zero-Allocation — OpenMP (persistent thread pool)\n");
    printf("  Threads: %d\n", n_threads);
    printf("═══════════════════════════════════════════════════════════════\n\n");

    /* Pre-allocate buffers — persistent across all tests */
    int8_t** buffers = (int8_t**)malloc(n_threads * sizeof(int8_t*));
    for (int i = 0; i < n_threads; i++) {
        posix_memalign((void**)&buffers[i], 64, 1000000 * sizeof(int8_t));
    }

    /* RNG state per thread — persistent */
    uint64_t (*rng_states)[2] = malloc(n_threads * sizeof(uint64_t[2]));

    for (int test = 0; test < n_tests; test++) {
        int n_agents = sizes[test];
        int n_trials = trial_counts[test];
        int trials_per_thread = n_trials / n_threads;

        struct timespec t0, t1;
        clock_gettime(CLOCK_MONOTONIC, &t0);

        double total_cancel = 0.0;

        #pragma omp parallel reduction(+:total_cancel)
        {
            int tid = omp_get_thread_num();
            int8_t* buf = buffers[tid];

            /* Seed RNG */
            rng_states[tid][0] = (uint64_t)tid * 0xDEADBEEFCAFEBABEULL + 42;
            rng_states[tid][1] = (uint64_t)tid * 0x123456789ABCDEF0ULL + 7;

            double local_cancel = 0.0;

            #pragma omp barrier  /* Ensure all threads ready */

            for (int t = 0; t < trials_per_thread; t++) {
                int sum = 0;
                for (int i = 0; i < n_agents; i++) {
                    int8_t v = fast_ternary(rng_states[tid]);
                    buf[i] = v;
                    sum += v;
                }
                local_cancel += 1.0 - (double)abs(sum) / (double)n_agents;
            }

            total_cancel += local_cancel;
        }

        clock_gettime(CLOCK_MONOTONIC, &t1);
        double elapsed = (t1.tv_sec - t0.tv_sec) + (t1.tv_nsec - t0.tv_nsec) / 1e9;

        double mean_cancel = total_cancel / n_threads / trials_per_thread;
        double throughput = (double)n_agents * (double)n_trials / elapsed / 1e9;

        printf("  n=%-8d  trials=%-8d  cancel=%.4f  time=%.4fs  throughput=%.1fB sig/s\n",
               n_agents, n_trials, mean_cancel, elapsed, throughput);
    }

    /* Cleanup */
    for (int i = 0; i < n_threads; i++) free(buffers[i]);
    free(buffers);
    free(rng_states);

    printf("\n═══════════════════════════════════════════════════════════════\n");
    printf("  Complete\n");
    printf("═══════════════════════════════════════════════════════════════\n");

    return 0;
}
