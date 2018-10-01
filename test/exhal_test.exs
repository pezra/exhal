defmodule ExHalTest do
  use ExUnit.Case, async: true

  alias ExHal.Document
  alias ExHal.ResponseHeader

  defmodule DocWithProperties do
    use ExUnit.Case, async: true

    defp doc, do: Document.parse! ExHal.client, ~s({"one": 1})

    test "properties can be retrieved" do
      assert {:ok, 1} = ExHal.fetch(doc(), "one")
    end

    test "missing properties cannot be retrieved" do
      assert :error = ExHal.fetch(doc(), "two")
    end
  end

  defmodule UrlFuncTest do
    use ExUnit.Case, async: true

    test "URL can be determined with self link" do
      assert {:ok, "http://example.com"} = ExHal.url(doc_with_self_link())
    end

    test "URL cannot be determined without self link" do
      assert :error = ExHal.url(doc_sans_self_link())
    end


    defp doc_with_self_link do
      Document.parse! ExHal.client, ~s({"_links": { "self": {"href": "http://example.com"}}})
    end
    defp doc_sans_self_link do
      Document.parse! ExHal.client, ~s({"_links": { }})
    end
  end

  defmodule DocWithWithLinks do
    use ExUnit.Case, async: true
    defp doc, do: Document.parse! ExHal.client, ~s({"_links": { "profile": {"href": "http://example.com"}}})

    test "links can be fetched" do
      assert {:ok, [%ExHal.Link{href: "http://example.com", templated: false}] } =
        ExHal.fetch(doc(), "profile")
    end

    test "urls can be extracted from links" do
      assert {:ok, "http://example.com"} =
        ExHal.link_target(doc(), "profile")
    end

    test "missing links cannot be fetched" do
      assert :error = ExHal.fetch(doc(), "author")
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
        ExHal.fetch(doc(), "profile")
    end

    test "missing links cannot be fetched" do
      assert :error = ExHal.fetch(doc(), "author")
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
      assert {:ok, [_, _] } = ExHal.fetch(doc(), "item")
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
        ExHal.fetch(doc(), "http://example.com/rels/foo")
    end

    test "links can be fetched by curied rels" do
      assert {:ok, [%ExHal.Link{href: "http://example.com"}] } =
        ExHal.fetch(doc(), "app:foo")
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
        ExHal.fetch(doc(), "search")
    end

  end


  defmodule HttpRequesting do
    use ExUnit.Case, async: false
    import Mox
    setup :verify_on_exit!

    test ".follow_link w/ normal link" do
      ExHal.ClientMock
      |> expect(:get, fn _client, "http://example.com/", _headers ->
        {:ok, Document.parse!(hal_str("http://example.com/")), %ResponseHeader{status_code: 200}}
      end)

      assert {:ok, (repr = %Document{}), %ResponseHeader{status_code: 200}} = ExHal.follow_link(doc(), "single")
      assert {:ok, "http://example.com/"} = ExHal.url(repr)
    end

    test ".follow_link w/ templated link" do
      ExHal.ClientMock
      |> expect(:get, fn _client, "http://example.com/?q=test", _headers ->
        {:ok, Document.parse!(hal_str("http://example.com/?q=test")), %ResponseHeader{status_code: 200}}
      end)

      assert {:ok, (repr = %Document{}), %ResponseHeader{status_code: 200}} = ExHal.follow_link(doc(), "tmpl", tmpl_vars: [q: "test"])
      assert {:ok, "http://example.com/?q=test"} = ExHal.url(repr)
    end

  test ".follow_link w/ embedded link" do
      assert {:ok, (repr = %Document{}), %ResponseHeader{}} = ExHal.follow_link(doc(), "embedded")
      assert {:ok, "http://example.com/embedded"} = ExHal.url(repr)
    end

    test ".follow_link w/ non-existent rel" do
      assert {:error, %ExHal.Error{}} = ExHal.follow_link(doc(), "absent")
    end

    test ".follow_link w/ multiple links with strict true fails" do
      assert {:error, %ExHal.Error{}} = ExHal.follow_link(doc(), "multiple", strict: true)
    end

    test ".follow_link w/ multiple links" do
      ExHal.ClientMock
      |> stub(:get, fn _client, "http://example.com/"<>id, _opts ->
        {:ok, Document.parse!(hal_str("http://example.com/#{id}")), %ResponseHeader{status_code: 200}}
      end)

      assert {:ok, (repr = %Document{}), %ResponseHeader{status_code: 200}} = ExHal.follow_link(doc(), "multiple")
      assert {:ok, _} = ExHal.url(repr)
    end


    test ".follow_links w/ single link" do
      ExHal.ClientMock
      |> expect(:get, fn _client, "http://example.com/", _headers ->
        {:ok, Document.parse!(hal_str("http://example.com/")), %ResponseHeader{status_code: 200}}
      end)

      assert [{:ok, (target = %Document{}), %ResponseHeader{status_code: 200}}] = ExHal.follow_links(doc(), "single")
      assert {:ok, "http://example.com/"} = ExHal.url(target)
    end

    test ".follow_links w/ templated link" do
      ExHal.ClientMock
      |> expect(:get, fn _client, "http://example.com/?q=test", _headers ->
        {:ok, Document.parse!(hal_str("http://example.com/?q=test")), %ResponseHeader{status_code: 200}}
      end)

      assert [{:ok, (target = %Document{}), %ResponseHeader{status_code: 200}}] = ExHal.follow_links(doc(), "tmpl", tmpl_vars: [q: "test"])
      assert {:ok, "http://example.com/?q=test"} = ExHal.url(target)
    end

    test ".follow_links w/ embedded link" do
      assert [{:ok, (target = %Document{}), %ResponseHeader{}}] = ExHal.follow_links(doc(), "embedded")
      assert {:ok, "http://example.com/embedded"} = ExHal.url(target)
    end

    test ".follow_links w/ non-existent rel" do
      assert [{:error, %ExHal.Error{}}] = ExHal.follow_links(doc(), "absent")
    end

    test ".follow_links w/ multiple links" do
      # exvcr fail
    end

    test ".post w/ normal link" do
      new_thing_hal = hal_str("http://example.com/new-thing")

      ExHal.ClientMock
      |> expect(:post, fn _client, "http://example.com/", new_thing_hal, _headers ->
        {:ok, Document.parse!(new_thing_hal), %ResponseHeader{status_code: 200}}
      end)

      assert {:ok, (target = %Document{}), %ResponseHeader{status_code: 200}} = ExHal.post(doc(), "single", new_thing_hal)
      assert {:ok, "http://example.com/new-thing"} = ExHal.url(target)
    end

    test ".patch w/ normal link" do
      new_thing_hal = hal_str("http://example.com/new-thing")

      ExHal.ClientMock
      |> expect(:patch, fn _client, "http://example.com/", new_thing_hal, _headers ->
        {:ok, Document.parse!(new_thing_hal), %ResponseHeader{status_code: 200}}
      end)

      assert {:ok, (target = %Document{}), %ResponseHeader{status_code: 200}} = ExHal.patch(doc(), "single", new_thing_hal)

      assert {:ok, "http://example.com/new-thing"} = ExHal.url(target)
    end

    defp doc do
      ExHal.Document.from_parsed_hal(ExHal.client,
        %{"_links" =>
           %{"single" => %{ "href" => "http://example.com/" },
             "tmpl" => %{ "href" => "http://example.com/{?q}", "templated" => true },
             "multiple" => [%{ "href" => "http://example.com/1" },
                            %{ "href" => "http://example.com/2" }]
            },
          "_embedded" =>
            %{"embedded" => %{"_links" => %{"self" => %{"href" => "http://example.com/embedded"}}}}
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

  end

end
