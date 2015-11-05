defmodule Hotsoup.Client.FacadeOverrideTest do
  use ExUnit.Case

  defmodule MyClient do
    use Hotsoup.Client.Facade, [nomatch: :renamed]

    def renamed(jnode, state) do
      {:nomatch, jnode, state}
    end
  end

  test "can rename nomatch/2 function" do
    assert {:nomatch, _, _} = MyClient.do_match("[]", :ok, :ok)
  end

  test "when renamed nomatch/2 does not exist under it old name" do
    assert_raise UndefinedFunctionError, fn -> MyClient.nomatch(:ok, :ok, :ok) end
  end
end
