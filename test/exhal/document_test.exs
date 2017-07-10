Code.require_file "../../test_helper.exs", __ENV__.file

defmodule ExHal.DocumentTest do
  use ExUnit.Case, async: true

  alias ExHal.Document

  setup do
    {:ok, %{client: ExHal.client}}
  end

  test "ExHal parses valid, empty HAL documents", %{client: client} do
    assert Document.parse!(client, "{}") |> is_hal_doc?
  end

  test "ExHal parses valid, non-empty HAL documents", %{client: client} do
    assert Document.parse!(client, "{}") |> is_hal_doc?
  end

  defmodule UrlFuncTest do
    use ExUnit.Case, async: true

    test "URL can be determined with self link" do
      assert {:ok, "http://example.com"} = Document.url(doc_with_self_link())
    end

    test "URL cannot be determined without self link" do
      assert :error = Document.url(doc_sans_self_link())
    end


    defp doc_with_self_link do
      Document.parse! ExHal.client, ~s({"_links": { "self": {"href": "http://example.com"}}})
    end
    defp doc_sans_self_link do
      Document.parse! ExHal.client, ~s({"_links": { }})
    end
  end

  test ".to_json_hash", %{client: client} do
    parsed_hal = %{
      "name" => "My Name",
      "_embedded" => %{ "test" => %{"_embedded" => %{}, "_links" => %{}, "name" => "Is Test"}},
      "_links" => %{ "self" => %{"href" => "http://example.com/my-name"},
                     "foo" => [
                       %{"href" => "http://example.com/my-name"},
                       %{"href" => "http://example.com/my-foo"},
                     ]}}

    exhal_doc = Document.from_parsed_hal(client, parsed_hal)
    assert ^parsed_hal = Document.to_json_hash(exhal_doc)
  end

  test "parsing with null links", %{client: client} do
    parsed_hal = %{
      "name" => "My Name",
      "_links" => %{ "self" => %{"href" => "http://example.com/my-name"},
                     "foo" => %{"href" => nil}
                    }}

    exhal_doc = Document.from_parsed_hal(client, parsed_hal)
    refute exhal_doc |> Document.has_link?("foo")
  end

  defmodule DocWithProperties do
    use ExUnit.Case, async: true

    defp doc, do: Document.parse! ExHal.client, ~s({"one": 1})

    test "properties can be fetched" do
      assert {:ok, 1} == Document.fetch(doc(), "one")
    end

    test "get(doc(), real_prop)" do
      assert 1 == Document.get(doc(), "one")
    end

    test "get_property(doc(), real_prop)" do
      assert 1 == Document.get_property(doc(), "one")
    end

    test "missing properties cannot be fetched" do
      assert :error == Document.fetch(doc(), "two")
    end

    test "get(doc(), missing_prop)" do
      assert nil == Document.get(doc(), "two")
    end

    test "get(doc(), missing_prop, default)" do
      assert :hello == Document.get(doc(), "two", :hello)
    end

    test "get_property(doc(), missing_prop)" do
      assert nil == Document.get_property(doc(), "two")
    end

    test "get_property(doc(), missing_prop, default)" do
      assert :hello == Document.get_property(doc(), "two", :hello)
    end

    test "can be rendered" do
      assert is_binary(Document.render!(doc()))
      assert String.contains?(Document.render!(doc()), ~s("one":))
      assert doc() == Document.parse!(Document.render!(doc()))
    end

    test "Poison.Encoder.encode(doc)" do
      assert is_binary(Poison.encode!(doc()))
      assert String.contains?(Poison.encode!(doc()), ~s("one":))
      assert doc() == Document.parse!(Poison.encode!(doc()))
    end

  end


  defmodule DocWithWithLinks do
    use ExUnit.Case, async: true

    @doc_str ~s({"_links": { "profile": {"href": "http://example.com"}}})

    defp doc, do: Document.parse! ExHal.client, @doc_str

    test "links can be fetched" do
      assert {:ok, [%ExHal.Link{href: "http://example.com", templated: false}] } =
        Document.fetch(doc(), "profile")
    end

    test "missing links cannot be fetched" do
      assert :error = Document.fetch(doc(), "author")
    end

    test "get_links(doc(), present_rel)" do
      assert [%ExHal.Link{href: "http://example.com", templated: false}] = Document.get_links(doc(), "profile")
    end

    test "get_links(doc(), absent_rel)" do
      assert [] = Document.get_links(doc(), "absent_rel")
    end

    test "get_links(doc(), absent_rel, :missing)" do
      assert :missing = Document.get_links(doc(), "absent_rel", :missing)
    end

    test "can be rendered" do
      assert is_binary(Document.render!(doc()))
      assert String.contains?(Document.render!(doc()), ~s("_links":))
      assert doc() == Document.parse!(Document.render!(doc()))
    end
  end

  defmodule DocWithWithEmbeddedLinks do
    use ExUnit.Case, async: true
    defp doc, do: Document.parse! ExHal.client, ~s({"_embedded": {
                                     "profile": {
                                       "name": "Peter",
                                       "_links": {
                                         "self": { "href": "http://example.com"}
                                       }}}})

    test "embeddeds can be fetched" do
      assert {:ok, [%ExHal.Link{target: %ExHal.Document{},
                                href: "http://example.com",
                                templated: false}] } =
        Document.fetch(doc(), "profile")
    end

    test "missing links cannot be fetched" do
      assert :error = Document.fetch(doc(), "author")
    end

    test "can be rendered" do
      assert is_binary(Document.render!(doc()))
      assert String.contains?(Document.render!(doc()), ~s("_embedded":))
      assert doc() == Document.parse!(Document.render!(doc()))
    end
  end

  defmodule DocWithWithDuplicateLinks do
    use ExUnit.Case, async: true
    defp doc, do: Document.parse! ExHal.client, ~s({"_links": {
                                     "item": [
                                       {"href": "http://example.com/1"},
                                       {"href": "http://example.com/2"}
                                     ]
                                 }})

    test "links can be fetched" do
      assert {:ok, [_, _] } = Document.fetch(doc(), "item")
    end
  end

  defmodule DocWithCuriedLinks do
    use ExUnit.Case, async: true
    defp doc, do: Document.parse! ExHal.client, ~s({"_links": {
                                     "app:foo": { "href": "http://example.com" },
                                     "curies": [ { "name": "app",
                                                   "href": "http://example.com/rels/{rel}",
                                                   "templated": true } ]
                                          } })

    test "links can be fetched by decuried rels" do
      assert {:ok, [%ExHal.Link{href: "http://example.com"}] } =
        Document.fetch(doc(), "http://example.com/rels/foo")
    end

    test "links can be fetched by curied rels" do
      assert {:ok, [%ExHal.Link{href: "http://example.com"}] } =
        Document.fetch(doc(), "app:foo")
    end

  end

  defmodule DocWithTemplatedLinks do
    use ExUnit.Case, async: true
    defp doc, do: Document.parse! ExHal.client, ~s(
                                    {"_links": {
                                     "search": { "href": "http://example.com/{?q}",
                                                 "templated": true }
                                          } } )

    test "templated links can be fetched" do
      assert {:ok, [%ExHal.Link{href: "http://example.com/{?q}", templated: true}] } =
        Document.fetch(doc(), "search")
    end

  end

  # Background

  defp is_hal_doc?(actual)  do
    %ExHal.Document{properties: _, links: _} = actual
  end

end
