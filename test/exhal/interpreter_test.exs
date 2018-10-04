defmodule ExHal.InterpreterTest do
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

    {:ok, doc: ExHal.Document.parse!(ExHal.client(), hal)}
  end

  test "can we make the most simple interpreter", %{doc: doc} do
    defmodule MyInterpreter do
      use ExHal.Interpreter
    end

    assert MyInterpreter.to_params(doc) == %{}
  end

  test "trying to extract properties", %{doc: doc} do
    defmodule MyOverreachingInterpreter do
      use ExHal.Interpreter

      defextract(:thing)
      defextract(:thing2, from: "TheOtherThing")
      defextract(:thing3)
    end

    assert MyOverreachingInterpreter.to_params(doc) == %{thing: 1, thing2: 2}
  end

  test "trying to extract links", %{doc: doc} do
    defmodule MyLinkInterpreter do
      use ExHal.Interpreter

      defextractlink(:mylink, rel: "up")
    end

    assert MyLinkInterpreter.to_params(doc) == %{mylink: "http://example.com"}
  end
end
