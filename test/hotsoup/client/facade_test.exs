defmodule Hotsoup.Client.FacadeTest.MyClient do
  use Hotsoup.Client.Facade

  match "\"foo\"", %{case: :case1} do
    :case1
  end

  match "42", %{case: :case1} do
    :case2
  end

  match "\"foo\"", %{case: :case2} do
    :case3
  end

  match "42", %{case: :case2} do
    :case4
  end

  match "[*, (?<val>_)]", _state,
    when: List.first(val) == 42
  do
    :case5
  end

  match "42", _state do
    :case6
  end
  
  match "[*, (?<v1>_), {_: (?<v2>_)}]", _state,
    when: check_some_properties(v2),
    when: is_list(v1),
    when: List.first(Enum.reverse(v1)) == 42
  do
    :case7
  end

  match "[*, (?<v1>_), {_: (?<v2>_)}]", _state,
    when: check_some_properties(v2)
  do
    :case8
  end
  
  defp check_some_properties(l) when is_list(l) do
    l == ["foo", :foo]
  end
  defp check_some_properties(_l) do
    false
  end
end

defmodule Hotsoup.Client.FacadeTest do
  use ExUnit.Case
  alias Hotsoup.Client.FacadeTest.MyClient

  test "match first on expression, then on data", _context do
    assert :case2 == MyClient.do_match("42", :mock, %{case: :case1})
    assert :case4 == MyClient.do_match("42", :mock, %{case: :case2})
    assert :case6 == MyClient.do_match("42", :mock, :whatelse)
    assert :case1 == MyClient.do_match("\"foo\"", :mock, %{case: :case1})
    assert :case3 == MyClient.do_match("\"foo\"", :mock, %{case: :case2})
  end

  test "match when: conditions" do
    assert :case5 == MyClient.do_match("[*, (?<val>_)]", {:mock_with_captures, [val: [42, :foo]]}, %{case: :case1})
    assert :case8 == MyClient.do_match("[*, (?<v1>_), {_: (?<v2>_)}]", {:mock_with_captures, [v2: ["foo", :foo], v1: :no_match_data]}, :no_match_data)
    assert :case7 == MyClient.do_match("[*, (?<v1>_), {_: (?<v2>_)}]", {:mock_with_captures, [v1: [:bar, 42], v2: ["foo", :foo]]}, :no_match_data)
  end

  test "return :nomatch when no clause matches" do
    {:nomatch, _, _} = MyClient.do_match("\"foo\"", :mock, :no_match_data)
  end

  test "return :nomatch when no :when conditions set matches" do
    {:nomatch, _, _} = MyClient.do_match("[*, (?<val>_)]", {:mock_with_captures, [val: [:foo, 42]]}, %{case: :case1})
  end

  test "error caused when variables present in expressions are not bound" do
    {:badmatch, _} = catch_error MyClient.do_match("[*, (?<val>_)]", {:mock_with_captures, [not_val: [42]]}, :no_match_data)
    {:badmatch, _} = catch_error MyClient.do_match("[*, (?<v1>_), {_: (?<v2>_)}]", {:mock_with_captures, [v1: [:bar, 42]]}, :no_match_data)
  end

  test "error caused when variables present in expressions are not bound event if all conditions are met" do
    {:badmatch, _} = catch_error MyClient.do_match("[*, (?<v1>_), {_: (?<v2>_)}]", {:mock_with_captures, [v2: ["foo", :foo]]}, :no_match_data)
  end
  
  test "can get watched expressions" do
    assert ["\"foo\"", "42", "[*, (?<v1>_), {_: (?<v2>_)}]", "[*, (?<val>_)]"] == MyClient.expressions |> Enum.sort(&(&1 < &2))
  end
end
