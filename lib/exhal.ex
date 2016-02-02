defmodule ExHal do
  @moduledoc """
  Use HAL APIs with ease.

  ## Example
  ```elixir

  iex> doc = ExHal.parse(~s|
  ...> { "name": "Hello!",
  ...>    "_links": {
  ...>      "self"   : { "href": "http://example.com" },
  ...>      "profile": [{ "href": "http://example.com/special" },
  ...>                  { "href": "http://example.com/normal" }]
  ...>   }
  ...> }
  ...> |)
  %ExHal.Document{links: %{"profile" => [%ExHal.Link{name: nil, rel: "profile", target: nil,
                href: "http://example.com/normal", templated: false},
               %ExHal.Link{name: nil, rel: "profile", target: nil, href: "http://example.com/special",
                templated: false}],
              "self" => [%ExHal.Link{name: nil, rel: "self", target: nil, href: "http://example.com",
                templated: false}]}, properties: %{"name" => "Hello!"}}
  iex> ExHal.url(doc)
  {:ok, "http://example.com"}
  iex> ExHal.fetch(doc, "name")
  {:ok, "Hello!"}
  iex> ExHal.fetch(doc, "non-existent")
  :error
  iex> ExHal.fetch(doc, "profile")
  {:ok,
   [%ExHal.Link{name: nil, rel: "profile", target: nil,
                href: "http://example.com/normal",
                templated: false},
    %ExHal.Link{name: nil, rel: "profile", target: nil,
                href: "http://example.com/special",
                templated: false}]}
  iex> ExHal.get_links_lazy(doc, "profile", fn -> [] end)
  [%ExHal.Link{name: nil, rel: "profile", target: nil,
               href: "http://example.com/normal",
               templated: false},
   %ExHal.Link{name: nil, rel: "profile", target: nil,
               href: "http://example.com/special",
               templated: false}]
  iex> ExHal.get_links_lazy(doc, "alternate", fn -> [] end)
  []

  ```
  """

  alias ExHal.Link, as: Link
  alias ExHal.Document, as: Document

  @doc """
  Returns a new `%ExHal.Document` representing the HAL document provided.
  """
  def parse(hal_str) do
    parsed = Poison.Parser.parse!(hal_str)

    Document.from_parsed_hal(parsed)
  end

  @doc """
  Fetches value of specified property or links whose `rel` matches

  Returns `{:ok, <property value>}` if `name` identifies a property;
          `{:ok, [%Link{}, ...]}`   if `name` identifies a link;
          `:error`                  othewise
  """
  def fetch(a_document, name) do
    case get_lazy(a_document, name, fn -> :error end) do
      :error -> :error
      result -> {:ok, result}
    end
  end

  @doc """
  Returns link or property of the specified name, or the result of `default_fun`
  if neither are found.
  """
  def get_lazy(a_doc, name, default_fun) do
    get_property_lazy(a_doc, name,
      fn -> get_links_lazy(a_doc, name, default_fun) end
    )
  end

  @doc """
  Returns `<property value>` when property exists
          result of `default_fun` otherwise
  """
  def get_property_lazy(a_doc, prop_name, default_fun) do
    Dict.get_lazy(a_doc.properties, prop_name, default_fun)
  end

  @doc """
  Returns `[%Link{}...]`     when link exists
          result of `default_fun` otherwise
  """
  def get_links_lazy(a_doc, link_name, default_fun) do
    Dict.get_lazy(a_doc.links, link_name, default_fun)
  end

  @doc """
  Returns `{:ok, <url of specified document>}`
  """
  def url(a_doc, default_fn \\ fn (_doc) -> :error end) do
    case ExHal.fetch(a_doc, "self") do
      :error            -> default_fn.(a_doc)
      {:ok, [link | _]} -> Link.target_url(link)
    end
  end
end
