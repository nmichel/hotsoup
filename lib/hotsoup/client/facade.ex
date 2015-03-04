defmodule Hotsoup.Client.Facade do
  defmacro __using__(_opts) do
    quote do
      def nomatch(jnode, state) do
        {:nomatch, jnode, state}
      end

      defoverridable [nomatch: 2]

      import unquote(__MODULE__)

      @matchers []
      @before_compile unquote(__MODULE__)
    end
  end
  
  defmacro __before_compile__(_env) do
    quote unquote: false do
      @matchers_by_exp @matchers |> Enum.group_by(fn({k, _expr, _state, _conds, _code}) ->
                                                      k
                                                  end)
                                 |> Enum.map(fn({k, v = [{_k, expr, state, _cond_0, _code_0}|_]}) ->
                                                 {{expr, state}, Enum.map(v, fn({_k, _expr_n, _state_n, cond_n, code_n}) ->
                                                                                 {cond_n, code_n}
                                                                             end)}
                                             end)

      @expressions Stream.map(@matchers_by_exp, fn({{expr, _state}, _conds_code}) -> expr end)
                   |> Enum.uniq

      def expressions do
        @expressions
      end

      @matchers_by_exp
      |> Enum.each fn({{expr, state}, conds_code}) ->
                       bindings = expr |> extract_capture_names |> build_bindings
                       body = build_body(conds_code)
                       svar = Macro.var(:svar, nil)
                       def do_match(unquote(expr), var!(jnode), unquote(svar) = unquote(state)) do
                         unquote_splicing(bindings)
                         unquote(body)
                       end
                   end

      def do_match(pattern, jnode, state) do
        nomatch(jnode, state)
      end
    end
  end

  defmacro match(expr, state, code) do
    quote do
      match(unquote(expr), unquote(state), [], unquote(code))
    end
  end

  defmacro match(expr, state, conds, [do: code]) do
    quote bind_quoted: [key: expr <> Macro.to_string(state),
                        expr: Macro.escape(expr),
                        state: Macro.escape(state),
                        conds: Macro.escape(conds),
                        code: Macro.escape(code)] do
      @matchers [{key, expr, state, conds, code} | @matchers]
    end
  end

  def extract_capture_names(expr) do
    Regex.compile("\\(\\?<([A-Za-z0-9_]+)>[^\\)]*\\)")
    |> elem(1)
    |> Regex.scan(expr, [capture: :all_but_first])
    |> List.flatten
  end

  def build_bindings(vars) do
    vars
    |> Enum.map(fn(name) ->
                    va = String.to_atom(name)
                    v = Macro.var(va, nil)
                    quote do
                      {:ok, l} = Keyword.fetch(elem(var!(jnode), 1), unquote(va))
                      unquote(v) = l
                    end
                end)
  end

  def build_body([]) do
    quote bind_quoted: [svar: Macro.var(:svar, nil),
                        jnode: Macro.var(:jnode, nil)] do
      nomatch(svar, jnode)
    end
  end
  def build_body([{conds, code} | tail]) do
    ifcond = build_if_conds(conds)
    elsebody = build_body(tail)
    quote do
      if unquote(ifcond) do
        unquote(code)
      else
        unquote(elsebody)
      end
    end
  end

  def build_if_conds(conds) do
    conds
    |> Enum.reduce(true,
                   fn({:when, c}, acc) ->
                       quote do
                         unquote(acc) and unquote(c)
                       end
                   end)
  end
end
