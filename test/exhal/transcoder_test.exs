defmodule ExHal.TranscoderTest do
  use ExUnit.Case

  setup do
    hal = """
    {
      "thing" : 1,
      "TheOtherThing": 2,
      "_links": {
        "up": { "href": "http://example.com" }
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

  test "trying to extract properties", %{doc: doc} do
    defmodule MyOverreachingTranscoder do
      use ExHal.Transcoder

      defproperty "thing"
      defproperty "TheOtherThing", param: :thing2
      defproperty "missingThing",  param: :thing3
    end

    assert MyOverreachingTranscoder.decode!(doc) == %{thing: 1, thing2: 2}

    encoded = MyOverreachingTranscoder.encode!(%{thing: 1, thing2: 2})
    assert 1 == ExHal.get_lazy(encoded, "thing", fn -> :missing end)
    assert 2 == ExHal.get_lazy(encoded, "TheOtherThing", fn -> :missing end)
    assert :missing == ExHal.get_lazy(encoded, "missingThing", fn -> :missing end)
  end

  test "trying to extract links", %{doc: doc} do
    defmodule MyLinkTranscoder do
      use ExHal.Transcoder

      deflink "up", param: :mylink
    end

    assert MyLinkTranscoder.decode!(doc) == %{mylink: "http://example.com"}

    encoded = MyLinkTranscoder.encode!(%{mylink: "http://example.com"})
    assert {:ok, "http://example.com"} == ExHal.link_target(encoded, "up")
  end
end
