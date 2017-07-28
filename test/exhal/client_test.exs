Code.require_file "../support/request_stubbing.exs", __DIR__

defmodule ExHal.ClientTest do
  use ExUnit.Case, async: true

  alias ExHal.Client

  test "adding headers to client" do
    assert (%Client{}
            |> Client.add_headers("hello": "bob")
            |> Client.add_headers("hello": ["alice","jane"]))
    |> to_have_header("hello", ["bob", "alice", "jane"])
  end

  # background

  defp to_have_header(client, expected_name, expected_value) do
    expected_name = String.to_atom(expected_name)
    {:ok, actual_value} = Keyword.fetch(client.headers, expected_name)

    actual_value == expected_value
  end
end

defmodule ExHal.ClientHttpRequestTest do
  use ExUnit.Case, async: false
  use RequestStubbing

  alias ExHal.{Client, Document, NonHalResponse, ResponseHeader}

  test ".get w/ normal link", %{client: client} do
    thing_hal = hal_str("http://example.com/thing")

    stub_request "get", url: "http://example.com/", resp_body: thing_hal do
      assert {:ok, (target = %Document{}), %ResponseHeader{status_code: 200}} =
        Client.get(client, "http://example.com/")

      assert {:ok, "http://example.com/thing"} = ExHal.url(target)
    end
  end

  test ".post w/ normal link", %{client: client} do
    new_thing_hal = hal_str("http://example.com/new-thing")

    stub_request "post", url: "http://example.com/",
                         req_body: new_thing_hal,
                         resp_body: new_thing_hal do
      assert {:ok, (target = %Document{}), %ResponseHeader{status_code: 200}} =
        Client.post(client, "http://example.com/", new_thing_hal)

      assert {:ok, "http://example.com/new-thing"} = ExHal.url(target)
    end
  end

  test ".post with empty response", %{client: client} do
    stub_request "post", url: "http://example.com/",
                         req_body: "post body",
                         resp_body: "" do
      assert {:ok, %NonHalResponse{}, %ResponseHeader{status_code: 200}} =
        Client.post(client, "http://example.com/", "post body")
    end
  end

  test ".put w/ normal link", %{client: client} do
    new_thing_hal = hal_str("http://example.com/new-thing")

    stub_request "put", url: "http://example.com/",
                        req_body: "the request body",
                        resp_body: new_thing_hal do
      assert {:ok, (target = %Document{}), %ResponseHeader{status_code: 200}} =
        Client.put(client, "http://example.com/", "the request body")

      assert {:ok, "http://example.com/new-thing"} = ExHal.url(target)
    end
  end

  test ".patch w/ normal link", %{client: client} do
    new_thing_hal = hal_str("http://example.com/new-thing")

    stub_request "patch", url: "http://example.com/",
                        req_body: "the request body",
                        resp_body: new_thing_hal do
      assert {:ok, (target = %Document{}), %ResponseHeader{status_code: 200}} =
        Client.patch(client, "http://example.com/", "the request body")

      assert {:ok, "http://example.com/new-thing"} = ExHal.url(target)
    end
  end


  # Background

  setup do
    {:ok, client: %Client{}}
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
