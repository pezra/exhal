Code.require_file "../support/request_stubbing.exs", __DIR__

defmodule ExHal.NavigationTest do
  use ExUnit.Case, async: false
  use RequestStubbing

  alias ExHal.{Navigation,Document,Error}

  test ".follow_link", %{doc: doc} do
    thing_hal = hal_str("http://example.com/thing")

    stub_request "get", url: "http://example.com/", resp_body: thing_hal do
      assert {:ok, (target = %Document{})} =
        Navigation.follow_link(doc, "single")

      assert {:ok, "http://example.com/thing"} = ExHal.url(target)
    end

    assert {:ok, (target = %Document{})} =
      Navigation.follow_link(doc, "embedded")

    assert {:ok, "http://example.com/e"} = ExHal.url(target)
  end

  test ".post", %{doc: doc} do
    new_thing_hal = hal_str("http://example.com/new-thing")

    stub_request "post", url: "http://example.com/",
                         req_body: "post body",
                         resp_body: new_thing_hal do
      assert {:ok, (target = %Document{})} =
        Navigation.post(doc, "single", "post body")

      assert {:ok, "http://example.com/new-thing"} = ExHal.url(target)
    end
  end

  test ".put", %{doc: doc} do
    new_thing_hal = hal_str("http://example.com/new-thing")

    stub_request "put", url: "http://example.com/",
                        req_body: "put body",
                        resp_body: new_thing_hal do
      assert {:ok, (target = %Document{})} =
        Navigation.put(doc, "single", "put body")

      assert {:ok, "http://example.com/new-thing"} = ExHal.url(target)
    end
  end

  test ".patch", %{doc: doc} do
    new_thing_hal = hal_str("http://example.com/new-thing")

    stub_request "patch", url: "http://example.com/",
                        req_body: "patch body",
                        resp_body: new_thing_hal do
      assert {:ok, (target = %Document{})} =
        Navigation.patch(doc, "single", "patch body")

      assert {:ok, "http://example.com/new-thing"} = ExHal.url(target)
    end
  end

  test ".link_target", %{doc: doc} do
    assert {:ok, "http://example.com/"} = Navigation.link_target(doc, "single")

    embedded_linked_doc = doc.links["embedded"] |> List.first |> Map.get(:target)
    assert {:ok, embedded_linked_doc} = Navigation.link_target(doc, "embedded")

    assert {:ok, "http://example.com/?q=hello"} = Navigation.link_target(doc, "tmpl", tmpl_vars: %{q: "hello"})

    assert {:ok, l} = Navigation.link_target(doc, "multiple")
    assert "http://example.com/1" == l or "http://example.com/2" == l

    assert {:error, %Error{}} = Navigation.link_target(doc, "multiple", strict: true)

    assert {:error, %Error{}} = Navigation.link_target(doc, "nonexistent")
  end

  # Background

  setup do
    {:ok, doc: doc}
  end

  defp doc do
    ExHal.Document.from_parsed_hal(
      ExHal.client,
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
end
