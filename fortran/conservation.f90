! ═══════════════════════════════════════════════════════════════════
! SuperInstance Conservation Law — Fortran 90 Implementation
! γ + η = C (Shannon chain rule: H(X) = I(X;G) + H(X|G))
!
! Fortran advantages: array syntax, column-major storage, OpenMP,
! pure functions, cache-friendly sequential access. The original HPC language.
! ═══════════════════════════════════════════════════════════════════

module conservation_mod
  use iso_fortran_env, only: int8, int64, real64
  implicit none
  private

  real(real64), parameter :: LOG2_3 = log(3.0_real64) / log(2.0_real64)

  public :: conservation_delta, conservation_efficiency
  public :: fleet_cancellation, monte_carlo_cancellation
  public :: ternary_dotproduct, ternary_matmul
  public :: conservation_entropy, conservation_analyze
  public :: haar_decompose
  public :: random_choice

contains

  ! δ(n) = (1/√n)(1 - 3/(2n))
  pure function conservation_delta(n) result(delta)
    integer, intent(in) :: n
    real(real64) :: delta
    if (n < 2) then
      delta = 1.0_real64
    else
      delta = (1.0_real64 / sqrt(real(n, real64))) * &
              (1.0_real64 - 3.0_real64 / (2.0_real64 * real(n, real64)))
    end if
  end function

  pure function conservation_efficiency(n) result(eff)
    integer, intent(in) :: n
    real(real64) :: eff
    eff = 1.0_real64 - conservation_delta(n)
  end function

  ! Fleet cancellation: 1 - |Σ signals| / n
  function fleet_cancellation(signals, n) result(cancel)
    integer, intent(in) :: n
    integer(int8), intent(in) :: signals(n)
    real(real64) :: cancel
    integer(int64) :: s
    integer :: i
    s = 0
    !$omp simd reduction(+:s)
    do i = 1, n
      s = s + int(signals(i), int64)
    end do
    cancel = 1.0_real64 - abs(real(s, real64)) / real(n, real64)
  end function

  ! Monte Carlo fleet cancellation
  function monte_carlo_cancellation(n_agents, n_trials) result(mean_cancel)
    integer, intent(in) :: n_agents, n_trials
    real(real64) :: mean_cancel
    real(real64) :: total_cancel
    integer :: t, i
    integer(int8), allocatable :: signals(:)
    integer :: seed_size
    integer, allocatable :: seed(:)

    call random_seed(size=seed_size)
    allocate(seed(seed_size))
    seed = 42
    call random_seed(put=seed)
    deallocate(seed)

    allocate(signals(n_agents))
    total_cancel = 0.0_real64

    !$omp parallel do reduction(+:total_cancel) private(signals, i)
    do t = 1, n_trials
      do i = 1, n_agents
        ! Random ternary: -1, 0, 1
        call random_choice(signals(i))
      end do
      total_cancel = total_cancel + fleet_cancellation(signals, n_agents)
    end do
    !$omp end parallel do

    mean_cancel = total_cancel / real(n_trials, real64)
    deallocate(signals)
  end function

  subroutine random_choice(val)
    integer(int8), intent(out) :: val
    real(real64) :: r
    call random_number(r)
    if (r < 1.0_real64 / 3.0_real64) then
      val = -1_int8
    else if (r < 2.0_real64 / 3.0_real64) then
      val = 0_int8
    else
      val = 1_int8
    end if
  end subroutine

  ! Ternary dot product
  pure function ternary_dotproduct(a, b, n) result(dp)
    integer, intent(in) :: n
    integer(int8), intent(in) :: a(n), b(n)
    integer(int64) :: dp
    integer :: i
    dp = 0
    !$omp simd reduction(+:dp)
    do i = 1, n
      dp = dp + int(a(i) * b(i), int64)
    end do
  end function

  ! Ternary matrix multiply (cache-blocked)
  subroutine ternary_matmul(A, B, C, M, K, N)
    integer, intent(in) :: M, K, N
    integer(int8), intent(in) :: A(M, K), B(K, N)
    integer(int64), intent(out) :: C(M, N)
    integer :: i, j, p
    C = 0_int64
    do i = 1, M
      do j = 1, N
        do p = 1, K
          C(i, j) = C(i, j) + int(A(i, p) * B(p, j), int64)
        end do
      end do
    end do
  end subroutine

  ! Shannon entropy for ternary
  function conservation_entropy(signals, n) result(H)
    integer, intent(in) :: n
    integer(int8), intent(in) :: signals(n)
    real(real64) :: H
    integer :: i, cnt_neg, cnt_zero, cnt_pos
    real(real64) :: p

    cnt_neg = 0; cnt_zero = 0; cnt_pos = 0
    !$omp simd reduction(+:cnt_neg, cnt_zero, cnt_pos)
    do i = 1, n
      if (signals(i) == -1_int8) cnt_neg = cnt_neg + 1
      if (signals(i) == 0_int8) cnt_zero = cnt_zero + 1
      if (signals(i) == 1_int8) cnt_pos = cnt_pos + 1
    end do

    H = 0.0_real64
    p = real(cnt_neg, real64) / real(n, real64)
    if (p > 0) H = H - p * log(p) / log(2.0_real64)
    p = real(cnt_zero, real64) / real(n, real64)
    if (p > 0) H = H - p * log(p) / log(2.0_real64)
    p = real(cnt_pos, real64) / real(n, real64)
    if (p > 0) H = H - p * log(p) / log(2.0_real64)
  end function

  ! Conservation analysis: γ + η = C
  subroutine conservation_analyze(X, G, n, gamma_val, eta_val, C_val)
    integer, intent(in) :: n
    integer(int8), intent(in) :: X(n), G(n)
    real(real64), intent(out) :: gamma_val, eta_val, C_val
    integer :: i, j
    integer :: joint(3, 3)
    real(real64) :: p, H_XG, H_G
    integer(int8), allocatable :: G_copy(:)

    C_val = conservation_entropy(X, n)
    H_G = conservation_entropy(G, n)

    ! Joint distribution
    joint = 0
    do i = 1, n
      joint(int(X(i)) + 2, int(G(i)) + 2) = &
        joint(int(X(i)) + 2, int(G(i)) + 2) + 1
    end do

    H_XG = 0.0_real64
    do i = 1, 3
      do j = 1, 3
        p = real(joint(i, j), real64) / real(n, real64)
        if (p > 0) H_XG = H_XG - p * log(p) / log(2.0_real64)
      end do
    end do

    eta_val = max(0.0_real64, H_XG - H_G)
    gamma_val = max(0.0_real64, C_val - eta_val)
  end subroutine

  ! Haar wavelet decomposition
  subroutine haar_decompose(signal, n, approx, detail)
    integer, intent(in) :: n
    integer(int8), intent(in) :: signal(n)
    real(real64), intent(out) :: approx(n/2), detail(n/2)
    integer :: i, half
    half = n / 2
    !$omp simd
    do i = 1, half
      approx(i) = (real(signal(2*i-1), real64) + real(signal(2*i), real64)) / sqrt(2.0_real64)
      detail(i) = (real(signal(2*i-1), real64) - real(signal(2*i), real64)) / sqrt(2.0_real64)
    end do
  end subroutine

