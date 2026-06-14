defmodule Conservation do
  @moduledoc """
  SuperInstance Conservation Law: γ + η = C
  
  Shannon chain rule: H(X) = I(X;G) + H(X|G)
  
  ## Advantages of Elixir/BEAM
  
  - Millions of lightweight processes (each agent = process)
  - Preemptive scheduling across all cores
  - Fault tolerance via supervision trees
  - Hot code swapping
  - Distributed fleet via Node.ping
  """

  @log2_3 :math.log2(3)

  @doc "δ(n) = (1/√n)(1 - 3/(2n))"
  def delta(n) when n < 2, do: 1.0
  def delta(n), do: (1.0 / :math.sqrt(n)) * (1.0 - 3.0 / (2.0 * n))

  @doc "Conservation efficiency = 1 - δ(n)"
  def efficiency(n), do: 1.0 - delta(n)

  @doc "Fleet cancellation: 1 - |Σ signals| / n"
  def cancellation_factor(signals) when is_list(signals) do
    n = length(signals)
    if n == 0, do: 0.0, else: 1.0 - abs(Enum.sum(signals)) / n
  end

  @doc "Shannon entropy H(X) for ternary distribution"
  def entropy(signals) when is_list(signals) do
    n = length(signals)
    if n == 0 do
      0.0
    else
      counts = Enum.frequencies(signals)
      counts
      |> Map.values()
      |> Enum.map(fn c -> 
        p = c / n
        if p > 0, do: -p * :math.log2(p), else: 0.0
      end)
      |> Enum.sum()
    end
  end

  @doc "Conservation analysis: returns {γ, η, C}"
  def analyze(x_signals, g_signals) do
    c = entropy(x_signals)
    h_g = entropy(g_signals)
    n = length(x_signals)
    
    # Joint entropy H(X, G)
    joint = Enum.zip(x_signals, g_signals)
            |> Enum.frequencies()
            |> Map.values()
            |> Enum.map(fn c -> 
              p = c / n
              if p > 0, do: -p * :math.log2(p), else: 0.0
            end)
            |> Enum.sum()
    
    eta = max(0.0, joint - h_g)
    gamma = max(0.0, c - eta)
    {gamma, eta, c}
  end

  @doc "Generate random ternary signals"
  def ternary_signals(n) do
    Enum.map(1..n, fn _ ->
      case :rand.uniform(3) do
        1 -> -1
        2 -> 0
        _ -> 1
      end
    end)
  end

  @doc "Monte Carlo fleet cancellation (sequential)"
  def monte_carlo(fleet_size, n_trials) do
    cancellations = Enum.map(1..n_trials, fn _ ->
      signals = ternary_signals(fleet_size)
      cancellation_factor(signals)
    end)
    Enum.sum(cancellations) / n_trials
  end

  @doc "Monte Carlo fleet cancellation (parallel via Task.async_stream)"
  def monte_carlo_parallel(fleet_size, n_trials) do
    cancellations = 
      1..n_trials
      |> Task.async_stream(
        fn _ ->
          signals = ternary_signals(fleet_size)
          cancellation_factor(signals)
        end,
        max_concurrency: System.schedulers_online() * 2,
        ordered: false,
        timeout: :infinity
      )
      |> Enum.map(fn {:ok, val} -> val end)
    
    Enum.sum(cancellations) / n_trials
  end

  @doc "Haar wavelet decomposition (single level)"
  def haar_decompose(signal) do
    half = div(length(signal), 2)
    even = Enum.take_every(signal, 2)
    odd = Enum.drop_every(signal, 2)
    sqrt2 = :math.sqrt(2)
    
    approx = Enum.zip(even, odd) |> Enum.map(fn {e, o} -> (e + o) / sqrt2 end)
    detail = Enum.zip(even, odd) |> Enum.map(fn {e, o} -> (e - o) / sqrt2 end)
    
    {approx, detail}
  end

  @doc "Maximum ternary entropy: log₂(3)"
  def h_max, do: @log2_3
end
