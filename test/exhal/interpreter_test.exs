defmodule ExHal.InterpreterTest do
  use ExUnit.Case

  setup do
    {:ok, doc: %ExHal.Document{properties: %{"thing" => 1, "thing2" => 2}}}
  end

  test "can we make the most simple interpreter", %{doc: doc} do
    defmodule MyInterpreter do
      use ExHal.Interpreter
    end

    assert MyInterpreter.to_params(doc) == %{}
  end

  test "trying to extract a property", %{doc: doc} do
    defmodule MyBetterInterpreter do
      use ExHal.Interpreter

      defextract :thing
      defextract :thing2
    end

    assert MyBetterInterpreter.to_params(doc) == %{thing: 1, thing2: 2}
  end

  test "trying to extract a property", %{doc: doc} do
    defmodule MyOverreachingInterpreter do
      use ExHal.Interpreter

      defextract :thing
      defextract :thing2
      defextract :thing3
    end

    assert MyOverreachingInterpreter.to_params(doc) == %{thing: 1, thing2: 2, thing3: nil}
  end
end
