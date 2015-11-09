defmodule Hotsoup.Client.Facade do
  defmacro __using__(opts) do
    nomatch = opts[:nomatch] || :nomatch
    domatch = opts[:do_match] || :do_match

    quote do
      import unquote(__MODULE__)
      
      @nomatch unquote(opts)[:nomatch] || :nomatch
      @domatch unquote(opts)[:do_match] || :do_match
      @matchers []
      @before_compile unquote(__MODULE__)

      def unquote(nomatch)(jnode, state) do
        {:nomatch, jnode, state}
      end

      defoverridable [{unquote(nomatch), 2}]
    end
  end

  defmacro __before_compile__(env) do
    matchers = Module.get_attribute(env.module, :matchers)
    domatch =  Module.get_attribute(env.module, :domatch)
    nomatch =  Module.get_attribute(env.module, :nomatch)

    matchers_by_exp = matchers
      |> Enum.group_by(fn({expr, state, _conds, _code}) ->
                           expr <> Macro.to_string(state)
                       end)
      |> Enum.map(fn({k, v = [{expr, state, _cond_0, _code_0}|_]}) ->
                      {{expr, state}, Enum.map(v, fn({_expr_n, _state_n, cond_n, code_n}) ->
                                                      {cond_n, code_n}
                                                  end)}
                  end)

    expressions = matchers_by_exp
      |> Stream.map(fn({{expr, _state}, _conds_code}) -> expr end)
      |> Enum.uniq

    match_defs =
      for {{expr, state}, conds_code} <- matchers_by_exp do
        bindings = expr |> extract_capture_names |> build_bindings
        body = build_body(conds_code)
        svar = Macro.var(:svar, nil)
        quote do
          def unquote(domatch)(unquote(expr), var!(jnode), unquote(svar) = unquote(state)) do
            unquote_splicing(bindings)
            unquote(body)
          end
        end
      end

    quote do
      def expressions do
        unquote(expressions)
      end

      unquote_splicing(match_defs)
       
      def unquote(domatch)(pattern, jnode, state) do
        unquote(nomatch)(jnode, state)
      end
    end
  end

  defmacro match(state, code) do
    pattern = quote do: @pattern
    quote do
      match(unquote(pattern), unquote(state), [], unquote(code))
    end
  end

  defmacro match(state, conds = [{:when, _} | _], code) do
    pattern = quote do: @pattern
    quote do
      match(unquote(pattern), unquote(state), unquote(conds), unquote(code))
    end
  end
  defmacro match(expr, state, code) do
    quote do
      match(unquote(expr), unquote(state), [], unquote(code))
    end
  end

  defmacro match(expr, state, conds, [do: code]) do
    quote bind_quoted: [expr: expr,
                        state: Macro.escape(state),
                        conds: Macro.escape(conds),
                        code: Macro.escape(code)] do
      @matchers [{expr, state, conds, code} | @matchers]
    end
  end

  defp extract_capture_names(expr) do
    Regex.compile("\\(\\?<([A-Za-z0-9_]+)>[^\\)]*\\)")
    |> elem(1)
    |> Regex.scan(expr, [capture: :all_but_first])
    |> List.flatten
  end

  defp build_bindings(vars) do
    vars
    |> Enum.map(fn(name) ->
                    va = String.to_atom(name)
                    v = Macro.var(va, nil)
                    quote do
                      cap = elem(var!(jnode), 1)
                      l =
                        case Keyword.fetch(cap, unquote(va)) do
                          :error ->
                            {_, val} = Enum.find(cap, &(elem(&1, 0) == unquote(name)))
                            val
                          {:ok, val} ->
                            val
                        end
                      unquote(v) = l
                    end
                end)
  end

  defp build_body([]) do
    quote bind_quoted: [svar: Macro.var(:svar, nil),
                        jnode: Macro.var(:jnode, nil)] do
      Kernel.apply(__MODULE__, @nomatch, [svar, jnode]) 
    end
  end
  defp build_body([{conds, code} | tail]) do
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

  defp build_if_conds(conds) do
    conds
    |> Enum.reduce(true,
                   fn({:when, c}, acc) ->
                       quote do
                         unquote(acc) and unquote(c)
                       end
                   end)
  end
end
