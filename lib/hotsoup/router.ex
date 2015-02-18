defmodule Hotsoup.Router do
  use GenServer
  use Hotsoup.Logger
  require Dict

  # API

  def default_options do
    %{ttl: :infinite}
  end

  def start_link(opts \\ default_options) do
    GenServer.start_link(__MODULE__, [opts])
  end

  def subscribe(rid, expr, target) when is_bitstring(expr) and is_pid(target) do
    GenServer.call(rid, {:subscribe, expr, target}, :infinity)
  end

  def unsubscribe(rid, target) when is_pid(target) do
    GenServer.call(rid, {:unsubscribe, target}, :infinity)
  end

  def route(rid, node) do
    GenServer.call(rid, {:route, node}, :infinity)
  end

  def propagate(rid, node) do
    GenServer.cast(rid, {:propagate, node})
  end

  def add_router(rid, other_id) do
    GenServer.cast(rid, {:add_router, other_id})
  end

  def remove_router(rid, other_id) do
    GenServer.cast(rid, {:remove_router, other_id})
  end

  def debug(rid, :dump) do
    GenServer.call(rid, {:debug, :dump}, :infinity)
  end

  ## Callbacks GenServer

  def init([opts]) do
    %{ttl: ttl} = Dict.merge(default_options, opts)
    ref = 
      case ttl do
        :infinite ->
          nil
        delay when is_integer(delay) ->
          Process.send_after(self(), :expired, ttl)
      end
    Process.flag(:trap_exit, true)
    {:ok, %{by_pattern: %{},
            routers:    [],
            timer:      ref}}
  end

  def handle_call({:subscribe, pattern, target}, from, state) do
    Hotsoup.Logger.info(["Processing subscribe ", pattern])
    state = do_subscribe(state, pattern, target)
    {:reply, :ok, state}
  end

  def handle_call({:unsubscribe, target}, from, state) do
    Hotsoup.Logger.info(["Processing unsubscribe "])
    state = do_unsubscribe(state, target)
    {:reply, :ok, state}
  end
  
  def handle_call({:route, node}, from, state) do
    Hotsoup.Logger.info(["Processing route ", node])
    state = reset_timer(state)
    do_route(state, node)
    {:reply, :ok, state}
  end

  def handle_call({:debug, :dump}, from, state) do
    do_dump(state)
    {:reply, :ok, state}
  end

  def handle_cast({:add_router, router_id}, state) do
    Hotsoup.Logger.info(["Adding router ", router_id])
    state = do_add_router(state, router_id)
    {:noreply, state}
  end

  def handle_cast({:propagate, node}, state) do
    Hotsoup.Logger.info(["Propagating node", node])
    do_propagate(state, node)
    {:noreply, state}
  end

  def handle_cast({:remove_router, router_id}, state) do
    Hotsoup.Logger.info(["Removing router ", router_id])
    state = do_remove_router(state, router_id)
    {:noreply, state}
  end
  
  def handle_info(:expired, state) do
    Hotsoup.Logger.info(["Router [", self(), "] expired"])
    {:stop, :normal, state}
  end

  def handle_info({:EXIT, pid, reason}, state) do
    Hotsoup.Logger.info(["Process [", pid, "] exited"])
    state =
      state
      |> do_unsubscribe(pid)
      |> do_remove_router(pid)
    {:noreply, state}
  end

  def terminate(_reason, _state) do
    Hotsoup.Logger.info(["Process [", self, "] terminated"]);
    :ok
  end

  # Internals

  defp do_subscribe(state = %{by_pattern: by_pattern}, pattern, target) do
    by_pattern = 
      case Dict.fetch(by_pattern, pattern) do
        :error ->
          epm = :ejpet.compile(pattern)
          Process.link(target)
          Dict.put(by_pattern, pattern, {epm, [{target}]})
        {:ok, {epm, targets}} ->
          case :lists.keyfind(target, 1, targets) do
            false ->
              Process.link(target)
              Dict.put(by_pattern, pattern, {epm, [{target}| targets]})
            _ ->
              by_pattern
          end
      end
    %{state | by_pattern: by_pattern}
  end

  defp do_unsubscribe(state = %{by_pattern: by_pattern}, target) do
    by_pattern = 
      by_pattern
      |> Stream.map(fn({pattern, {epm, targets}}) ->
                        {pattern, {epm, :lists.keydelete(target, 1, targets)}}
                    end)
      |> Stream.filter(fn({pattern, {_epm, []}}) ->
                           false
                         ({pattern, {_epm, _targets}}) ->
                           true
                       end)
      |> Enum.into(%{})
    %{state | by_pattern: by_pattern}
  end

  defp do_route(state = %{by_pattern: by_pattern,
                          routers: routers}, node) do
    do_propagate(state, node)
    Enum.each(routers, &propagate(&1, node))
  end
  
  defp do_propagate(state = %{by_pattern: by_pattern}, node) do
    Enum.each(by_pattern, fn({pattern, {epm, targets}}) ->
                              case :ejpet.run(node, epm) do
                                {true, captures} ->
                                  Enum.each targets, fn({tgt}) ->
                                                         send(tgt, {node, captures})
                                                     end
                                {false, _} ->
                                  :ok
                              end
                          end)
  end

  defp do_add_router(state = %{routers: routers}, router_id) do
    routers = 
      case Enum.find(routers, &(&1 == router_id)) do
        nil ->
          Process.link(router_id)
          [router_id | routers]
        _ ->
          routers
      end
    %{state | routers: routers}
  end

  defp do_remove_router(state = %{routers: routers}, router_id) do
    Process.unlink(router_id)
    %{state | routers: Enum.reject(routers, &(&1 == router_id))}
  end

  defp do_dump(%{by_pattern: by_pattern}) do
    Hotsoup.Logger.info(["dict: ", by_pattern])
  end

  defp reset_timer(state = %{timer: timer}) do
    case timer do
      nil ->
        state
      _ ->
        :erlang.cancel_timer(timer)
        %{state | timer: Process.send_after(self(), :expired, 10000)}
    end
  end
end
