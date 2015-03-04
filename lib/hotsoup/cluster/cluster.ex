defmodule Hotsoup.Cluster do
  use GenServer
  use Hotsoup.Logger
  import Hotsoup.Helpers
 
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
    {:ok, %{by_pattern: %{},
            routers: []}}
  end
  
  def handle_call({:subscribe, client_id, pattern}, _from, state) do
    Hotsoup.Logger.info(["Subscribing client [", client_id, "] for pattern [", pattern, "]"])
    {r, state} = subscribe_client_for_pattern(state, client_id, pattern)
    {:reply, r, state}
  end
  def handle_call({:unsubscribe, client_id}, _from, state) do
    Hotsoup.Logger.info(["Unsubscribing client [", client_id, "]"])
    state = unsubscribe_client(state, client_id)
    {:reply, :ok, state}
  end
  def handle_call({:get_router, opts}, _from, state) do
    Hotsoup.Logger.info(["Requesting router"])
    {r, state} = do_get_router(state, opts)
    {:reply, r, state}
  end
  def handle_call({:stats, :routers}, _from, state) do
    stats = do_get_stats(state, :routers)
    {:reply, {:ok, stats}, state}
  end
  def handle_call({:debug, :dump}, _from, state) do
    do_dump(state)
    {:reply, :ok, state}
  end

  def handle_info({:EXIT, pid, _reason}, state) do
    Hotsoup.Logger.info(["Process [", pid, "] is dead"])
    state =
      state
      |> remove_router(pid)
      |> unsubscribe_client(pid)
    {:noreply, state}
  end

  # Internal

  defp subscribe_client_for_pattern(state = %{routers: routers}, client_id, pattern) do
    state = do_subscribe(state, pattern, client_id)
    Enum.each(routers, fn(rid) ->
                           no_error do
                             Hotsoup.Router.subscribe(rid, pattern, client_id)
                           end
                       end)
    {:ok, state}
  end
  
  defp unsubscribe_client(state = %{routers: routers}, client_id) do
    state = do_unsubscribe(state, client_id)
    Enum.each(routers, fn(router_id) ->
                           no_error do
                             Hotsoup.Router.unsubscribe(router_id, client_id)
                           end
                       end)
    state
  end

  defp do_get_router(state = %{routers: routers, by_pattern: by_pattern}, opts) do
    case Hotsoup.Cluster.Supervisor.start_router(Dict.merge(opts, [routers: routers, by_pattern: by_pattern])) do
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

  defp do_subscribe(state = %{by_pattern: by_pattern}, pattern, target) do
    by_pattern = 
      case Dict.fetch(by_pattern, pattern) do
        :error ->
          Process.link(target)
          Dict.put(by_pattern, pattern, [{target}])
        {:ok, targets} ->
          case :lists.keyfind(target, 1, targets) do
            false ->
              Process.link(target)
              Dict.put(by_pattern, pattern, [{target}|targets])
            _ ->
              by_pattern
          end
      end
    %{state | by_pattern: by_pattern}
  end

  defp do_unsubscribe(state = %{by_pattern: by_pattern}, target) do
    by_pattern = 
      Stream.map(by_pattern, fn({pattern, targets}) ->
                        {pattern, :lists.keydelete(target, 1, targets)}
                    end)
      |> Stream.filter(fn({_pattern, []}) ->
                           false
                         ({_pattern, _targets}) ->
                           true
                       end)
      |> Enum.into(%{})
    %{state | by_pattern: by_pattern}
  end

  defp do_dump(state) do
    Hotsoup.Logger.info(["state: ", state])
  end

  defp do_get_stats(%{routers: routers}, :routers) do
    routers
  end
end
