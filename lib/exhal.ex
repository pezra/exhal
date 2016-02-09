defmodule ExHal do
  @moduledoc """
    Use HAL APIs with ease.

    ## Example

    Consider a resource `http://example.com/hal` whose HAL representation looks like

    ```json
    { "name": "Hello!",
      "_links": {
         "self"   : { "href": "http://example.com" },
          "profile": [{ "href": "http://example.com/special" },
                      { "href": "http://example.com/normal" }]
      }
    }
    ```

    ```elixir
    iex> doc = ExHal.client
    ...> |> ExHal.Client.with_headers("User-Agent": "MyClient/1.0")
    ...> |> ExHal.Client.get("http://example.com/hal")
    %ExHal.Document{...}

    iex> ExHal.follow_link(doc, "profile")
    {:error, %ExHal.Error{reason: "multiple choices"}}

    iex> ExHal.follow_link(doc, "nonexistent")
    {:error, %ExHal.Error{reason: "no such link"}}

    iex> ExHal.follow_link("self")
    {:ok, %ExHal.Document{...}}

    iex> ExHal.follow_link(doc, "profile", pick_volunteer: true)
    {:ok, %ExHal.Document{...}}

    iex> ExHal.follow_links(doc, "profile")
    [{:ok, %ExHal.Document{...}}, {:ok, %ExHal.Document{...}}]

    iex> ExHal.follow_links(doc, "profile", headers: ["Content-Type": "application/vnd.custom.json+type"])
    [{:ok, %ExHal.Document{...}}, {:ok, %ExHal.Document{...}}]
    ```
    """

  alias ExHal.Link
  alias ExHal.Document
  alias ExHal.Error
  alias ExHal.Client

  @doc """
    Returns a default client
    """
  def client do
    %Client{}
  end

  @doc """
  Follows a link in a HAL document.

  Returns `{:ok,    %ExHal.Document{...}}` if request is an error
          `{:error, %ExHal.Error{...}}` if not
  """
  def follow_link(a_doc, name, opts \\ %{tmpl_vars: %{}, pick_volunteer: false, headers: []}) do
    opts = Map.new(opts)
    pick_volunteer? = Map.get opts, :pick_volunteer, false

    case figure_link(a_doc, name, pick_volunteer?) do
      {:error, e} -> {:error, e}
      {:ok, link} -> Link.follow(link, a_doc.client, opts)
    end

  end

  @doc """
  Follows all links of a particular rel in a HAL document.

  Returns `[{:ok, %ExHal.Document{...}}, {:error, %ExHal.Error{...}, ...]`
  """
  def follow_links(a_doc, name, opts \\ %{tmpl_vars: %{}, headers: []}) do
    opts = Map.new(opts)

    case get_links_lazy(a_doc, name, fn -> :missing end) do
      :missing -> [{:error, %Error{reason: "no such link: #{name}"}}]
      links    -> Enum.map(links, fn link -> Link.follow(link, a_doc.client, opts) end)
    end

  end

  @doc """
  Posts data to the named link in a HAL document.

  Returns `{:error, %ExHal.Error{...}}` if request is an error
          `{:ok,    %ExHal.Document{...}}` if not
  """
  def post(a_doc, name, body) do
    case figure_link(a_doc, name, false) do
      {:error, e} -> {:error, e}
      {:ok, link} -> Link.post(link, body, a_doc.client)
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
    Map.get_lazy(a_doc.properties, prop_name, default_fun)
  end

  @doc """
  Returns `[%Link{}...]`     when link exists
          result of `default_fun` otherwise
  """
  def get_links_lazy(a_doc, link_name, default_fun) do
    Map.get_lazy(a_doc.links, link_name, default_fun)
  end

  @doc """
  Returns `{:ok, <url of specified document>}`
          `:error`
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
