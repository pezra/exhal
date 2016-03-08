defmodule ExHal do
  @moduledoc """
    Use HAL APIs with ease.

    Given a resource `http://example.com/hal` whose HAL representation looks like

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
    ...> |> ExHal.Client.add_headers("User-Agent": "MyClient/1.0")
    ...> |> ExHal.Client.get("http://example.com/hal")
    %ExHal.Document{...}
    ```

    Now we have an entry point to the API we can follow links to navigate around.

    ```exlixir
    iex> ExHal.follow_link(doc, "profile")
    {:ok, %ExHal.Document{...}}

    iex> ExHal.follow_link("self")
    {:ok, %ExHal.Document{...}}

    iex> ExHal.follow_links(doc, "profile")
    [{:ok, %ExHal.Document{...}}, {:ok, %ExHal.Document{...}}]
    ```

    We can specify headers for each request in addition to the headers specified in the client.

    ```elixir
    iex> ExHal.follow_links(doc, "profile",
                            headers: ["Accept": "application/vnd.custom.json+type"])
    [{:ok, %ExHal.Document{...}}, {:ok, %ExHal.Document{...}}]

    ```

    If we try to follow a non-existent or compound link with `ExHal.follow_link` it will return an error tuple.

    ```elixir
    iex> ExHal.follow_link(doc, "nonexistent")
    {:error, %ExHal.Error{reason: "no such link"}}

    iex> ExHal.follow_link(doc, "profile", strict: true)
    {:error, %ExHal.Error{reason: "multiple choices"}}
    ```

    If we try to follow a non-existent with `ExHal.follow_links` it will return a list of error tuples.

    ```elixir
    iex> ExHal.follow_links(doc, "nonexistent")
    [{:error, %ExHal.Error{reason: "no such link"}}]
    ```

    ### Collections

    Consider a resource `http://example.com/hal-collection` whose HAL representation looks like

    ```json
    { "_links": {
         "self"   : { "href": "http://example.com/hal-collection" },
          "item": [{ "href": "http://example.com/beginning" },
                   { "href": "http://example.com/middle" }]
          "next": { "href": "http://example.com/hal-collection?p=2" }
      }
    }
    ```
    and a resource `http://example.com/hal-collection?p=2` whose HAL representation looks like

    ```json
    { "_links": {
         "self"   : { "href": "http://example.com/hal-collection?p=2" },
          "item": [{ "href": "http://example.com/end" }]
      }
    }
    ```

    If we get the first HAL collection resource and turn it into a stream we can use all our favorite Stream functions on it.

    ```elixir
    iex> collection = ExHal.client
    ...> |> ExHal.Client.add_headers("User-Agent": "MyClient/1.0")
    ...> |> ExHal.Client.get("http://example.com/hal-collection")
    ...> |> ExHal.to_stream
    #Function<11.52512309/2 in Stream.resource/3>

    iex> Stream.map(collection, fn follow_results ->
    ...>   case follow_results do
    ...>     {:ok, a_doc} -> ExHal.url(a_doc)}
    ...>     {:error, _}  -> :error
    ...>   end
    ...> end )
    ["http://example.com/beginning", "http://example.com/middle", "http://example.com/end"]
    ```
    """


  alias ExHal.Link
  alias ExHal.Error
  alias ExHal.Client
  alias ExHal.Navigation

  @doc """
    Returns a default client
    """
  def client do
    %Client{}
  end

  defdelegate [
    follow_link(a_doc, name),
    follow_link(a_doc, name, opts),

    follow_links(a_doc, name),
    follow_links(a_doc, name, opts),

    post(a_doc, name, body),
    post(a_doc, name, body, opts),

    link_target(a_doc, name),
    link_target(a_doc, name, opts)
  ], to: Navigation

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
  Returns `<property value>` when property exists or result of `default_fun`
  otherwise
  """
  def get_property_lazy(a_doc, prop_name, default_fun) do
    Map.get_lazy(a_doc.properties, prop_name, default_fun)
  end

  @doc """
  Returns `[%Link{}...]` when link exists or result of `default_fun` otherwise.
  """
  def get_links_lazy(a_doc, link_name, default_fun) do
    Map.get_lazy(a_doc.links, link_name, default_fun)
  end

  @doc """
  Returns `{:ok, <url of specified document>}` or `:error`.
  """
  def url(a_doc, default_fn \\ fn (_doc) -> :error end) do
    case ExHal.Locatable.url(a_doc) do
      :error -> default_fn.(a_doc)
      url    -> url
    end
  end

  @doc """
    Returns a stream that yields the items in the rfc 6573 collection
    represented by `a_doc`.
    """
  def to_stream(a_doc) do
    ExHal.Collection.to_stream(a_doc)
  end
end

