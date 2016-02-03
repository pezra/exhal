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

  ExHal can also make requests. Continuing the example above:

  ```elixir
  ExHal.follow_link(doc, "profile")
  {:error, %ExHal.Error{reason: "multiple choices"}}

  ExHal.follow_link(doc, "profile")
  {:error, %ExHal.Error{reason: "no such link"}}

  ExHal.follow_link("self")
  {:ok, %ExHal.Document{...}}

  ExHal.follow_link(doc, "profile", pick_volunteer: true)
  {:ok, %ExHal.Document{...}}

  ExHal.follow_links(doc, "profile")
  [{:ok, %ExHal.Document{...}}, {:ok, %ExHal.Document{...}}]

  ```

  """

  alias ExHal.Link, as: Link
  alias ExHal.Document, as: Document
  alias ExHal.Error, as: Error

  @doc """
  Returns a new `%ExHal.Document` representing the HAL document provided.
  """
  def parse(hal_str) do
    parsed = Poison.Parser.parse!(hal_str)

    Document.from_parsed_hal(parsed)
  end

  @doc """
  Follows a link in a HAL document.

  Returns `{:ok,    %ExHal.Document{...}}` if request is an error
          `{:error, %ExHal.Error{...}}` if not
  """
  def follow_link(a_doc, name, opts \\ %{pick_volunteer: false, tmpl_vars: %{}}) do
    pick_volunteer? = Dict.get opts, :pick_volunteer, false
    tmpl_vars = Dict.get opts, :tmpl_vars, %{}

    case figure_link(a_doc, name, pick_volunteer?) do
      {:error, e} -> {:error, e}
      {:ok, link} -> Link.follow(link, tmpl_vars)
    end

  end

  @doc """
  Follows all links of a particular rel in a HAL document.

  Returns `[{:ok, %ExHal.Document{...}}, {:error, %ExHal.Error{...}, ...]`
  """
  def follow_links(a_doc, name, opts \\ %{tmpl_vars: %{}}) do
    tmpl_vars = Dict.get opts, :tmpl_vars, %{}

    case get_links_lazy(a_doc, name, fn -> :missing end) do
      :missing -> {:error, %Error{reason: "no such link: #{name}"}}

      links    -> Enum.map(links, fn link -> Link.follow(link, tmpl_vars) end)
    end

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

  defp figure_link(a_doc, name, pick_volunteer?) do
    case get_links_lazy(a_doc, name, fn -> :missing end) do
      :missing -> {:error, %Error{reason: "no such link: #{name}"}}

      (ls = [_|[_|_]]) -> if pick_volunteer? do
                             {:ok, List.first(ls)}
                           else
                             {:error, %Error{reason: "multiple choices"}}
                           end

      [l] -> {:ok, l}
    end
  end
end
