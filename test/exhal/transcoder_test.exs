defmodule ExHal.TranscoderTest do
  use ExUnit.Case

  setup do
    hal = """
    {
      "thing" : 1,
      "TheOtherThing": 2,
      "yer_mom": true,
      "_links": {
        "up": { "href": "http://example.com/1" },
        "tag": [
          {"href": "foo:1"},
          {"href": "http://2"},
          {"href": "urn:1"}
        ],
        "nested": { "href": "http://example.com/2" }
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
      defproperty "yer_mom", param: [:yer, :mom]
    end

    assert %{thing: 1, thing2: -2, yer: %{mom: true}} == MyOverreachingTranscoder.decode!(doc)

    encoded = MyOverreachingTranscoder.encode!(%{thing: 1, thing2: 2, yer: %{mom: true}})
    assert 1 == ExHal.get_lazy(encoded, "thing", fn -> :missing end)
    assert -2 == ExHal.get_lazy(encoded, "TheOtherThing", fn -> :missing end)
    assert true == ExHal.get_lazy(encoded, "yer_mom", fn -> :missing end)
    assert :missing == ExHal.get_lazy(encoded, "missingThing", fn -> :missing end)
  end

  test "extract links", %{doc: doc} do
    defmodule MyLinkTranscoder do
      use ExHal.Transcoder

      deflink "up", param: :mylink
      deflink "nested", param: [:nested, :url]
    end

    assert MyLinkTranscoder.decode!(doc) == %{mylink: "http://example.com/1",
                                             nested: %{url: "http://example.com/2"}}

    encoded = MyLinkTranscoder.encode!(%{mylink: "http://example.com/1",
                                         nested: %{url: "http://example.com/2"}})
    assert {:ok, "http://example.com/1"} == ExHal.link_target(encoded, "up")
    assert {:ok, "http://example.com/2"} == ExHal.link_target(encoded, "nested")
  end

  test "trying to extract multiple links", %{doc: doc} do
   defmodule MyOtherMultiLinkTranscoder do
     use ExHal.Transcoder

     deflinks "tag", param: :tag
   end

   assert %{tag: ["urn:1", "http://2", "foo:1"]} == MyOtherMultiLinkTranscoder.decode!(doc)

   encoded = MyOtherMultiLinkTranscoder.encode!(%{tag: ["urn:1", "http://2", "foo:1"]})
   assert {:ok, ["urn:1", "http://2", "foo:1"]} == ExHal.link_targets(encoded, "tag")
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

  test "composable transcoders", %{doc: doc} do
    defmodule BaseTranscoder do
      use ExHal.Transcoder
      defproperty "thing"
      deflink "up", param: :up_url
    end
    defmodule ExtTranscoder do
      use ExHal.Transcoder
      defproperty "TheOtherThing", param: :thing2
      deflinks "tag", param: :tag
    end

    decoded = BaseTranscoder.decode!(doc)
    |> ExtTranscoder.decode!(doc)
    assert %{thing: 1} = decoded
    assert %{thing2: 2} = decoded
    assert %{up_url: "http://example.com/1"} = decoded
    assert %{tag: ["urn:1", "http://2", "foo:1"]} = decoded

    params = %{thing: 1,
               tag: ["urn:1", "http://2", "foo:1"],
               thing2: 2,
               up_url: "http://example.com/1"}
    encoded = BaseTranscoder.encode!(params)
    |> ExtTranscoder.encode!(params)
    assert 1 == ExHal.get_lazy(encoded, "thing", fn -> :missing end)
    assert 2 == ExHal.get_lazy(encoded, "TheOtherThing", fn -> :missing end)
    assert {:ok, "http://example.com/1"} == ExHal.link_target(encoded, "up")
    assert {:ok, ["urn:1", "http://2", "foo:1"]} == ExHal.link_targets(encoded, "tag")

  end
end

defmodule ExHal.TranscoderEmptyLinksTest do
  use ExUnit.Case

  setup do
    hal = """
    {
      "_links": {
        "tag": []
      }
    }
    """

    {:ok, doc: ExHal.Document.parse!(ExHal.client, hal)}
  end

  test "trying to extract empty link array", %{doc: doc} do
   defmodule MyOtherMultiLinkTranscoder do
     use ExHal.Transcoder

     deflinks "tag", param: :tag
   end

   assert %{} == MyOtherMultiLinkTranscoder.decode!(doc)

   encoded = MyOtherMultiLinkTranscoder.encode!(%{tag: []})
   refute ExHal.Document.has_link?(encoded, "tag")
  end
end


defmodule ExHal.TranscoderNullLinksTest do
  use ExUnit.Case

  setup do
    hal = """
    {
      "_links": {
        "tag": null
      }
    }
    """

    {:ok, doc: ExHal.Document.parse!(ExHal.client, hal)}
  end

  test "trying to extract empty link array", %{doc: doc} do
   defmodule MyOtherMultiLinkTranscoder do
     use ExHal.Transcoder

     deflinks "tag", param: :tag
   end

   assert %{} == MyOtherMultiLinkTranscoder.decode!(doc)

   encoded = MyOtherMultiLinkTranscoder.encode!(%{tag: []})
   refute ExHal.Document.has_link?(encoded, "tag")
  end
end

defmodule ExHal.TranscoderAbsentLinksTest do
  use ExUnit.Case

  setup do
    hal = """
    {
      "_links": {
      },
      "tag": []
    }
    """

    {:ok, doc: ExHal.Document.parse!(ExHal.client, hal)}
  end

  test "trying to extract empty link array", %{doc: doc} do
   defmodule MyOtherMultiLinkTranscoder do
     use ExHal.Transcoder

     deflinks "tag", param: :tag
   end

   assert %{} == MyOtherMultiLinkTranscoder.decode!(doc)

   encoded = MyOtherMultiLinkTranscoder.encode!(%{tag: []})
   refute ExHal.Document.has_link?(encoded, "tag")
  end
end