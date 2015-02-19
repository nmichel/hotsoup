defmodule Hotsoup.Helpers do
  defmacro no_error(do: code) do
    quote do
      try do
        unquote(code)
      catch
        _e, _r -> nil
      end
    end
  end
end
