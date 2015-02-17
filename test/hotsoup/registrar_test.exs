defmodule Hotsoup.RegistrarTest do
  use ExUnit.Case
    
  test "Can lauch a bunch of routers and wait for them to die", context do
    Process.flag(:trap_exit, true)

    range = 9000
    offset = 1000
    max = range + offset

    1..100 
    |> Enum.map(fn (_) ->
                     {:ok, pid} = Hotsoup.Registrar.get_router(%{ttl: trunc(:random.uniform * range) + offset})
                     pid
                end)

    receive do
    after
      max ->
        nil
    end
    
    assert({:ok, []} == Hotsoup.Registrar.get_stats(:routers))
  end
end