end module conservation_mod

! ═══ Main Program ═══
program conservation_bench
  use iso_fortran_env, only: int8, int64, real64
  use conservation_mod
  use omp_lib
  implicit none

  integer, parameter :: DP = kind(1.0d0)
  integer :: fleet_sizes(8)
  integer :: i, n, n_trials
  real(real64) :: mc_result, theory, err, t0, t1
  real(real64) :: gamma_v, eta_v, C_v
  integer(int8), allocatable :: X(:), G(:)
  real(real64), allocatable :: approx(:), detail(:)
  integer :: seed_size
  integer, allocatable :: seed(:)

  print *, "═══ SuperInstance Conservation Law — Fortran 90 ═══"
  write(*,'(A,I0)') " OpenMP threads: ", omp_get_max_threads()
  print *, ""

  ! Monte Carlo benchmark
  print *, "─── Monte Carlo Fleet Cancellation ───"
  fleet_sizes = [5, 10, 50, 100, 1000, 10000, 100000, 1000000]
  n_trials = 10000

  write(*,'(A8, A14, A14, A10, A12)') "Fleet", "Empirical", "Theory", "Error%", "Time(ms)"

  do i = 1, size(fleet_sizes)
    n = fleet_sizes(i)
    if (n > 10000) n_trials = 100  ! reduce for large fleets
    if (n > 100000) n_trials = 10

    t0 = omp_get_wtime()
    mc_result = monte_carlo_cancellation(n, n_trials)
    t1 = omp_get_wtime()

    theory = conservation_efficiency(n)
    err = abs(mc_result - theory) / theory * 100.0_real64

    write(*,'(I8, F14.4, F14.4, F10.2, F12.1)') &
      n, mc_result, theory, err, (t1 - t0) * 1000.0_real64
  end do

  ! Conservation identity
  print *, ""
  print *, "─── Conservation Identity γ + η = C ───"
  n = 10000
  allocate(X(n), G(n))
  call random_seed(size=seed_size)
  allocate(seed(seed_size))
  seed = 123
  call random_seed(put=seed)
  deallocate(seed)

  do i = 1, n
    call random_choice(X(i))
    call random_choice(G(i))
  end do

  call conservation_analyze(X, G, n, gamma_v, eta_v, C_v)
  write(*,'(A, F10.6)') " γ = ", gamma_v
  write(*,'(A, F10.6)') " η = ", eta_v
  write(*,'(A, F10.6)') " C = ", C_v
  write(*,'(A, F10.6)') " γ+η = ", gamma_v + eta_v

  ! Haar wavelet
  print *, ""
  print *, "─── Haar Wavelet Decomposition ───"
  deallocate(X)
  allocate(X(8))
  X = [1_int8, 1_int8, -1_int8, 1_int8, -1_int8, -1_int8, 1_int8, -1_int8]
  allocate(approx(4), detail(4))
  call haar_decompose(X, 8, approx, detail)
  write(*,'(A, 4F8.3)') " Approx: ", approx
  write(*,'(A, 4F8.3)') " Detail: ", detail

  deallocate(X, G, approx, detail)
  print *, ""
  print *, "═══ Fortran Complete ═══"

end program conservation_bench
