defmodule ExHal.TranscoderTest do
  use ExUnit.Case

  setup do
    hal = """
    {
      "thing" : 1,
      "TheOtherThing": 2,
      "_links": {
        "up": { "href": "http://example.com/1" },
        "tag": [
          {"href": "foo:1"},
          {"href": "http://2"},
          {"href": "urn:1"}
        ]
      }
    }
    """

    {:ok, doc: ExHal.Document.parse!(ExHal.client, hal)}
  end

  test "can we make the most simple transcoder", %{doc: doc} do
    defmodule MyTranscoder do
      use ExHal.Transcoder
    end

    assert MyTranscoder.decode!(doc) == %{}
    assert %ExHal.Document{} = MyTranscoder.encode!(%{})
  end

  test "transcode properties", %{doc: doc} do
    defmodule NegationConverter do
      @behaviour ExHal.Transcoder.ValueConverter
      def to_hal(val), do: val * -1
      def from_hal(val), do: val * -1
    end
    defmodule MyOverreachingTranscoder do
      use ExHal.Transcoder

      defproperty "thing"
      defproperty "TheOtherThing", param: :thing2, value_converter: NegationConverter
      defproperty "missingThing",  param: :thing3
    end

    assert MyOverreachingTranscoder.decode!(doc) == %{thing: 1, thing2: -2}

    encoded = MyOverreachingTranscoder.encode!(%{thing: 1, thing2: 2})
    assert 1 == ExHal.get_lazy(encoded, "thing", fn -> :missing end)
    assert -2 == ExHal.get_lazy(encoded, "TheOtherThing", fn -> :missing end)
    assert :missing == ExHal.get_lazy(encoded, "missingThing", fn -> :missing end)
  end

  test "trying to extract links", %{doc: doc} do
    defmodule MyLinkTranscoder do
      use ExHal.Transcoder

      deflink "up", param: :mylink
    end

    assert MyLinkTranscoder.decode!(doc) == %{mylink: "http://example.com/1"}

    encoded = MyLinkTranscoder.encode!(%{mylink: "http://example.com/1"})
    assert {:ok, "http://example.com/1"} == ExHal.link_target(encoded, "up")
  end

  test "trying to extract multiple links with flag", %{doc: doc} do
   defmodule MyMultiLinkTranscoder do
     use ExHal.Transcoder

     deflink "tag", param: :tag, multiple: true
   end

   assert %{tag: ["urn:1", "http://2", "foo:1"]} == MyMultiLinkTranscoder.decode!(doc)

   encoded = MyMultiLinkTranscoder.encode!(%{tag: ["urn:1", "http://2", "foo:1"]})
   assert {:ok, ["urn:1", "http://2", "foo:1"]} == ExHal.link_target(encoded, "tag")
  end

  test "trying to extract multiple links with deflinks", %{doc: doc} do
   defmodule MyOtherMultiLinkTranscoder do
     use ExHal.Transcoder

     deflinks "tag", param: :tag
   end

   assert %{tag: ["urn:1", "http://2", "foo:1"]} == MyOtherMultiLinkTranscoder.decode!(doc)

   encoded = MyOtherMultiLinkTranscoder.encode!(%{tag: ["urn:1", "http://2", "foo:1"]})
   assert {:ok, ["urn:1", "http://2", "foo:1"]} == ExHal.link_target(encoded, "tag")
  end


  test "trying to extract links with value conversion", %{doc: doc} do
    defmodule MyLinkConverter do
      @behaviour ExHal.Transcoder.ValueConverter
      def to_hal(id) do
        "http://example.com/#{id}"
      end
      def from_hal(up_url) do
        {id, _} = up_url
        |> String.split("/")
        |> List.last
        |> Integer.parse
        id
      end
    end

    defmodule MyLinkConversionTranscoder do
      use ExHal.Transcoder

      deflink "up", param: :up_id, value_converter: MyLinkConverter
    end

    assert MyLinkConversionTranscoder.decode!(doc) == %{up_id: 1}

    encoded = MyLinkConversionTranscoder.encode!(%{up_id: 2})
    assert {:ok, "http://example.com/2"} == ExHal.link_target(encoded, "up")
  end
end
