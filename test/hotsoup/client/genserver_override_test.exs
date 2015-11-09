defmodule Hotsoup.Client.GenServerOverrideTest do
  use ExUnit.Case

  defmodule MyClient do
    use Hotsoup.Client.GenServer, [do_match: :renamed_do_match,
                                   nomatch: :new_no_match]

    def init(args) do
      {:ok, %{master: args[:master],
              nodes: []}}
    end

    match "42", state = %{master: master, nodes: [] = nodes} do
      send(master, {:match, :rule1})
      {:noreply, %{state | nodes: [jnode | nodes]}}
    end

    match "42", state = %{master: master, nodes: [:node42] = nodes} do
      send(master, {:match, :rule2})
      {:noreply, %{state | nodes: [jnode | nodes]}}
    end

    match "[*, (?<val>_)]", %{master: master} = state,
      when: List.first(val) == 42
    do
      send(master, {:match, :rule3})
      {:noreply, state}
    end

    def new_no_match(jnode, state) do
      {:stop, {:nomatch_renamed, jnode}, state}
    end
  end

  setup do
    Process.flag(:trap_exit, true)
    {:ok, pid} = MyClient.start_link([master: self])
    {:ok, [pid: pid]}
  end

  test "route depending on state", context do
    GenServer.cast(context[:pid], {:node, "42", :node42})
    assert_receive {:match, :rule1}

    GenServer.cast(context[:pid], {:node, "42", :other})
    assert_receive {:match, :rule2}
  end

  test "one :when cond evaluated", context do
    pid = context[:pid]
    GenServer.cast(pid, {:node, "[*, (?<val>_)]", {:ok, [v2: ["toto"], val: [42, 13]]}}) # will match
    assert_receive {:match, :rule3}
    assert Process.info(pid)[:messages] == [] # all messages processed
  end

  test "call 'no match' callback when no 'do match' clause matches", context do
    GenServer.cast(context[:pid], {:node, "DIE", :nomatch})
    assert_receive {:EXIT, _, {:nomatch_renamed, :nomatch}}
  end
end
