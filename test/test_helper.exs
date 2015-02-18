ExUnit.start()

defmodule Helper do
  defmacro wait(ms) do
    quote do
      receive do
      after
        unquote(ms) ->
          nil
      end
    end
  end

  defmacro wait_for_msg() do
    quote do
      receive do
        m -> m
      end
    end
  end
end
