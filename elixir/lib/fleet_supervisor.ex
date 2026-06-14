defmodule Conservation.FleetSupervisor do
  @moduledoc """
  DynamicSupervisor managing a pool of FleetAgent processes.
  
  Spawns N agents, aggregates their signals in parallel,
  and measures fleet cancellation. Handles agent failures
  gracefully via BEAM supervision.
  """
  use DynamicSupervisor

  def start_link(init_arg) do
    DynamicSupervisor.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  def spawn_fleet(n) do
    agents = Enum.map(1..n, fn _ ->
      {:ok, pid} = DynamicSupervisor.start_child(__MODULE__, Conservation.FleetAgent)
      pid
    end)
    agents
  end

  def aggregate_signals(agents) do
    agents
    |> Task.async_stream(&Conservation.FleetAgent.signal/1, 
         ordered: false, timeout: 5000)
    |> Enum.map(fn {:ok, val} -> val end)
  end

  def measure_cancellation(agents) do
    signals = aggregate_signals(agents)
    Conservation.cancellation_factor(signals)
  end

  def terminate_fleet(agents) do
    Enum.each(agents, &GenServer.stop/1)
  end

  @impl true
  def init(_arg) do
    DynamicSupervisor.init(strategy: :one_for_one, max_restarts: 1000)
  end
end
