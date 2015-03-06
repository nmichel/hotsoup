defmodule DSL do
  defp transform({:with_key, key}) when is_binary(key) do
    Macro.to_string(key) <> ":_"
  end
  defp transform({:with_key, frag}) do
    quote do
      unquote(frag) <> ":_"
    end
  end
  defp transform({:with_value, val}) when is_binary(val) or is_binary(val) do
    "_:" <> Macro.to_string(val)
  end
  defp transform({:with_value, frag}) do
    quote bind_quoted: [frag: transform(frag)] do
      "_:" <> frag
    end
  end
  defp transform(:any) do
    "*"
  end
  defp transform(:true) do
    "true"
  end
  defp transform(false) do
    "false"
  end
  defp transform(frag) when is_number(frag) or is_binary(frag) do
    Macro.to_string(frag)
  end
  defp transform(frag) do
    frag
  end
  
  defmacro list(entries) do
    entries = Enum.map(entries, &transform/1)
    quote bind_quoted: [entries: entries] do
      base = "[" <> Enum.at(entries, 0)
      Enum.reduce(Enum.drop(entries, 1), base, fn(exp, acc) ->
                                                 acc <> "," <> exp
                                               end)
      <> "]"
    end
  end
  
  defmacro object(constraints) do
    constraints = Enum.map(constraints, &transform/1)
    quote bind_quoted: [constraints: constraints] do
      base = "{" <> Enum.at(constraints, 0)
      Enum.reduce(Enum.drop(constraints, 1), base, fn(exp, acc) ->
                                                     acc <> "," <> exp
                                                   end)
      <> "}"
    end
  end
end


# import DSL

# toto = fn -> 
#   "42"
# end

# list [1, foo.(), 3]
# list [:any, 2, 3]
# list [:any, "foo", 3]

# object with_value: list([1, 2, :any]),
#        with_key: toto.()

defmodule Monitor do
  use Hotsoup.Client.Facade
  import DSL

  defmodule Bar do
    def toto do
      "\"42\""
    end
  end

  @object object with_value: list([1, 2, :any]),
                 with_key:   Bar.toto()
  match @object, state do
    {:stop, :object}
  end

  @capturelist "[(?<val>_)]"
  @simplelist  list([1, :any, 42])

  @expr "42"
  match @expr, state do
    {:stop, state}
  end

  @expr "\"foo\""
  match @expr, state do
    {:stop, state}
  end

  match @capturelist, state,
    when: val == ["bar"]
  do
    {:stop, :bar}
  end
  match @capturelist, state,
    when: val == ["foo"]
  do
    {:stop, :foo}
  end
  match @capturelist, state do
    {:stop, :catchall}
  end
  
  match @simplelist, state do
    {:stop, :toto}
  end
end
