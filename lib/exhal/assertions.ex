defmodule ExHal.Assertions do
  import ExUnit.Assertions
  alias ExHal.{Document,Navigation,Link}

  @doc"""
    Returns a function that checks if the actual value is equal to the expected.
  """
  def eq(expected) do
    fn(actual) -> actual == expected end
  end

  @doc"""
    Returns a function that checks if the actual value matches the expected pattern.
  """
  def matches(expected) do
    fn(actual) -> actual =~ expected end
  end

  @doc"""
    Asserts that a property exists and, optionally, that its value checks out.
  """
  def assert_property(doc, prop_name, check_fn \\ fn (_actual) -> true end)

  def assert_property(doc, prop_name, check_fn) when is_binary(doc) do
    assert_property(Document.parse!(doc), prop_name, check_fn)
  end
  def assert_property(doc, prop_name, check_fn) do
    prop_val = Document.get_property_lazy(doc, prop_name,
      fn -> flunk "#{prop_name} is absent" end)

    assert check_fn.(prop_val)
  end

  @doc"""
    Asserts that a link exists and, optionally, that its target checks out.
  """
  def assert_link_target(doc, rel, check_fn \\ fn (_actual) -> true end)

  def assert_link_target(doc, rel, check_fn) when is_binary(doc) do
    assert_link_target(Document.parse!(doc), rel, check_fn)
  end
  def assert_link_target(doc, rel, check_fn) do
    link_targets =
      doc
      |> Document.get_links_lazy(rel, fn -> flunk "#{rel} link is absent" end)
      |> Enum.map(&Link.target_url(&1))
      |> Enum.map(&elem(&1, 1))

    assert link_targets |> Enum.any?(&check_fn.(&1)), "expected `#{link_targets}` to be ..."
  end
end
