defmodule Hotsoup.Logger do
  require Logger
  
  defmacro __using__(_opts) do
    quote do
      import Logger
    end
  end

  defimpl Inspect, for: PID do
    def inspect(pid, _opts) do
      IO.iodata_to_binary(:erlang.pid_to_list(pid))
    end
  end

  defmacro info(what) when is_list(what) do
    quote bind_quoted: [what: what] do
      t = Enum.map(what, fn(x) when is_binary(x) -> x
                           (x) -> inspect(x) end)
      Logger.info([inspect(self()), " | #{__MODULE__} - " | t])
    end
  end

  defmacro debug(what) when is_list(what) do
    t = Enum.map(what, fn(x) when is_binary(x) -> x
                         (x) -> quote do: inspect(unquote(x)) end)
    quote do
      Logger.debug [inspect(self()), " | #{__MODULE__} - " | unquote(t)]
    end
  end
end
