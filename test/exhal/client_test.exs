
defmodule ExHal.ClientTest do
  use ExUnit.Case, async: true

  alias ExHal.{Client, Document, NonHalResponse, ResponseHeader}

  import Mox
  setup :verify_on_exit!

  describe ".new" do
    test ".new/0" do
      assert %Client{} = Client.new()
    end

    test "(empty_headers)" do
      assert %Client{} = Client.new([])
    end

    test "(headers)" do
      assert %Client{headers: %{"User-Agent" => "test agent", "X-Whatever" => "example"}} =
               Client.new("User-Agent": "test agent", "X-Whatever": "example")
    end

    test "(headers, follow_redirect: follow)" do
      assert %Client{headers: %{"User-Agent" => "test agent"}, opts: [follow_redirect: false]} =
               Client.new(["User-Agent": "test agent"], follow_redirect: false)
    end
  end

  describe ".add_headers/1" do
    test "adding headers to client" do
      assert %Client{}
             |> Client.add_headers(hello: "bob")
             |> Client.add_headers(hello: ["alice", "jane"])
             |> to_have_header("hello", ["bob", "alice", "jane"])
    end
  end

  describe ".set_authorizer/2" do
    test "first time" do
      test_auther = authorizer_factory()

      assert %Client{authorizer: test_auther} == Client.set_authorizer(Client.new(), test_auther)
    end

    test "last one in wins time" do
      test_auther1 = authorizer_factory()
      test_auther2 = authorizer_factory()

      assert %Client{authorizer: test_auther2} ==
               Client.new()
               |> Client.set_authorizer(test_auther1)
               |> Client.set_authorizer(test_auther2)
    end
  end

  describe ".get/2" do
    test "w/ normal link" do
      client = Client.new()

      ExHal.HttpClientMock
      |> expect(:get, fn "http://example.com/", _headers, _opts ->
        {:ok, %HTTPoison.Response{body: hal_str("http://example.com/thing"), status_code: 200}}
      end)

      assert {:ok, repr = %Document{}, %ResponseHeader{status_code: 200}} =
               Client.get(client, "http://example.com/")

      assert {:ok, "http://example.com/thing"} = ExHal.url(repr)
    end

    test "adds credentials to request if authorizer provides some" do
      client =
        Client.new()
        |> Client.set_authorizer(authorizer_factory("Bearer mytoken"))

      ExHal.HttpClientMock
      |> expect(:get, fn _url, %{"Authorization" => "Bearer mytoken"}, _opts ->
        {:ok, %HTTPoison.Response{body: "{}", status_code: 200}}
      end)

      Client.get(client, "http://example.com/thing")
    end

    test "doesn't add credentials to request if authorizer provides none" do
      client =
        Client.new()
        |> Client.set_authorizer(authorizer_factory(%{}))

      ExHal.HttpClientMock
      |> expect(:get, fn _url, headers, _opts ->
        assert ! Map.has_key?(headers, "Authorization")
        {:ok, %HTTPoison.Response{body: "{}", status_code: 200}}
      end)

      Client.get(client, "http://example.com/thing")
    end

  end

  describe ".post" do
    test "w/ normal link" do
      client = Client.new
      new_thing_hal = hal_str("http://example.com/new-thing")

      ExHal.HttpClientMock
      |> expect(:post, fn "http://example.com/", new_thing_hal, _headers, _opts ->
        {:ok, %HTTPoison.Response{body: new_thing_hal, status_code: 200}}
      end)

      assert {:ok, repr = %Document{}, %ResponseHeader{status_code: 200}} =
               Client.post(client, "http://example.com/", new_thing_hal)

      assert {:ok, "http://example.com/new-thing"} = ExHal.url(repr)
    end

    test "w/ empty response" do
      client = Client.new()

      ExHal.HttpClientMock
      |> expect(:post, fn "http://example.com/", _body, _headers, _opts ->
        {:ok, %HTTPoison.Response{body: "", status_code: 204}}
      end)

      assert {:ok, %NonHalResponse{}, %ResponseHeader{status_code: 204}} =
               Client.post(client, "http://example.com/", "post body")
    end

    test "w/ auth" do
      client =
        Client.new()
        |> Client.set_authorizer(authorizer_factory("Bearer mytoken"))

      ExHal.HttpClientMock
      |> expect(:post, fn _url, _body, %{"Authorization" => "Bearer mytoken"}, _opts ->
        {:ok, %HTTPoison.Response{body: "{}", status_code: 200}}
      end)

      Client.post(client, "http://example.com/thing", "post body")
    end
  end


  describe ".put" do
    test "w/ normal link" do
      client = Client.new()

      new_thing_hal = hal_str("http://example.com/new-thing")

      ExHal.HttpClientMock
      |> expect(:put, fn "http://example.com/", new_thing_hal, _headers, _opts ->
        {:ok, %HTTPoison.Response{body: new_thing_hal, status_code: 200}}
      end)

      assert {:ok, repr = %Document{}, %ResponseHeader{status_code: 200}} =
               Client.put(client, "http://example.com/", new_thing_hal)

      assert {:ok, "http://example.com/new-thing"} = ExHal.url(repr)
    end

    test "w/ auth" do
      client =
        Client.new()
        |> Client.set_authorizer(authorizer_factory("Bearer mytoken"))

      ExHal.HttpClientMock
      |> expect(:put, fn _url, _body, %{"Authorization" => "Bearer mytoken"}, _opts ->
        {:ok, %HTTPoison.Response{body: "{}", status_code: 200}}
      end)

      Client.put(client, "http://example.com/thing", "put body")
    end
  end

  describe ".patch" do
    test "w/ normal link" do
      client = Client.new()

      new_thing_hal = hal_str("http://example.com/new-thing")

      ExHal.HttpClientMock
      |> expect(:patch, fn "http://example.com/", new_thing_hal, _headers, _opts ->
        {:ok, %HTTPoison.Response{body: new_thing_hal, status_code: 200}}
      end)

      assert {:ok, repr = %Document{}, %ResponseHeader{status_code: 200}} =
               Client.patch(client, "http://example.com/", new_thing_hal)

      assert {:ok, "http://example.com/new-thing"} = ExHal.url(repr)
    end

    test "w/ auth" do
      client =
        Client.new()
        |> Client.set_authorizer(authorizer_factory("Bearer mytoken"))

      ExHal.HttpClientMock
      |> expect(:patch, fn _url, _body, %{"Authorization" => "Bearer mytoken"}, _opts ->
        {:ok, %HTTPoison.Response{body: "{}", status_code: 200}}
      end)

      Client.patch(client, "http://example.com/thing", "patch body")
    end
  end


  # background

  defp client_factory(), do: %Client{}

  defp authorizer_factory(headers \\ %{"Authorization" => "Bearer mytoken"})
  defp authorizer_factory(headers) when is_map(headers) do
    %ExHal.TestAuthorizer{headers: headers}
  end
  defp authorizer_factory(credentials) when is_binary(credentials) do
    %ExHal.TestAuthorizer{headers: %{"Authorization" => credentials}}
  end

  defp to_have_header(client, expected_name, expected_value) do
    {:ok, actual_value} = Map.fetch(client.headers, expected_name)

    actual_value == expected_value
  end

  defp hal_str(url) do
    """
    { "name": "#{url}",
      "_links": {
        "self": { "href": "#{url}" }
      }
    }
    """
  end

end
