defmodule ExHal.CollectionTest do
  use ExUnit.Case, async: true
  use ExVCR.Mock, adapter: ExVCR.Adapter.Hackney

  alias ExHal.Document
  alias ExHal.Collection
  alias ExHal.Client

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

  test ".to_stream(single_page_collection_doc) contains all items", ctx do
    subject = Collection.to_stream(ctx[:single_page_collection_doc])
    assert 2 == Enum.count(subject)
    assert Enum.all? subject, fn x -> {:ok, _} = x end
    assert Enum.any? subject, has_doc_with_name("first")
    assert Enum.any? subject, has_doc_with_name("second")
  end

  test ".to_stream(multi_page_collection_doc) contains all items", ctx do
    subject = Collection.to_stream(ctx[:multi_page_collection_doc])

    stub_request ctx[:last_page_collection_url], ctx[:last_page_collection_hal_str], fn ->
      assert 3 == Enum.count(subject)
      assert Enum.all? subject, fn x -> {:ok, _} = x end
      assert Enum.any? subject, has_doc_with_name("first")
      assert Enum.any? subject, has_doc_with_name("second")
      assert Enum.any? subject, has_doc_with_name("last")
    end
  end

  test "ExHal.to_stream(sinlge_page_collection_doc) works", ctx do
    assert ExHal.to_stream(ctx[:single_page_collection_doc]) |> is_a_stream
  end


  # background

  setup do
    {:ok, [non_collection_doc:           non_collection_doc,
           single_page_collection_doc:   single_page_collection_doc,
           multi_page_collection_doc:    multi_page_collection_doc,
           empty_collection_doc:         empty_collection_doc,
           last_page_collection_url:     "http://example.com/?p=2",
           last_page_collection_hal_str: last_page_collection_hal_str]}
  end

  defp non_collection_doc do
    Document.from_parsed_hal(%Client{}, %{})
  end

  defp single_page_collection_doc do
    Document.from_parsed_hal(%Client{}, %{"_embedded" =>
                                %{"item" =>
                                   [%{"name" => "first"},
                                    %{"name" => "second"}
                                   ]
                                 }
                              })
  end

  defp empty_collection_doc do
    Document.from_parsed_hal(%Client{}, %{"_embedded" =>
                                %{"item" =>
                                   [
                                   ]
                                 }
                              })
  end

  defp multi_page_collection_doc do
    Document.from_parsed_hal(%Client{}, %{"_embedded" =>
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
        {:ok, doc} -> ExHal.get_property_lazy(doc, "name", fn -> :missing end) == expected
        _ -> false
      end
    end
  end

  def stub_request(url, body, block) do
    use_cassette :stub, [url: url, body: body, status_code: 200] do
      block.()
    end
  end
end
