defmodule Hotsoup.Registrar do
  use Hotsoup.Logger
  use GenServer
  
  # API
  
  def start_link do
    GenServer.start_link __MODULE__, [], name: __MODULE__
  end
  
  def subscribe(client_id, pattern) when is_pid(client_id) and is_bitstring(pattern) do
    GenServer.call __MODULE__, {:subscribe, client_id, pattern}
  end
  
  def unsubscribe(client_id) when is_pid(client_id) do
    GenServer.call __MODULE__, {:unsubscribe, client_id}
  end

  # Callbacks GenServer

  def init(_opts) do
    Hotsoup.Logger.info ["started"]
    Process.flag :trap_exit, true
    {:ok, %{routers: []}}
  end
  
  def handle_call({:subscribe, client_id, pattern}, from, state) do
    Hotsoup.Logger.info ["Subscribing client [", client_id, "] for pattern [", pattern, "]"]
    {r, state} = subscribe_client_for_pattern(state, client_id, pattern)
    {:reply, r, state}
  end
  
  def handle_call({:unsubscribe, client_id}, from, state) do
    Hotsoup.Logger.info ["Unsubscribing client [", client_id, "]"]
    {r, state} = unsubscribe_client(state, client_id)
    {:reply, r, state}
  end

  def handle_info({:EXIT, pid, reason}, state) do
    Hotsoup.Logger.info ["Client [", pid, "] is dead"]
    state = unsubscribe_client(state, pid)
    {:noreply, state}
  end

  # Internal
  
  defp subscribe_client_for_pattern(state = %{routers: routers}, client_id, pattern) do
    Enum.each routers, &(Hotsoup.Router.subscribe(&1, client_id, pattern))
    {:ok, state}
  end
  
  defp unsubscribe_client(state = %{routers: routers}, client_id) do
    Enum.each routers, &(Hotsoup.Router.unsubscribe(&1, client_id))
    {:ok, state}
  end

  defp remove_router(state = %{routers: routers}, router_id) do
    {:ok, %{state | routers: Enum.filter(routers, &(&1 != router_id))}}
  end
end
