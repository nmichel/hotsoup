defmodule Hotsoup.Logger do
  require Enum
  require Logger

  defmacro __using__(_opts) do
    quote do
      import Logger
    end
  end

  defmacro info(what) when is_list(what) do
    quote bind_quoted: [what: what] do
      t = Enum.map(what, fn(x) when is_binary(x) -> x
                           (x) -> inspect(x) end)
      Logger.info(["#{__MODULE__} - " | t])
    end
  end

  defmacro debug(what) when is_list(what) do
    t = Enum.map(what, fn(x) when is_binary(x) -> x
                         (x) -> quote do: inspect(unquote(x)) end)
    quote do
      Logger.debug ["#{__MODULE__} - " | unquote(t)]
    end
  end
end
