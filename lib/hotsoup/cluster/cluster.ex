defmodule Hotsoup.Cluster do
  use Hotsoup.Logger
  use GenServer

  # API
  
  def start_link do
    GenServer.start_link(__MODULE__, [], [name: __MODULE__])
  end
  
  def subscribe(client_id, pattern) when is_pid(client_id) and is_bitstring(pattern) do
    GenServer.call(__MODULE__, {:subscribe, client_id, pattern})
  end
  
  def unsubscribe(client_id) when is_pid(client_id) do
    GenServer.call(__MODULE__, {:unsubscribe, client_id})
  end

  def get_router(opts \\ Hotsoup.Router.default_options) do
    GenServer.call(__MODULE__, {:get_router, opts})
  end

  def debug(:dump) do
    GenServer.call(__MODULE__, {:debug, :dump}, :infinity)
  end

  def get_stats(:routers) do
    GenServer.call(__MODULE__, {:stats, :routers}, :infinity)
  end

  # Callbacks GenServer

  def init(_opts) do
    Hotsoup.Logger.info(["started"])
    Process.flag(:trap_exit, true)
    {:ok, %{routers: []}}
  end
  
  def handle_call({:subscribe, client_id, pattern}, from, state) do
    Hotsoup.Logger.info(["Subscribing client [", client_id, "] for pattern [", pattern, "]"])
    {r, state} = subscribe_client_for_pattern(state, client_id, pattern)
    {:reply, r, state}
  end
  
  def handle_call({:unsubscribe, client_id}, from, state) do
    Hotsoup.Logger.info(["Unsubscribing client [", client_id, "]"])
    {r, state} = unsubscribe_client(state, client_id)
    {:reply, r, state}
  end
  
  def handle_call({:get_router, opts}, from, state) do
    Hotsoup.Logger.info(["Requesting router"])
    {r, state} = do_get_router(state, opts)
    {:reply, r, state}
  end

  def handle_call({:stats, :routers}, from, state) do
    stats = do_get_stats(state, :routers)
    {:reply, {:ok, stats}, state}
  end

  def handle_call({:debug, :dump}, from, state) do
    do_dump(state)
    {:reply, :ok, state}
  end

  def handle_info({:EXIT, pid, reason}, state) do
    Hotsoup.Logger.info(["Process [", pid, "] is dead"])
    state =
      state
      |> remove_router(pid)
      |> unsubscribe_client(pid)
    {:noreply, state}
  end

  def handle_info(info, state) do
    Hotsoup.Logger.info(["Registrar received: ", info])
  end

  # Internal
  
  defp subscribe_client_for_pattern(state = %{routers: routers}, client_id, pattern) do
    Enum.each(routers, &(Hotsoup.Router.subscribe(&1, pattern, client_id)))
    {:ok, state}
  end
  
  defp unsubscribe_client(state = %{routers: routers}, client_id) do
    Enum.each(routers, fn(router_id) ->
                           try do
                             Hotsoup.Router.unsubscribe(router_id, client_id)
                           catch 
                             _e, _r -> :ok
                           end
                       end)
    state
  end

  defp do_get_router(state, opts) do
    case Hotsoup.Cluster.Supervisor.start_router(opts) do
      {:ok, pid} ->
        {{:ok, pid}, add_router(state, pid)}
      _ ->
        {:error, state}
    end
  end

  defp add_router(state = %{routers: routers}, router_id) do
    Process.link(router_id)
    Enum.each(routers, &Hotsoup.Router.add_router(&1, router_id))
    %{state | routers: [router_id | routers]}
  end
  
  defp remove_router(state = %{routers: routers}, router_id) do
    Process.unlink(router_id)
    Enum.each(routers, &Hotsoup.Router.remove_router(&1, router_id))
    %{state | routers: Enum.filter(routers, &(&1 != router_id))}
  end

  defp do_dump(state) do
    Hotsoup.Logger.info(["state: ", state])
  end

  defp do_get_stats(%{routers: routers}, :routers) do
    routers
  end
end
