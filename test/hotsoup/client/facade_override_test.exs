defmodule Hotsoup.Client.FacadeOverrideTest do
  use ExUnit.Case

  defmodule MyClientNoMatch do
    use Hotsoup.Client.Facade, [nomatch: :renamed_do_match]

    def renamed_do_match(jnode, state) do
      {:nomatch, jnode, state}
    end
  end

  test "can rename nomatch/2 function" do
    assert {:nomatch, _, _} = MyClientNoMatch.do_match("[]", :ok, :ok)
  end

  test "when renamed, nomatch/2 does not exist under it old name" do
    assert_raise UndefinedFunctionError, fn -> MyClientNoMatch.nomatch(:ok, :ok) end
  end

  defmodule MyClientRenameDoMatch do
    use Hotsoup.Client.Facade, [do_match: :renamed_do_match]
  end

  test "can rename do_match/3 function" do
    assert {:nomatch, _, _} = MyClientRenameDoMatch.renamed_do_match("[]", :ok, :ok)
  end

  test "when renamed, do_match/3 does not exist under it old name" do
    assert_raise UndefinedFunctionError, fn -> MyClientRenameDoMatch.do_match(:ok, :ok, :ok) end
  end

  defmodule MyClientRenameDoMatchOverrideNoMatch do
    use Hotsoup.Client.Facade, [do_match: :renamed_do_match]

    def nomatch(jnode, state) do
      {:override_no_match, jnode, state}
    end
  end

  test "default nomatch/2 still called when do_match/3 is renamed" do
    assert {:override_no_match, :ok, :ok} = MyClientRenameDoMatchOverrideNoMatch.renamed_do_match("[]", :ok, :ok)
  end

  defmodule MyClientRenameBoth do
    use Hotsoup.Client.Facade, [do_match: :renamed_do_match,
                                nomatch: :new_no_match]

    def new_no_match(jnode, state) do
      {:nomatch_renamed, jnode, state}
    end
  end

  test "can rename do_match/3 and no_match/2 functions" do
    assert {:nomatch_renamed, _, _} = MyClientRenameBoth.renamed_do_match("[]", :ok, :ok)
  end
end
