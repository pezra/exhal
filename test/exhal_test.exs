Code.require_file "../test_helper.exs", __ENV__.file

defmodule ExHalFacts do
  use ExUnit.Case, async: true
  doctest ExHal

  alias ExHal.Document, as: Document

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
      assert {:ok, [%ExHal.Link{href: "http://example.com", templated: false}] } =
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
                                href: "http://example.com",
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
      assert {:ok, [%ExHal.Link{href: "http://example.com"}] } =
        ExHal.fetch(doc, "http://example.com/rels/foo")
    end

    test "links can be fetched by curied rels" do
      assert {:ok, [%ExHal.Link{href: "http://example.com"}] } =
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
      assert {:ok, [%ExHal.Link{href: "http://example.com/{?q}", templated: true}] } =
        ExHal.fetch(doc, "search")
    end

  end


    defmodule HttpRequesting do
    use ExUnit.Case, async: false
    use ExVCR.Mock, adapter: ExVCR.Adapter.Hackney

    setup_all do
      ExVCR.Config.cassette_library_dir(__DIR__, __DIR__)
      :ok
    end

    test ".follow_link w/ normal link" do
      stub_request "http://example.com/", fn ->
        assert {:ok, (target = %Document{})} = ExHal.follow_link(doc, "single")

        assert {:ok, "http://example.com/"} = ExHal.url(target)
      end
    end

    test ".follow_link w/ templated link" do
      stub_request "http://example.com/?q=test", fn ->
       assert {:ok, (target = %Document{})} =
          ExHal.follow_link(doc, "tmpl", tmpl_vars: %{q: "test"})

        assert {:ok, "http://example.com/?q=test"} = ExHal.url(target)
      end
    end

    test ".follow_link w/ embedded link" do
      stub_request "http://example.com/embedded", fn ->
        assert {:ok, (target = %Document{})} =
          ExHal.follow_link(doc, "embedded")

        assert {:ok, "http://example.com/e"} = ExHal.url(target)
      end
    end

    test ".follow_link w/ non-existent rel" do
      assert {:error, %ExHal.Error{}} = ExHal.follow_link(doc, "absent")
    end

    test ".follow_link w/ multiple links" do
      assert {:error, %ExHal.Error{}} = ExHal.follow_link(doc, "multiple")
    end

    test ".follow_link w/ multiple links and volunteer" do
      stub_request "~r/http:\/\/example.com\/[12]/", fn ->
        assert {:ok, (target = %Document{})} =
          ExHal.follow_link(doc, "multiple", pick_volunteer: true)

        assert {:ok, _} = ExHal.url(target)
      end
    end


    test ".follow_links w/ single link" do
      stub_request "http://example.com/", fn ->
        assert [{:ok, (target = %Document{})}] = ExHal.follow_links(doc, "single")

        assert {:ok, "http://example.com/"} = ExHal.url(target)

      end
    end

    test ".follow_links w/ templated link" do
      stub_request "http://example.com/?q=test", fn ->
       assert [{:ok, (target = %Document{})}] =
          ExHal.follow_links(doc, "tmpl", tmpl_vars: %{q: "test"})

        assert {:ok, "http://example.com/?q=test"} = ExHal.url(target)
      end
    end

    test ".follow_links w/ embedded link" do
      stub_request "http://example.com/embedded", fn ->
        assert [{:ok, (target = %Document{})}] =
          ExHal.follow_links(doc, "embedded")

        assert {:ok, "http://example.com/e"} = ExHal.url(target)
      end
    end

    test ".follow_links w/ non-existent rel" do
      assert {:error, %ExHal.Error{}} = ExHal.follow_links(doc, "absent")
    end

    test ".follow_links w/ multiple links" do
      # exvcr fail
    end

    defp doc do
      ExHal.Document.from_parsed_hal(
        %{"_links" =>
           %{"single" => %{ "href" => "http://example.com/" },
             "tmpl" => %{ "href" => "http://example.com/{?q}", "templated" => true },
             "multiple" => [%{ "href" => "http://example.com/1" },
                            %{ "href" => "http://example.com/2" }]
            },
          "_embedded" =>
            %{"embedded" => %{"_links" => %{"self" => %{"href" => "http://example.com/e"}}}}
         }
      )
    end

    def hal_str(url) do
      """
      { "name": "#{url}",
        "_links": {
          "self": { "href": "#{url}" }
        }
      }
      """
    end

    def stub_request(url, block) do
      use_cassette :stub, [url: url, body: hal_str(url), status_code: 200] do
        block.()
      end
    end


    def stub_post_request(link, opts \\ %{}, block) do
      {:ok, url} = Link.target_url(link)
      resp = Dict.get opts, :resp, fn (_) -> hal_str(url) end

      use_cassette :stub, [url: url, method: "post", body: resp, status_code: 201]  do
        block.()
      end
    end
  end

  # Background

  defp assert_is_hal_document(actual)  do
    assert %ExHal.Document{properties: _, links: _} = actual
  end
end
