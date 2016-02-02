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

  defmodule UrlFuncTest do
    use ExUnit.Case, async: true

    test "URL can be determined with self link" do
      assert {:ok, "http://example.com"} = ExHal.url(doc_with_self_link)
    end

    test "URL cannot be determined without self link" do
      assert :error = ExHal.url(doc_sans_self_link)
    end


    defp doc_with_self_link do
      ExHal.parse ~s({"_links": { "self": {"href": "http://example.com"}}})
    end
    defp doc_sans_self_link do
      ExHal.parse ~s({"_links": { }})
    end
  end

  defmodule DocWithWithLinks do
    use ExUnit.Case, async: true
    defp doc, do: ExHal.parse ~s({"_links": { "profile": {"href": "http://example.com"}}})

    test "links can be fetched" do
      assert {:ok, [%ExHal.Link{target_url: "http://example.com", templated: false}] } =
        ExHal.fetch(doc, "profile")
    end

    test "missing links cannot be fetched" do
      assert :error = ExHal.fetch(doc, "author")
    end
  end

  defmodule DocWithWithEmbeddedLinks do
    use ExUnit.Case, async: true
    defp doc, do: ExHal.parse ~s({"_embedded": {
                                     "profile": {
                                       "name": "Peter",
                                       "_links": {
                                         "self": { "href": "http://example.com"}
                                       }}}})

    test "embeddeds can be fetched" do
      assert {:ok, [%ExHal.Link{target: %ExHal.Document{},
                                target_url: "http://example.com",
                                templated: false}] } =
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

    test "links can be fetched by decuried rels" do
      assert {:ok, [%ExHal.Link{target_url: "http://example.com", templated: _, name: _}] } =
        ExHal.fetch(doc, "http://example.com/rels/foo")
    end

    test "links can be fetched by curied rels" do
      assert {:ok, [%ExHal.Link{target_url: "http://example.com", templated: _, name: _}] } =
        ExHal.fetch(doc, "app:foo")
    end

  end

  defmodule DocWithTemplatedLinks do
    use ExUnit.Case, async: true
    defp doc, do: ExHal.parse ~s({"_links": {
                                     "search": { "href": "http://example.com/{?q}",
                                                 "templated": true }
                                          } } )

    test "templated links can be fetched" do
      assert {:ok, [%ExHal.Link{target_url: "http://example.com/{?q}", templated: true, name: _}] } =
        ExHal.fetch(doc, "search")
    end

  end

  # Background

  defp assert_is_hal_document(actual)  do
    assert %ExHal.Document{properties: _, links: _} = actual
  end
end
