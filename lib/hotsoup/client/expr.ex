defmodule Hotsoup.Client.Expr do
  defmacro __using__(_opts) do
    quote do
      import unquote(__MODULE__)
    end
  end

  defp transform({:with_key, key}) when is_binary(key) do
    Macro.to_string(key) <> ":_"
  end
  defp transform({:with_key, frag}) do
    quote do
      unquote(frag) <> ":_"
    end
  end
  defp transform({:with, [key: fragk]}) do
    transform({:with_key, fragk})
  end
  defp transform({:with, [value: fragv]}) do
    transform({:with_value, fragv})
  end
  defp transform({:with, [key: fragk, value: fragv]}) do
    quote bind_quoted: [fragk: transform(fragk),
                        fragv: transform(fragv)] do
      fragk <> ":" <> fragv
    end
  end
  defp transform({:with, [value: fragv, key: fragk]}) do
    transform({:with, [key: fragk, value: fragv]})
  end
  defp transform({:with_value, val}) when is_binary(val) do
    "_:" <> Macro.to_string(val)
  end
  defp transform({:with_value, frag}) do
    quote bind_quoted: [frag: transform(frag)] do
      "_:" <> frag
    end
  end
  defp transform(:any) do
    "_"
  end
  defp transform(:some) do
    "*"
  end
  defp transform(:true) do
    "true"
  end
  defp transform(:false) do
    "false"
  end
  defp transform(:null) do
    "null"
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
      base = "[" <> (Enum.at(entries, 0) || "")
      Enum.reduce(Enum.drop(entries, 1), base, fn(exp, acc) ->
                                                 acc <> "," <> exp
                                               end)
      <> "]"
    end
  end
  
  defmacro object(constraints) do
    constraints = Enum.map(constraints, &transform/1)
    quote bind_quoted: [constraints: constraints] do
      base = "{" <> (Enum.at(constraints, 0) || "")
      Enum.reduce(Enum.drop(constraints, 1), base, fn(exp, acc) ->
                                                     acc <> "," <> exp
                                                   end)
      <> "}"
    end
  end
  
  defmacro capture(frag, [as: name]) when is_atom(name) do
    quote do
      capture(unquote(frag), [as: unquote(to_string(name))])
    end
  end
  defmacro capture(frag, [as: name]) do
    quote bind_quoted: [name: name,
                        frag: transform(frag)] do
      "(?<" <> name <> ">" <> frag <> ")"
    end
  end
  
  defp default_modifiers do
    [deep: false, global: false]
  end
  
  defmacro set(constraints) do
    quote do
      set(unquote(constraints), [])
    end
  end
  
  defmacro set(constraints, modifiers) do
    modifiers = Keyword.merge(default_modifiers, modifiers)
    {:ok, deep?} = Keyword.fetch(modifiers, :deep)
    {:ok, global?} = Keyword.fetch(modifiers, :global)
    constraints = Enum.map(constraints, &transform/1)

    quote bind_quoted: [constraints: constraints,
                        deep?: deep?,
                        global?: global?] do

      open = deep? && "<!" || "<"
      close = deep? && "!>" || ">"
      ending = global? && "/g" || ""
      base = Enum.at(constraints, 0) || ""
      
      open
      <>
      Enum.reduce(Enum.drop(constraints, 1), base, fn(exp, acc) ->
                                                     acc <> "," <> exp
                                                   end)
      <>
      close
      <>
      ending
    end
  end
end
