#!/usr/bin/env elixir
# Run: mix run bench/runner.exs

alias Conservation.{FleetSupervisor, FleetAgent}

IO.puts("═══ SuperInstance Conservation Law — Elixir/OTP ═══")
IO.puts("BEAM schedulers: #{System.schedulers_online()}")
IO.puts("")

# Start supervisors
children = [
  {Conservation.FleetSupervisor, []}
]
{:ok, _} = Supervisor.start_link(children, strategy: :one_for_one)

IO.puts("─── Monte Carlo Fleet Cancellation (parallel) ───")
sizes = [5, 10, 50, 100, 500, 1000, 5000, 10000]

IO.puts(String.duplicate("-", 65))
IO.puts(String.pad_trailing("Fleet", 10) <> 
        String.pad_trailing("Empirical", 14) <> 
        String.pad_trailing("Theory", 14) <> 
        String.pad_trailing("Error%", 10) <> 
        String.pad_trailing("Time(ms)", 10))
IO.puts(String.duplicate("-", 65))

for n <- sizes do
  trials = if n > 5000, do: 100, else: 1000
  
  t0 = System.monotonic_time(:millisecond)
  result = Conservation.monte_carlo_parallel(n, trials)
  t1 = System.monotonic_time(:millisecond)
  
  theory = Conservation.efficiency(n)
  err = abs(result - theory) / theory * 100
  
  IO.puts(
    String.pad_trailing(Integer.to_string(n), 10) <>
    String.pad_trailing(:erlang.float_to_binary(result, decimals: 4), 14) <>
    String.pad_trailing(:erlang.float_to_binary(theory, decimals: 4), 14) <>
    String.pad_trailing(:erlang.float_to_binary(err, decimals: 2), 10) <>
    String.pad_trailing(Integer.to_string(t1 - t0), 10)
  )
end

# Conservation identity
IO.puts("")
IO.puts("─── Conservation Identity γ + η = C ───")
g_signals = Conservation.ternary_signals(5000)
mask = Enum.map(1..5000, fn _ -> :rand.uniform() < 0.5 end)
x_signals = Enum.zip(g_signals, mask)
           |> Enum.map(fn {g, m} -> if m, do: g, else: Enum.random([-1, 0, 1]) end)

{gamma, eta, c} = Conservation.analyze(x_signals, g_signals)
IO.puts("  γ = #{Float.round(gamma, 6)} bits")
IO.puts("  η = #{Float.round(eta, 6)} bits")
IO.puts("  C = #{Float.round(c, 6)} bits")
IO.puts("  γ + η = #{Float.round(gamma + eta, 6)} bits")
IO.puts("  H_max = #{Float.round(Conservation.h_max(), 6)} bits")

# Haar wavelet
IO.puts("")
IO.puts("─── Haar Wavelet Decomposition ───")
signal = [1, 1, -1, 1, -1, -1, 1, -1]
{approx, detail} = Conservation.haar_decompose(signal)
IO.puts("  Signal: #{inspect(signal)}")
IO.puts("  Approx: #{inspect(Enum.map(approx, &Float.round(&1, 3)))}")
IO.puts("  Detail: #{inspect(Enum.map(detail, &Float.round(&1, 3)))}")

# GenServer fleet stress test
IO.puts("")
IO.puts("─── GenServer Fleet Stress Test ───")
for n <- [100, 1000, 5000] do
  t0 = System.monotonic_time(:millisecond)
  agents = FleetSupervisor.spawn_fleet(n)
  cancel = FleetSupervisor.measure_cancellation(agents)
  t1 = System.monotonic_time(:millisecond)
  FleetSupervisor.terminate_fleet(agents)
  
  theory = Conservation.efficiency(n)
  IO.puts("  #{n} agents: cancel=#{Float.round(cancel, 4)}, theory=#{Float.round(theory, 4)}, time=#{t1-t0}ms")
end

# Throughput
IO.puts("")
IO.puts("─── Throughput ───")
t0 = System.monotonic_time(:millisecond)
result = Conservation.monte_carlo_parallel(100000, 10)
t1 = System.monotonic_time(:millisecond)
throughput = 100000 * 10 / (t1 - t0) / 1000
IO.puts("  100K agents × 10 trials: #{t1-t0}ms (#{Float.round(throughput, 1)}M sig/s)")

IO.puts("")
IO.puts("═══ Elixir Complete ═══")
