Code.require_file "support/request_stubbing.exs", __DIR__

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
    use RequestStubbing

    setup_all do
      ExVCR.Config.cassette_library_dir(__DIR__, __DIR__)
      :ok
    end

    test ".follow_link w/ normal link" do
      stub_request "get", url: "http://example.com/", resp_body: hal_str("http://example.com/") do
        assert {:ok, (target = %Document{}), %ResponseHeader{status_code: 200}} = ExHal.follow_link(doc(), "single")

        assert {:ok, "http://example.com/"} = ExHal.url(target)
      end
    end

    test ".follow_link w/ templated link" do
      stub_request "get", url: "http://example.com/?q=test", resp_body: hal_str("http://example.com/?q=test") do
       assert {:ok, (target = %Document{}), %ResponseHeader{status_code: 200}} =
          ExHal.follow_link(doc(), "tmpl", tmpl_vars: [q: "test"])

        assert {:ok, "http://example.com/?q=test"} = ExHal.url(target)
      end
    end

    test ".follow_link w/ embedded link" do
      stub_request "get", url: "http://example.com/embedded", resp_body: hal_str("http://example.com/embedded") do
        assert {:ok, (target = %Document{}), %ResponseHeader{}} =
          ExHal.follow_link(doc(), "embedded")

        assert {:ok, "http://example.com/embedded"} = ExHal.url(target)
      end
    end

    test ".follow_link w/ non-existent rel" do
      assert {:error, %ExHal.NoSuchLinkError{}} = ExHal.follow_link(doc(), "absent")
    end

    test ".follow_link w/ malformed URL" do
      assert catch_error(ExHal.follow_link(doc("/boom"), "single"))
    end

    test ".follow_link w/ multiple links with strict true fails" do
      assert {:error, %ExHal.Error{}} = ExHal.follow_link(doc(), "multiple", strict: true)
    end

    test ".follow_link w/ multiple links" do
      stub_request "get", url: "~r/http:\/\/example.com\/[12]/", resp_body: hal_str("") do
        assert {:ok, (target = %Document{}), %ResponseHeader{status_code: 200}} =
          ExHal.follow_link(doc(), "multiple")

        assert {:ok, _} = ExHal.url(target)
      end
    end


    test ".follow_links w/ single link" do
      stub_request "get", url: "http://example.com/", resp_body: hal_str("http://example.com/") do
        assert [{:ok, (target = %Document{}), %ResponseHeader{status_code: 200}}] = ExHal.follow_links(doc(), "single")

        assert {:ok, "http://example.com/"} = ExHal.url(target)

      end
    end

    test ".follow_links w/ templated link" do
      stub_request "get", url: "http://example.com/?q=test", resp_body: hal_str("http://example.com/?q=test") do
       assert [{:ok, (target = %Document{}), %ResponseHeader{status_code: 200}}] =
          ExHal.follow_links(doc(), "tmpl", tmpl_vars: [q: "test"])

        assert {:ok, "http://example.com/?q=test"} = ExHal.url(target)
      end
    end

    test ".follow_links w/ embedded link" do
      stub_request "get", url: "http://example.com/embedded", resp_body: hal_str("http://example.com/embedded") do
        assert [{:ok, (target = %Document{}), %ResponseHeader{}}] =
          ExHal.follow_links(doc(), "embedded")

        assert {:ok, "http://example.com/embedded"} = ExHal.url(target)
      end
    end

    test ".follow_links w/ non-existent rel" do
      assert {:error, %ExHal.NoSuchLinkError{}} = ExHal.follow_links(doc(), "absent")
    end

    test ".follow_links w/ multiple links" do
      stub_request "get", url: "~r/http:\/\/example.com\/[12]/", resp_body: hal_str("") do
        ExHal.follow_links(doc(), "multiple")
        |> Enum.each(fn resp ->
          assert {:ok, target = %Document{}, %ResponseHeader{status_code: 200}} = resp
          assert {:ok, _} = ExHal.url(target)
        end)
      end
    end

    test ".follow_links w/ non-HAL responses" do
      stub_request "get", url: "~r/http:\/\/example.com\/[12]/", resp_body: "" do
        ExHal.follow_links(doc(), "multiple")
        |> Enum.each(fn resp ->
          assert {:ok, %ExHal.NonHalResponse{}, _} = resp
        end)
      end
    end

    test ".follow_links w/ non-200 status" do
      stub_request "get", url: "~r/http:\/\/example.com\/[12]/", resp_body: hal_str(""), resp_status: 500 do
        ExHal.follow_links(doc(), "multiple")
        |> Enum.each(fn resp ->
          assert {:error, %Document{}, %ResponseHeader{status_code: 500}} = resp
        end)
      end
    end

    test ".follow_links to malformed URLs" do
      assert catch_error(ExHal.follow_links(doc("/boom"), "multiple"))
    end

    test ".post w/ normal link" do
      new_thing_hal = hal_str("http://example.com/new-thing")

      stub_request "post", url: "http://example.com/", req_body: new_thing_hal, resp_body: new_thing_hal do
        assert {:ok, (target = %Document{}), %ResponseHeader{status_code: 200}} = ExHal.post(doc(), "single", new_thing_hal)

        assert {:ok, "http://example.com/new-thing"} = ExHal.url(target)
      end
    end

    test ".patch w/ normal link" do
      new_thing_hal = hal_str("http://example.com/new-thing")

      stub_request "patch", url: "http://example.com/", req_body: new_thing_hal, resp_body: new_thing_hal do
        assert {:ok, (target = %Document{}), %ResponseHeader{status_code: 200}} = ExHal.patch(doc(), "single", new_thing_hal)

        assert {:ok, "http://example.com/new-thing"} = ExHal.url(target)
      end
    end

    defp doc(base_url \\ "http://example.com/") do
      ExHal.Document.from_parsed_hal(ExHal.client,
        %{"_links" =>
          %{"single" => %{ "href" => base_url },
            "tmpl" => %{ "href" => "#{base_url}{?q}", "templated" => true },
            "multiple" => [%{ "href" => "#{base_url}1" },
              %{ "href" => "#{base_url}2" }]
            },
          "_embedded" =>
          %{"embedded" => %{"_links" => %{"self" => %{"href" => "#{base_url}embedded"}}}}
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
