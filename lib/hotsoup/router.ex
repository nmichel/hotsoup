defmodule Hotsoup.Router do
  use GenServer
  use Hotsoup.Logger
  require Dict

  # API

  def start_link do
    GenServer.start_link __MODULE__, []
  end

  def register(rid, expr, target) when is_bitstring(expr) and is_pid(target) do
    GenServer.call rid, {:register, expr, target}, :infinity
  end

  def unregister(rid, target) when is_pid(target) do
    GenServer.call rid, {:unregister, target}, :infinity
  end

  def route(rid, node) do
    GenServer.call rid, {:route, node}, :infinity
  end

  def debug(rid, :dump) do
    GenServer.call rid, {:debug, :dump}, :infinity
  end

  ## Callbacks GenServer

  def init(_opts) do
    Hotsoup.Logger.info ["started"]
    Process.flag :trap_exit, true
    {:ok, %{by_pattern: %{}}}
  end

  def handle_call({:register, pattern, target}, from, state) do
    Hotsoup.Logger.info ["Processing register ", pattern]
    state = do_register(state, pattern, target)
    {:reply, :ok, state}
  end

  def handle_call({:unregister, target}, from, state) do
    Hotsoup.Logger.info ["Processing unregister "]
    state = do_unregister(state, target)
    {:reply, :ok, state}
  end

  def handle_call({:route, node}, from, state) do
    Hotsoup.Logger.info ["Processing route ", node]
    do_route(state, node)
    {:reply, :ok, state}
  end

  def handle_call({:debug, :dump}, from, state) do
    do_dump(state)
    {:reply, :ok, state}
  end

  def handle_info({:EXIT, target, reason}, state) do
    state = do_unregister(state, target)
    {:noreply, state}
  end

  # Internals

  defp do_register(state = %{by_pattern: by_pattern}, pattern, target) do
    by_pattern = 
      case Dict.fetch(by_pattern, pattern) do
        :error ->
          epm = :ejpet.compile(pattern)
          Process.link target
          Dict.put(by_pattern, pattern, {epm, [{target}]})
        {:ok, {epm, targets}} ->
          case :lists.keyfind(target, 1, targets) do
            false ->
              Process.link target
              Dict.put(by_pattern, pattern, {epm, [{target}| targets]})
            _ ->
              by_pattern
          end
      end
    %{state | by_pattern: by_pattern}
  end

  defp do_unregister(state = %{by_pattern: by_pattern}, target) do
    by_pattern = 
      by_pattern
      |> Stream.map(fn {pattern, {epm, targets}} ->
                         {pattern, {epm, :lists.keydelete(target, 1, targets)}}
                    end)
      |> Stream.filter(fn {pattern, {_epm, []}} ->
                            false
                          {pattern, {_epm, _targets}} ->
                            true
                       end)
      |> Enum.into(%{})
    %{state | by_pattern: by_pattern}
  end

  defp do_route(state = %{by_pattern: by_pattern}, node) do
    Enum.each by_pattern, fn({pattern, {epm, targets}}) ->
                              case :ejpet.run(node, epm) do
                                {true, captures} ->
                                  Enum.each targets, fn({tgt}) ->
                                                         send tgt, {node, captures}
                                                     end
                                {false, _} ->
                                  :ok
                              end
                          end
    state
  end

  defp do_dump(%{by_pattern: by_pattern}) do
    Hotsoup.Logger.info ["dict: ", by_pattern]
  end
end
