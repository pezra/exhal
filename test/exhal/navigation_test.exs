defmodule ExHal.NavigationTest do
  use ExUnit.Case, async: false
  import Mox

  alias ExHal.{Navigation, Document, Error, ResponseHeader}

  describe ".follow_link" do
    test "regular link", %{doc: doc} do
      ExHal.ClientMock
      |> expect(:get, fn _client, "http://example.com/", _headers ->
        {:ok, Document.parse!(hal_str("http://example.com/thing")),
         %ResponseHeader{status_code: 200}}
      end)

      assert {:ok, repr = %Document{}, %ResponseHeader{status_code: 200}} =
               Navigation.follow_link(doc, "single")

      assert {:ok, "http://example.com/thing"} = ExHal.url(repr)
    end

    test "embedded link", %{doc: doc} do
      assert {:ok, repr = %Document{}, %ResponseHeader{}} =
               Navigation.follow_link(doc, "embedded")

      assert {:ok, "http://example.com/e"} = ExHal.url(repr)
    end
  end

  describe ".post" do
    test "regular link", %{doc: doc} do
      new_thing_hal = hal_str("http://example.com/new-thing")

      ExHal.ClientMock
      |> expect(:post, fn _client, "http://example.com/", "post body", _headers ->
        {:ok, Document.parse!(new_thing_hal), %ResponseHeader{status_code: 200}}
      end)

      assert {:ok, repr = %Document{}, %ResponseHeader{status_code: 200}} =
               Navigation.post(doc, "single", "post body")

      assert {:ok, "http://example.com/new-thing"} = ExHal.url(repr)
    end
  end

  describe ".put" do
    test "regular link", %{doc: doc} do
      new_thing_hal = hal_str("http://example.com/new-thing")

      ExHal.ClientMock
      |> expect(:put, fn _client, "http://example.com/", "put body", _headers ->
        {:ok, Document.parse!(new_thing_hal), %ResponseHeader{status_code: 200}}
      end)

      assert {:ok, repr = %Document{}, %ResponseHeader{status_code: 200}} =
               Navigation.put(doc, "single", "put body")

      assert {:ok, "http://example.com/new-thing"} = ExHal.url(repr)
    end
  end

  describe ".patch" do
    test "regular link", %{doc: doc} do
      new_thing_hal = hal_str("http://example.com/new-thing")

      ExHal.ClientMock
      |> expect(:patch, fn _client, "http://example.com/", "patch body", _headers ->
        {:ok, Document.parse!(new_thing_hal), %ResponseHeader{status_code: 200}}
      end)

      assert {:ok, repr = %Document{}, %ResponseHeader{status_code: 200}} =
               Navigation.patch(doc, "single", "patch body")

      assert {:ok, "http://example.com/new-thing"} = ExHal.url(repr)
    end
  end

  test ".link_target", %{doc: doc} do
    assert {:ok, "http://example.com/"} = Navigation.link_target(doc, "single")
    assert {:ok, "http://example.com/e"} = Navigation.link_target(doc, "embedded")

    assert {:ok, "http://example.com/?q=hello"} =
             Navigation.link_target(doc, "tmpl", tmpl_vars: %{q: "hello"})

    assert {:ok, l} = Navigation.link_target(doc, "multiple")
    assert "http://example.com/1" == l or "http://example.com/2" == l

    assert {:error, %Error{}} = Navigation.link_target(doc, "multiple", strict: true)

    assert {:error, %Error{}} = Navigation.link_target(doc, "nonexistent")
  end

  # Background

  setup do
    {:ok, doc: doc()}
  end

  defp doc do
    ExHal.Document.from_parsed_hal(
      ExHal.client(),
      %{
        "_links" => %{
          "single" => %{"href" => "http://example.com/"},
          "tmpl" => %{"href" => "http://example.com/{?q}", "templated" => true},
          "multiple" => [%{"href" => "http://example.com/1"}, %{"href" => "http://example.com/2"}]
        },
        "_embedded" => %{
          "embedded" => %{"_links" => %{"self" => %{"href" => "http://example.com/e"}}}
        }
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
