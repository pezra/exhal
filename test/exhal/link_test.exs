defmodule ExHal.LinkTest do
  use ExUnit.Case, async: true
  use ExVCR.Mock, adapter: ExVCR.Adapter.Hackney

  alias ExHal.Link, as: Link
  alias ExHal.Document, as: Document

  test ".from_links_entry w/ explicit href" do
    link_entry = %{"href" => "http://example.com",
                   "templated" => false,
                   "name" => "test"}
    link = Link.from_links_entry("foo", link_entry)

    assert %Link{href: "http://example.com"} = link
    assert %Link{templated: false}           = link
    assert %Link{name: "test"}               = link
    assert %Link{rel: "foo"}                 = link
  end

  test ".from_links_entry w/ templated href" do
    link_entry = %{"href" => "http://example.com{?q}",
                   "templated" => true,
                   "name" => "test"}
    link = Link.from_links_entry("foo", link_entry)

    assert %Link{href: "http://example.com{?q}"} = link
    assert %Link{templated: true}                = link
    assert %Link{name: "test"}                   = link
    assert %Link{rel: "foo"}                     = link
  end

  test ".from_embedded w/o self link" do
    embedded_doc = Document.from_parsed_hal(ExHal.client, %{ "name" => "foo" })
    link = Link.from_embedded("foo", embedded_doc)

    assert %Link{href: nil}         = link
    assert %Link{templated: false}  = link
    assert %Link{name: nil}         = link
    assert %Link{rel: "foo"}        = link
  end

  test ".from_embedded w/ self link" do
    parsed_hal = %{ "name" => "foo",
                    "_links" => %{
                      "self" => %{ "href" => "http://example.com" }
                            }
                  }
    embedded_doc = Document.from_parsed_hal(ExHal.client, parsed_hal)
    link = Link.from_embedded("foo", embedded_doc)

    assert %Link{href: "http://example.com"} = link
    assert %Link{templated: false}           = link
    assert %Link{name: nil}                  = link
    assert %Link{rel: "foo"}                 = link
  end

  test ".target_url w/ untemplated link w/ vars" do
    assert {:ok, "http://example.com/"} = Link.target_url(normal_link,
                                                          %{q: "hello"})
  end

  test ".target_url w/ untemplated link w/o vars" do
    assert {:ok, "http://example.com/"} = Link.target_url(normal_link)
  end

  test ".target_url w/ templated link" do
    assert {:ok, "http://example.com/?q=hello"} = Link.target_url(templated_link,
                                                                  %{q: "hello"})
  end

  test ".embedded?" do
    assert true == Link.embedded?(%Link{target: %Document{}})
    assert false == Link.embedded?(%Link{href: "https://aa/resource"})
  end

  defmodule HttpRequesting do
    use ExUnit.Case, async: false
    use ExVCR.Mock, adapter: ExVCR.Adapter.Hackney

    setup do
      client = %ExHal.Client{}
      {:ok, [client: client,
             embedded_link: ExHal.LinkTest.embedded_link(client)]}
    end

    test ".follow w/ normal link", context do
      stub_request "http://example.com/", fn ->
        assert {:ok, (target = %Document{})} = Link.follow(ExHal.LinkTest.normal_link, context[:client])
        assert {:ok, "http://example.com/"} = ExHal.url(target)
      end
    end

    test ".follow w/ templated link", context do
      stub_request "http://example.com/?q=test", fn ->
        link = ExHal.LinkTest.templated_link("http://example.com/{?q}")

        assert {:ok, (target = %Document{})} = Link.follow(link, context[:client], tmpl_vars: [q: "test"])
        assert {:ok, "http://example.com/?q=test"} = ExHal.url(target)
      end
    end

    test ".follow w/ embedded link", context do
      stub_request "http://example.com/embedded", fn ->
        assert {:ok, (target = %Document{})} = Link.follow(context[:embedded_link],
                                                           context[:client])
        assert {:ok, "http://example.com/embedded"} = ExHal.url(target)
      end
    end

    test ".post w/ normal link", context do
      link = ExHal.LinkTest.normal_link("http://example.com/")
      new_thing_hal = hal_str("http://example.com/new-thing")

      stub_post_request link, [resp: new_thing_hal], fn ->
        assert {:ok, (target = %Document{})} = Link.post(link, new_thing_hal, context[:client])
        assert {:ok, "http://example.com/new-thing"} = ExHal.url(target)
      end
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

      opts = Map.new(opts)
      resp = Map.get opts, :resp, fn (_) -> hal_str(url) end

      use_cassette :stub, [url: url, method: "post", request_body: resp, body: resp, status_code: 201] do
        block.()
      end
    end
  end

  def normal_link(url \\ "http://example.com/") do
    link_entry = %{"href" => url,
                   "templated" => false,
                   "name" => "test"}
    Link.from_links_entry("foo", link_entry)
  end

  def templated_link(tmpl \\ "http://example.com/{?q}") do
    link_entry = %{"href" => tmpl,
                   "templated" => true,
                   "name" => "test"}
    Link.from_links_entry("foo", link_entry)
  end

  def embedded_link(client, url \\ "http://example.com/embedded") do
    parsed_hal = %{"name" => url,
                   "_links" =>
                     %{ "self" => %{ "href" => url }
                      }
                  }
    target_doc = Document.from_parsed_hal(client, parsed_hal)

    Link.from_embedded("foo", target_doc)
  end
end
