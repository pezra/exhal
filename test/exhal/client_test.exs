Code.require_file "../support/request_stubbing.exs", __DIR__

defmodule ExHal.ClientTest do
  use ExUnit.Case, async: true

  alias ExHal.{Client, SimpleAuthorizer}

  describe ".new" do
    test ".new/0" do
      assert %Client{} = Client.new
    end

    test "(empty_headers)" do
      assert %Client{} = Client.new([])
    end

    test "(headers)" do
      assert %Client{headers: ["User-Agent": "test agent", "X-Whatever": "example"]} =
        Client.new("User-Agent": "test agent", "X-Whatever": "example")
    end

    test "(headers, follow_redirect: follow)" do
      assert %Client{headers: ["User-Agent": "test agent"], opts: [follow_redirect: false]} =
        Client.new(["User-Agent": "test agent"], follow_redirect: false)
    end
  end

  describe ".add_headers/1" do
    test "adding headers to client" do
      assert (%Client{}
      |> Client.add_headers("hello": "bob")
      |> Client.add_headers("hello": ["alice","jane"]))
      |> to_have_header("hello", ["bob", "alice", "jane"])
    end
  end

  describe ".set_authorizer/2" do
    test "first time" do
      test_auther = SimpleAuthorizer.new("http://example.com", "Bearer sometoken")

      assert %Client{authorizer: test_auther} ==
        Client.set_authorizer(Client.new, test_auther)
    end

    test "last one in wins time" do
      test_auther1 = SimpleAuthorizer.new("http://example.com", "Bearer sometoken")
      test_auther2 = SimpleAuthorizer.new("http://myapp.com", "Bearer someothertoken")

      assert %Client{authorizer: test_auther2} ==
        Client.new
        |> Client.set_authorizer(test_auther1)
        |> Client.set_authorizer(test_auther2)
    end
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
