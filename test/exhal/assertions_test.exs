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

    {:ok,
     %{
       hal: hal,
       doc: ExHal.Document.parse!(hal)
     }}
  end

  test "eq(expected)" do
    assert true == eq("foo").("foo")
    assert false == eq("foo").("bar")
  end

  test "matches(expected)" do
    assert true == matches(~r/f/).("foo")
    assert false == matches(~r/b/).("foo")
  end

  test "assert_property(doc, property_name)", %{doc: doc} do
    assert true == assert_property(doc, "name")
  end

  test "assert_property(doc, nonexistent_property_name)", %{doc: doc} do
    assert_raise ExUnit.AssertionError, ~r/absent/, fn ->
      assert_property(doc, "nonexistent")
    end
  end

  test "assert_property(doc, property_name, check_fn)", %{doc: doc} do
    assert true == assert_property(doc, "name", eq("foo"))
  end

  test "assert_property(doc, property_name, failing_check)", %{doc: doc} do
    assert_raise ExUnit.AssertionError, ~r/eq."wrong"/, fn ->
      assert_property(doc, "name", eq("wrong"))
    end
  end

  test "assert_property(doc, nonexistent_prop_name, check_fn)", %{doc: doc} do
    assert_raise ExUnit.AssertionError, ~r/absent/, fn ->
      assert_property(doc, "nonexistent", eq("foo"))
    end
  end

  test "assert_property(hal, property_name)", %{hal: hal} do
    assert true == assert_property(hal, "name")
  end

  test "assert_property(hal, nonexistent_property_name)", %{hal: hal} do
    assert_raise ExUnit.AssertionError, ~r/absent/, fn ->
      assert_property(hal, "nonexistent")
    end
  end

  test "assert_property(hal, property_name, check_fn)", %{hal: hal} do
    assert true == assert_property(hal, "name", eq("foo"))
  end

  test "assert_property(hal, property_name, failing_check)", %{hal: hal} do
    assert_raise ExUnit.AssertionError, ~r/eq."wrong"/, fn ->
      assert_property(hal, "name", eq("wrong"))
    end
  end

  test "assert_property(hal, nonexistent_prop_name, check_fn)", %{hal: hal} do
    assert_raise ExUnit.AssertionError, ~r/absent/, fn ->
      assert_property(hal, "nonexistent", eq("foo"))
    end
  end

  test "assert_link_target(doc, rel)", %{doc: doc} do
    assert true == assert_link_target(doc, "profile")
  end

  test "assert_link_target(doc, nonexistent_rel)", %{doc: doc} do
    assert_raise ExUnit.AssertionError, ~r/absent/i, fn ->
      assert_link_target(doc, "nonexistent")
    end
  end

  test "assert_link_target(doc, rel_with_multiple_links, check_fn)", %{doc: doc} do
    assert true == assert_link_target(doc, "profile", eq("http://example.com/simple"))
    assert true == assert_link_target(doc, "profile", eq("http://example.com/other"))
  end

  test "assert_link_target(doc, rel, non_matching_target_url)", %{doc: doc} do
    assert_raise ExUnit.AssertionError, ~r(eq.*"http://example.com/unsupported"), fn ->
      assert_link_target(doc, "profile", eq("http://example.com/unsupported"))
    end
  end

  test "assert_link_target(doc, nonexistent_rel, check_fn)", %{doc: doc} do
    assert_raise ExUnit.AssertionError, ~r/absent/, fn ->
      assert_link_target(doc, "nonexistent", eq("http://example.com/simple"))
    end
  end

  test "assert_link_target(hal, rel)", %{hal: hal} do
    assert true == assert_link_target(hal, "profile")
  end

  test "assert_link_target(hal, nonexistent_rel)", %{hal: hal} do
    assert_raise ExUnit.AssertionError, ~r/absent/i, fn ->
      assert_link_target(hal, "nonexistent")
    end
  end

  test "assert_link_target(hal, rel_with_multiple_links, check_fn)", %{hal: hal} do
    assert true == assert_link_target(hal, "profile", eq("http://example.com/simple"))
    assert true == assert_link_target(hal, "profile", eq("http://example.com/other"))
  end

  test "assert_link_target(hal, rel, non_matching_target_url)", %{hal: hal} do
    assert_raise ExUnit.AssertionError, ~r(eq.*"http://example.com/unsupported"), fn ->
      assert_link_target(hal, "profile", eq("http://example.com/unsupported"))
    end
  end

  test "assert_link_target(hal, nonexistent_rel, check_fn)", %{hal: hal} do
    assert_raise ExUnit.AssertionError, ~r/absent/, fn ->
      assert_link_target(hal, "nonexistent", eq("http://example.com/simple"))
    end
  end

  test "assert collection(doc) |> Enum.empty?", %{doc: doc} do
    assert collection(doc) |> Enum.empty?()
  end

  test "assert collection(hal) |> Enum.empty?", %{hal: hal} do
    assert collection(hal) |> Enum.empty?()
  end
end
