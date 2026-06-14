defmodule Conservation.FleetAgent do
  @moduledoc """
  GenServer representing a single fleet agent with ternary state {-1, 0, +1}.
  
  In the BEAM model, each agent is a lightweight process (~2KB).
  Millions can coexist — each with independent state, failure isolation,
  and preemptive scheduling.
  """
  use GenServer

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts)
  end

  def signal(pid), do: GenServer.call(pid, :signal)

  def set_valence(pid, valence), do: GenServer.cast(pid, {:set, valence})

  @impl true
  def init(_opts) do
    valence = case :rand.uniform(3) do
      1 -> -1
      2 -> 0
      _ -> 1
    end
    {:ok, %{valence: valence}}
  end

  @impl true
  def handle_call(:signal, _from, state) do
    {:reply, state.valence, state}
  end

  @impl true
  def handle_cast({:set, valence}, state) do
    {:noreply, %{state | valence: valence}}
  end
end
