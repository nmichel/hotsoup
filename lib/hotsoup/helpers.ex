defmodule Hotsoup.Helpers do
  @doc """
    Silently catch any error the wrapped code may raise.
  """
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
