defmodule Hotsoup.Client.ExprTest do
  use ExUnit.Case
  use Hotsoup.Client.Expr

  test "static list expressions" do
    assert list([]) == "[]"
    assert list([1]) == "[1]"
    assert list([1, 42]) == "[1,42]"
    assert list([1, "foo"]) == "[1,\"foo\"]"
    assert list([:any, "foo", :some]) == "[_,\"foo\",*]"
  end
  
  test "static object expressions" do
    assert object([]) == "{}"
    assert object(with_key: "foo") == "{\"foo\":_}"
    assert object(with_value: 42) == "{_:42}"
    assert object(with_value: "foo") == "{_:\"foo\"}"
    assert object(with: [key: "foo", value: "bar"]) == "{\"foo\":\"bar\"}"
  end

  test "static capture expressions" do
    assert capture(:any, as: :val) == "(?<val>_)"
    assert capture(:any, as: "val") == "(?<val>_)"
  end
  
  test "static set expressions" do
    assert set([]) == "<>"
    assert set([], [global: true]) == "<>/g"
    assert set([], [deep: true]) == "<!!>"
    assert set([], [deep: true, global: true]) == "<!!>/g"

    assert set([set([], [deep: true])], [global: true]) == "<<!!>>/g"
  end
  
  @capname "val"
  test "dynamic expressions" do
    assert capture(:any, as: @capname) == "(?<val>_)"
    
    defmodule Config do
      def num_param do
        42
      end
      def expr(p) do
        list [:any, object(with_key: "#{inspect(p)}")]
      end
    end

    assert capture(Config.expr("foo"), as: @capname) == "(?<val>[_,{\"foo\":_}])"
    assert list([to_string(Config.num_param)]) == "[42]"
  end
  
end
