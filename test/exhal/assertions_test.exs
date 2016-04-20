defmodule ExHal.AssertionsTest do
  use ExUnit.Case, async: true

  import ExHal.Assertions

  setup do
    hal = ~s(
      { "name": "foo",
        "_links": {
          "profile": [ {"href": "http://example.com/simple" },
                       {"href": "http://example.com/other" } ]
        }
      }
    )

    {:ok, %{
        hal: hal,
        doc: ExHal.Document.parse!(hal)
     } }
  end

  test ".eq(expected)" do
    assert true  == eq("foo").("foo")
    assert false == eq("foo").("bar")
  end

  test ".matches(expected)" do
    assert true  == matches(~r/f/).("foo")
    assert false == matches(~r/b/).("foo")
  end

  test "property value assertions for hal doc", %{doc: doc} do
    assert true == assert_property(doc, "name")
    assert true == assert_property(doc, "name", eq "foo")

    assert_raise ExUnit.AssertionError, fn ->
      assert_property(doc, "name", eq "wrong")
    end

    assert_raise ExUnit.AssertionError, fn ->
      assert_property(doc, "nonexistent", eq "foo")
    end
  end

  test "property value assertions for hal str", %{hal: hal} do
    assert true == assert_property(hal, "name")
    assert true == assert_property(hal, "name", eq "foo")

    assert_raise ExUnit.AssertionError, fn ->
      assert_property(hal, "name", eq "wrong")
    end

    assert_raise ExUnit.AssertionError, fn ->
      assert_property(hal, "nonexistent", eq "foo")
    end
  end

  test "link target assertions for hal doc", %{doc: doc} do
    assert true == assert_link_target(doc, "profile")
    assert true == assert_link_target(doc, "profile", eq "http://example.com/simple")
    assert true == assert_link_target(doc, "profile", eq "http://example.com/other")

    assert_raise ExUnit.AssertionError, fn ->
      assert_link_target(doc, "profile", eq "http://example.com/unsupported")
    end

    assert_raise ExUnit.AssertionError, fn ->
      assert_link_target(doc, "nonexistent", eq "http://example.com/simple")
    end
  end

  test "link target assertions for hal str", %{hal: hal} do
    assert true == assert_link_target(hal, "profile")
    assert true == assert_link_target(hal, "profile", eq "http://example.com/simple")

    assert_raise ExUnit.AssertionError, fn ->
      assert_link_target(hal, "profile", eq "http://example.com/unsupported")
    end

    assert_raise ExUnit.AssertionError, fn ->
      assert_link_target(hal, "nonexistent", eq "http://example.com/simple")
    end
  end



end
