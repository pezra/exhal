Code.require_file "../test_helper.exs", __ENV__.file

defmodule ExHalFacts do
  use ExUnit.Case, async: true

  test "ExHal parses valid, empty HAL documents" do
    assert_is_hal_document ExHal.parse "{}"
  end

  test "ExHal parses valid, non-empty HAL documents" do
    assert_is_hal_document ExHal.parse "{}"
  end

  defmodule DocWithProperties do
    use ExUnit.Case, async: true

    defp doc, do: ExHal.parse ~s({"one": 1})

    test "properties can be retrieved" do
      assert {:ok, 1} = ExHal.fetch(doc, "one")
    end

    test "missing properties cannot be retrieved" do
      assert :error = ExHal.fetch(doc, "two")
    end
  end

  defmodule DocWithWithLinks do
    use ExUnit.Case, async: true
    defp doc, do: ExHal.parse ~s({"_links": { "profile": {"href": "http://example.com"}}})

    test "links can be fetched" do
      assert {:ok, [%ExHal.Relation{target: "http://example.com", templated: false}] } =
        ExHal.fetch(doc, "profile")
    end

    test "missing links cannot be fetched" do
      assert :error = ExHal.fetch(doc, "author")
    end
  end

  defmodule DocWithWithDuplicateLinks do
    use ExUnit.Case, async: true
    defp doc, do: ExHal.parse ~s({"_links": {
                                     "item": [
                                       {"href": "http://example.com/1"},
                                       {"href": "http://example.com/2"}
                                     ]
                                 }})

    test "links can be fetched" do
      assert {:ok, [_, _] } = ExHal.fetch(doc, "item")
    end
  end

  defmodule DocWithCuriedLinks do
    use ExUnit.Case, async: true
    defp doc, do: ExHal.parse ~s({"_links": {
                                     "app:foo": { "href": "http://example.com" },
                                     "curies": [ { "name": "app",
                                                   "href": "http://example.com/rels/{rel}",
                                                   "templated": true } ]
                                          } })

    @tag :pending
    test "links can be fetched by decuried rels" do
      assert {:ok, [%ExHal.Relation{target: "http://example.com", templated: _, name: _}] } =
        ExHal.fetch(doc, "http://example.com/rels/foo")
    end

    test "links can be fetched by curied rels" do
      assert {:ok, [%ExHal.Relation{target: "http://example.com", templated: _, name: _}] } =
        ExHal.fetch(doc, "app:foo")
    end

  end

  # Background

  defp assert_is_hal_document(actual)  do
    assert %ExHal.Document{properties: _, relations: _} = actual
  end
end
