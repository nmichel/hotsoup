defmodule Hotsoup.Router do
  use GenServer
  use Hotsoup.Logger
  require Dict

  # API

  def start_link do
    GenServer.start_link __MODULE__, [], name: __MODULE__
  end

  def register(expr, target) when is_bitstring(expr) and is_pid(target) do
    GenServer.call __MODULE__, {:register, expr, target}, :infinity
  end

  def route(node) do
    GenServer.call __MODULE__, {:route, node}, :infinity
  end

  def debug(:dump) do
    GenServer.call __MODULE__, {:debug, :dump}, :infinity
  end

  ## GenServer Callbacks

  def init(_opts) do
    Hotsoup.Logger.info(["started"])
    Process.flag :trap_exit, true
    {:ok, %{by_pattern: %{}}}
  end

  def handle_call({:register, pattern, target}, from, state) do
    Hotsoup.Logger.debug(["Processing register ", pattern])
    state = register(state, pattern, target)
    {:reply, :ok, state}
  end

  def handle_call({:route, node}, from, state) do
    Hotsoup.Logger.debug(["Processing route ", node ])
    route(state, node)
    {:reply, :ok, state}
  end

  def handle_call({:debug, :dump}, from, state) do
    dump(state)
    {:reply, :ok, state}
  end

  def handle_info({:EXIT, target, reason}, state) do
    state = unregister(state, target)
    {:noreply, state}
  end

  defp register(state = %{by_pattern: by_pattern}, pattern, target) do
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

  defp unregister(state = %{by_pattern: by_pattern}, target) do
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

  defp route(state = %{by_pattern: by_pattern}, node) do
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

  defp dump(%{by_pattern: by_pattern}) do
    Hotsoup.Logger.info ["dict: ", by_pattern]
  end
end
