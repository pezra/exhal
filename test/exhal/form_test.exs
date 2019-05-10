defmodule ExHal.FormTest do
  use ExUnit.Case, async: true

  import ExHal.Assertions

  alias ExHal.Form
  alias FakeClient

  import Mox
  setup :verify_on_exit!

  setup do
    Application.put_env(:exhal, :client, ExHal.ClientMock)
    on_exit fn ->
      Application.put_env(:exhal, :client, ExHal.Client)
    end
  end

  doctest ExHal.Form

  describe ".from_forms_entry/1" do
    test "valid empty form" do
      valid_empty_form_json = %{
        "_links" => %{
          "target" => %{"href" => "http://example.com/foo"}
        },
        "method" => "POST",
        "contentType" => "application/json",
        "fields" => []
      }

      assert %Form{} = Form.from_forms_entry(valid_empty_form_json)
    end

    test "invalid form json" do
      invalid_form_json = %{
        "method" => "POST",
        "contentType" => "application/json",
        "fields" => []
      }

      assert_raise(ArgumentError, fn -> Form.from_forms_entry(invalid_form_json) end)
    end
  end

  describe ".get_fields/1" do
    setup do
      form_json = %{
        "_links" => %{
          "target" => %{"href" => "http://example.com/foo"}
        },
        "method" => "POST",
        "contentType" => "application/json",
        "fields" => [
          %{"name" => "first_field", "type" => "string"},
          %{"name" => "second_field", "type" => "number"}
        ]
      }

      {:ok, %{form: Form.from_forms_entry(form_json)}}
    end

    test "returns correct fields", %{form: form} do
      assert same_items?(
               ["first_field", "second_field"],
               Form.get_fields(form) |> Enum.map(& &1.name)
             )
    end
  end

  describe ".set_field_value/3" do
    setup do
      form_json = %{
        "_links" => %{
          "target" => %{"href" => "http://example.com/foo"}
        },
        "method" => "POST",
        "contentType" => "application/json",
        "fields" => [
          %{"name" => "string_field", "type" => "string"}
        ]
      }

      {:ok, %{form: Form.from_forms_entry(form_json)}}
    end

    test "accepts string and returns updated form", %{form: form} do
      assert %Form{} = Form.set_field_value(form, "string_field", "yer mom")
    end
  end

  describe ".submit(post_form)" do
    setup do
      form_json = %{
        "_links" => %{
          "target" => %{"href" => "http://example.com/foo"}
        },
        "method" => "POST",
        "contentType" => "application/json",
        "fields" => [
          %{
            "name" => "string_field",
            "type" => "string",
            "value" => "test",
            "path" => "/stringField"
          }
        ]
      }

      {:ok, %{form: Form.from_forms_entry(form_json)}}
    end

    test "posts form succeeds", %{form: form} do
      ExHal.ClientMock
      |> expect(:post, fn _client, _url, _body, _opts ->
        {:ok, %ExHal.Document{}, %ExHal.ResponseHeader{}}
      end)

      assert {:ok, %ExHal.Document{}, %ExHal.ResponseHeader{}} = Form.submit(form, ExHal.client())
    end

    test "posts to correct place", %{form: form} do
      ExHal.ClientMock
      |> expect(:post, fn _client, url, _body, _opts ->
        assert "http://example.com/foo" == url
        {:ok, %ExHal.Document{}, %ExHal.ResponseHeader{}}
      end)

      Form.submit(form, ExHal.client())
    end

    test "posts correct media type", %{form: form} do
      ExHal.ClientMock
      |> expect(:post, fn _client, _url, _body, [headers: headers] ->
        assert "application/json" ==
                 Enum.find(headers, fn {field_name, _} ->
                   Regex.match?(~r/content-type/i, to_string(field_name))
                 end)
                 |> elem(1)

        {:ok, %ExHal.Document{}, %ExHal.ResponseHeader{}}
      end)

      Form.submit(form, ExHal.client())
    end

    test "posts correct body", %{form: form} do
      ExHal.ClientMock
      |> expect(:post, fn _client, _url, body, _opts ->
        assert_property(ExHal.Document.parse!(body), "stringField", eq("test"))
        {:ok, %ExHal.Document{}, %ExHal.ResponseHeader{}}
      end)

      Form.submit(form, ExHal.client())
    end
  end

  describe ".submit(put_form)" do
    setup do
      form_json = %{
        "_links" => %{
          "target" => %{"href" => "http://example.com/foo"}
        },
        "method" => "PUT",
        "contentType" => "application/json",
        "fields" => [
          %{
            "name" => "string_field",
            "type" => "string",
            "value" => "test",
            "path" => "/stringField"
          }
        ]
      }

      {:ok, %{form: Form.from_forms_entry(form_json)}}
    end

    test "put form succeeds", %{form: form} do
      ExHal.ClientMock
      |> expect(:put, fn _client, _url, _body, _opts ->
        {:ok, %ExHal.Document{}, %ExHal.ResponseHeader{}}
      end)

      assert {:ok, %ExHal.Document{}, %ExHal.ResponseHeader{}} = Form.submit(form, ExHal.client())
    end

    test "puts to correct place", %{form: form} do
      ExHal.ClientMock
      |> expect(:put, fn _client, url, _body, _opts ->
        assert "http://example.com/foo" == url
        {:ok, %ExHal.Document{}, %ExHal.ResponseHeader{}}
      end)

      Form.submit(form, ExHal.client())
    end

    test "puts correct media type", %{form: form} do
      ExHal.ClientMock
      |> expect(:put, fn _client, _url, _body, [headers: headers] ->
        assert "application/json" ==
                 Enum.find(headers, fn {field_name, _} ->
                   Regex.match?(~r/content-type/i, to_string(field_name))
                 end)
                 |> elem(1)

        {:ok, %ExHal.Document{}, %ExHal.ResponseHeader{}}
      end)

      Form.submit(form, ExHal.client())
    end

    test "puts correct body", %{form: form} do
      ExHal.ClientMock
      |> expect(:put, fn _client, _url, body, _opts ->
        assert_property(ExHal.Document.parse!(body), "stringField", eq("test"))
        {:ok, %ExHal.Document{}, %ExHal.ResponseHeader{}}
      end)

      Form.submit(form, ExHal.client())
    end
  end

  def same_items?(list1, list2) do
    Enum.sort(list1) == Enum.sort(list2)
  end
end
