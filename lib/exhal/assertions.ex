defmodule ExHal.Assertions do
  @moduledoc """
  Convenience functions for asserting things about HAL documents

  ```elixir
  iex> import ExUnit.Assertions
  nil
  iex> import ExHal.Assertions
  nil
  iex> assert_property ~s({"name": "foo"}), "name"
  true
  iex> assert_property ~s({"name": "foo"}), "address"
  ** (ExUnit.AssertionError) address is absent
  iex> assert_property ~s({"name": "foo"}), "name", eq "foo"
  true
  iex> assert_property ~s({"name": "foo"}), "name", matches ~r/fo/
  true
  iex> assert_property ~s({"name": "foo"}), "name", eq "bar"
  ** (ExUnit.AssertionError) expected property `name` to eq("bar")
  iex> assert_link_target ~s({"_links": { "profile": {"href": "http://example.com" }}}),
  ...>   "profile"
  true
  iex> assert_link_target ~s({"_links": { "profile": {"href": "http://example.com" }}}),
  ...>   "item"
  ** (ExUnit.AssertionError) link `item` is absent
  iex> assert_link_target ~s({"_links": { "profile": {"href": "http://example.com" }}}),
  ...>   "profile", eq "http://example.com"
  true
  iex> assert_link_target ~s({"_links": { "profile": {"href": "http://example.com" }}}),
  ...>   "profile", matches ~r/example.com/
  true
  iex> assert_link_target ~s({"_links": { "profile": {"href": "http://example.com" }}}),
  ...>   "profile", eq "http://bad.com"
  ** (ExUnit.AssertionError) expected (at least one) `item` link to eq("http://bad.com") but found only http://example.com
  iex> assert collection("{}") |> Enum.empty?
  true
  iex> assert 1 == collection("{}") |> Enum.count
  ** (ExUnit.AssertionError) Assertion with == failed
  ```
  """

  import ExUnit.Assertions
  alias ExHal.{Document, Link, Collection}

  @doc """
  Returns a stream representation of the document.
  """
  def collection(doc) when is_binary(doc) do
    Document.parse!(doc) |> collection
  end

  def collection(doc) do
    Collection.to_stream(doc)
  end

  @doc """
  Returns a function that checks if the actual value is equal to the expected.
  """
  def eq(expected) do
    fn actual -> actual == expected end
  end

  @doc """
  Returns a function that checks if the actual value matches the expected pattern.
  """
  def matches(expected) do
    fn actual -> actual =~ expected end
  end

  @doc """
  Asserts that a property exists and, optionally, that its value checks out.
  """
  defmacro assert_property(doc, rel) do
    quote do
      p_assert_property(unquote(doc), unquote(rel), fn _ -> true end, nil)
    end
  end

  defmacro assert_property(doc, rel, check_fn) do
    check_desc = Macro.to_string(check_fn)

    quote do
      p_assert_property(unquote(doc), unquote(rel), unquote(check_fn), unquote(check_desc))
    end
  end

  @doc """
  Asserts that the specifed link exists and that its target checks out.
  """
  defmacro assert_link_target(doc, rel) do
    quote do
      p_assert_link_target(unquote(doc), unquote(rel), fn _ -> true end, nil)
    end
  end

  defmacro assert_link_target(doc, rel, check_fn) do
    check_desc = Macro.to_string(check_fn)

    quote do
      p_assert_link_target(unquote(doc), unquote(rel), unquote(check_fn), unquote(check_desc))
    end
  end

  # internal functions

  @spec p_assert_property(String.t() | Document.t(), String.t(), (any() -> boolean()), String.t()) ::
          any()
  def p_assert_property(doc, prop_name, check_fn, check_desc) when is_binary(doc) do
    p_assert_property(Document.parse!(doc), prop_name, check_fn, check_desc)
  end

  def p_assert_property(doc, prop_name, check_fn, check_desc) do
    prop_val =
      Document.get_property_lazy(doc, prop_name, fn -> flunk("#{prop_name} is absent") end)

    assert check_fn.(prop_val), "expected property #{prop_name} to #{check_desc}"
  end

  def p_assert_link_target(doc, rel, check_fn, check_desc) when is_binary(doc) do
    p_assert_link_target(Document.parse!(doc), rel, check_fn, check_desc)
  end

  def p_assert_link_target(doc, rel, check_fn, check_desc) do
    link_targets =
      doc
      |> Document.get_links_lazy(rel, fn -> flunk("#{rel} link is absent") end)
      |> Enum.map(&Link.target_url(&1))
      |> Enum.map(&elem(&1, 1))

    assert link_targets |> Enum.any?(&check_fn.(&1)),
           "expected (at least one) `#{rel}` link to #{check_desc} but found only #{link_targets}`"
  end
end
