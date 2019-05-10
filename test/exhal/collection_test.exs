Code.require_file "../support/request_stubbing.exs", __DIR__

defmodule ExHal.CollectionTest do
  use ExUnit.Case, async: false
  use RequestStubbing

  alias ExHal.Document
  alias ExHal.Collection
  alias ExHal.ResponseHeader

  import Mox

  test ".to_json_hash" do
    parsed_hal = %{
      "name" => "My Name",
      "_embedded" => %{ "test" => %{"_embedded" => %{}, "_links" => %{}, "name" => "Is Test"}},
      "_links" => %{ "self" => %{"href" => "http://example.com/my-name"}}}

    doc = Document.from_parsed_hal(parsed_hal)
    assert %{"_embedded" => %{"item" => [^parsed_hal]}} = Collection.to_json_hash([doc])
  end

  test "render!/1" do
    parsed_hal = %{
      "name" => "My Name",
      "_embedded" => %{ "test" => %{"_embedded" => %{}, "_links" => %{}, "name" => "Is Test"}},
      "_links" => %{ "self" => %{"href" => "http://example.com/my-name"}}}

    doc = Document.from_parsed_hal(parsed_hal)
    {:ok, rendered_doc, %ResponseHeader{}} =
      Collection.render!([doc])
      |> Document.parse!
      |> Collection.to_stream
      |> Enum.at(0)

    assert rendered_doc == doc
  end

  test ".to_stream(non_collection_doc) succeeds", ctx do
    assert Collection.to_stream(ctx[:non_collection_doc]) |> is_a_stream
  end

  test ".to_stream(sinlge_page_collection_doc) works", ctx do
    assert Collection.to_stream(ctx[:single_page_collection_doc]) |> is_a_stream
  end

  test ".to_stream(empty_page_collection_doc) works", ctx do
    assert Collection.to_stream(ctx[:empty_collection_doc]) |> is_a_stream
  end

  test ".to_stream(multi_page_collection_doc) works", ctx do
    assert Collection.to_stream(ctx[:multi_page_collection_doc]) |> is_a_stream
  end

  test ".to_stream(single_page_collection_doc) contains all items", %{
    single_page_collection_doc: single_page_collection_doc
  } do
    subject = Collection.to_stream(single_page_collection_doc)
    assert 2 == Enum.count(subject)
    assert Enum.all? subject, fn x -> {:ok, _, %ResponseHeader{}} = x end
    assert Enum.any? subject, has_doc_with_name("first")
    assert Enum.any? subject, has_doc_with_name("second")
  end

  test ".to_stream(multi_page_collection_doc) contains all items", %{
    last_page_collection_url: last_page_collection_url,
    last_page_collection_hal_str: last_page_collection_hal_str,
    multi_page_collection_doc: multi_page_collection_doc
  } do
    subject = Collection.to_stream(multi_page_collection_doc)

    stub_request "get", url: last_page_collection_url, resp_body: last_page_collection_hal_str do
      assert 3 == Enum.count(subject)
      assert Enum.all? subject, fn x -> {:ok, _, %ResponseHeader{}} = x end
      assert Enum.any? subject, has_doc_with_name("first")
      assert Enum.any? subject, has_doc_with_name("second")
      assert Enum.any? subject, has_doc_with_name("last")
    end
  end

  test "ExHal.to_stream(sinlge_page_collection_doc) works", ctx do
    assert ExHal.to_stream(ctx[:single_page_collection_doc]) |> is_a_stream
  end

  test "ExHal.to_stream(truly_empty_collection_doc) works", %{truly_empty_collection_doc: doc} do
    assert ExHal.to_stream(doc) |> is_a_stream
  end

  describe "Non Hal Responses" do
    setup do
      Application.put_env(:exhal, :client, ExHal.ClientMock)
      on_exit fn ->
        Application.put_env(:exhal, :client, ExHal.Client)
      end
    end

    test ".to_stream(multi_page_collection_doc) handles error", %{
      multi_page_collection_doc: multi_page_collection_doc
    } do

      ExHal.ClientMock
      |> expect(:get, fn _client, _url, _opts ->
        {:error, %ExHal.Error{reason: :timeout}}
      end)

      subject = Collection.to_stream(multi_page_collection_doc)

      assert_raise ExHal.CollectionError, "Failed to fetch next link due to timeout", fn -> Enum.count(subject) end
    end
  end


  # background

  setup do
    {:ok, [non_collection_doc:           non_collection_doc(),
           single_page_collection_doc:   single_page_collection_doc(),
           multi_page_collection_doc:    multi_page_collection_doc(),
           empty_collection_doc:         empty_collection_doc(),
           truly_empty_collection_doc:   truly_empty_collection_doc(),
           last_page_collection_url:     "http://example.com/?p=2",
           last_page_collection_hal_str: last_page_collection_hal_str()]}
  end

  defp non_collection_doc do
    Document.from_parsed_hal(%{})
  end

  defp single_page_collection_doc do
    Document.from_parsed_hal(%{"_embedded" =>
                                %{"item" =>
                                   [%{"name" => "first"},
                                    %{"name" => "second"}
                                   ]
                                 }
                              })
  end

  defp empty_collection_doc do
    Document.from_parsed_hal(%{"_embedded" =>
                                %{"item" =>
                                   [
                                   ]
                                 }
                              })
  end

  defp truly_empty_collection_doc do
    Document.from_parsed_hal(%{"_embedded" => %{}})
  end

  defp multi_page_collection_doc do
    Document.from_parsed_hal(%{"_embedded" =>
                                %{"item" =>
                                   [%{"name" => "first"},
                                    %{"name" => "second"}
                                   ]
                                 },
                               "_links" =>
                                 %{"next" => %{"href" => "http://example.com/?p=2"}
                                  }
                              })
  end

  defp last_page_collection_hal_str do
    """
      {"_embedded": {
         "item": [{"name": "last"}]
         }
      }
      """
  end

  defp is_a_stream(thing) do
    is_function(thing)
  end

  defp has_doc_with_name(expected) do
    fn item ->
      case item do
        {:ok, doc, %ResponseHeader{}} -> ExHal.get_property_lazy(doc, "name", fn -> :missing end) == expected
        _ -> false
      end
    end
  end
end
