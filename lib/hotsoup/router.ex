defmodule Hotsoup.Router do
  require Dict
  use GenServer
  use Hotsoup.Logger
  import Hotsoup.Helpers

  # API

  def default_options do
    %{ttl:        :infinite,
      by_pattern: %{}}
  end

  def start_link(opts \\ default_options) do
    GenServer.start_link(__MODULE__, [opts])
  end

  def debug(rid, :dump) do
    GenServer.call(rid, {:debug, :dump}, :infinity)
  end

  def subscribe(rid, expr, target) when is_bitstring(expr) and is_pid(target) do
    GenServer.cast(rid, {:subscribe, expr, target})
  end

  def unsubscribe(rid, target) when is_pid(target) do
    GenServer.cast(rid, {:unsubscribe, target})
  end

  def route(rid, node) do
    GenServer.cast(rid, {:route, node})
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

  ## Callbacks GenServer

  def init([opts]) do
    Process.flag(:trap_exit, true)

    %{ttl: ttl, routers: routers, by_pattern: by_pattern} = Dict.merge(default_options, opts)
    
    ref = 
      case ttl do
        :infinite ->
          nil
        delay when is_integer(delay) ->
          Process.send_after(self(), :expired, ttl)
      end
      
    Enum.each(routers, &Process.link(&1))
    
    by_pattern = 
      Stream.map(by_pattern, fn({pattern, targets}) ->
                               epm = :ejpet.compile(pattern)
                               Enum.each(targets, fn({target}) ->
                                                    Process.link(target)
                                                  end)
                               {pattern, {epm, targets}}
                             end)
      |> Enum.into(%{})

    {:ok, %{by_pattern: by_pattern,
            routers:    routers,
            timer:      ref}}
  end

  def handle_call({:debug, :dump}, _from, state) do
    do_dump(state)
    {:reply, :ok, state}
  end
  
  def handle_cast({:route, node}, state) do
    Hotsoup.Logger.info(["Processing route ", node])
    state = reset_timer(state)
    do_route(state, node)
    {:noreply, state}
  end
  def handle_cast({:subscribe, pattern, target}, state) do
    Hotsoup.Logger.info(["Processing subscribe ", pattern])
    state = do_subscribe(state, pattern, target)
    {:noreply, state}
  end
  def handle_cast({:unsubscribe, target}, state) do
    Hotsoup.Logger.info(["Processing unsubscribe "])
    state = do_unsubscribe(state, target)
    {:noreply, state}
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
  def handle_info({:EXIT, pid, _reason}, state) do
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
      |> Stream.filter(fn({_pattern, {_epm, []}}) ->
                           false
                         ({_pattern, {_epm, _targets}}) ->
                           true
                       end)
      |> Enum.into(%{})
    %{state | by_pattern: by_pattern}
  end

  defp do_route(state = %{routers: routers}, node) do
    do_propagate(state, node)
  end
  
  defp do_propagate(%{by_pattern: by_pattern}, node) do
    Enum.each(by_pattern, fn({_pattern, {epm, targets}}) ->
                              case :ejpet.run(node, epm) do
                                {true, captures} ->
                                  Enum.each targets, fn({tgt}) ->
                                                         no_error do
                                                           send(tgt, {node, captures})
                                                         end
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

  defp reset_timer(state = %{timer: nil}) do
    state
  end
  defp reset_timer(state = %{timer: timer}) do
    :erlang.cancel_timer(timer)
    %{state | timer: Process.send_after(self(), :expired, 10000)}
  end
end
