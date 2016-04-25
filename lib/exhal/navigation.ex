defmodule ExHal.Navigation do
  alias ExHal.Link
  alias ExHal.Error
  alias ExHal.Client

  @doc """
  Follows a link in a HAL document.

  Returns `{:ok,    %ExHal.Document{...}}` if response is successful;
  `{:error, %ExHal.Error{...}}` if not
  """
  def follow_link(a_doc, name, opts \\ %{tmpl_vars: %{}, strict: false, headers: []}) do
    opts = Map.new(opts)
    pick_volunteer? = !(Map.get opts, :strict, false)
    tmpl_vars = Map.get(opts, :tmpl_vars, %{})

    case figure_link(a_doc, name, pick_volunteer?) do
      {:error, e} -> {:error, e}
      {:ok, link} -> _follow_link(a_doc.client, link, tmpl_vars, opts)
    end

  end

  @doc """
  Follows all links of a particular rel in a HAL document.

  Returns `[{:ok, %ExHal.Document{...}}, {:error, %ExHal.Error{...}, ...]`
  """
  def follow_links(a_doc, name, opts) when is_map(opts) or is_list(opts) do
    follow_links(a_doc, name, fn _name -> [{:error, %Error{reason: "no such link: #{name}"}}] end, opts)
  end

  def follow_links(a_doc, name, missing_link_handler, opts \\ %{}) do
    opts = Map.new(opts)
    tmpl_vars = Map.get(opts, :tmpl_vars, %{})

    case ExHal.get_links_lazy(a_doc, name, fn -> :missing end) do
      :missing -> missing_link_handler.(name)
      links    -> Enum.map(links, &_follow_link(a_doc.client, &1, tmpl_vars, opts))
    end

  end

  def follow_links(a_doc, name) do
    follow_links(a_doc, name, %{})
  end

  @doc """
  Posts data to the named link in a HAL document.

  Returns `{:ok, %ExHal.Document{...}}` if response is successful and body is HAL;
  `{:error, %ExHal.Error{...}}` if response is an error if not
  """
  def post(a_doc, name, body, opts \\ %{tmpl_vars: %{}, strict: true}) do
    pick_volunteer? = !(Map.get opts, :strict, true)
    tmpl_vars = Map.get(opts, :tmpl_vars, %{})

    case figure_link(a_doc, name, pick_volunteer?) do
      {:error, e} -> {:error, e}
      {:ok, link} -> Client.post(a_doc.client, Link.target_url!(link, tmpl_vars), body, opts)
    end
  end

  @doc """
  PUTs data to the named link in a HAL document.

  Returns `{:ok, %ExHal.Document{...}}` if response is successful and body is HAL;
  `{:error, %ExHal.Error{...}}` if response is an error if not
  """
  def put(a_doc, name, body, opts \\ %{tmpl_vars: %{}, strict: true}) do
    pick_volunteer? = !(Map.get opts, :strict, true)
    tmpl_vars = Map.get(opts, :tmpl_vars, %{})

    case figure_link(a_doc, name, pick_volunteer?) do
      {:error, e} -> {:error, e}
      {:ok, link} -> Client.put(a_doc.client, Link.target_url!(link, tmpl_vars), body, opts)
    end
  end

  @doc """
    Returns `{:ok, url}` if a matching link is found or `{:error, %ExHal.Error{...}}` if not.

    * a_doc - `ExHal.Document` in which to search for links
    * name - the rel of the link of interest
    * opts
      * `:tmpl_vars` - `Map` of variables with which to expand any templates found. Default: `%{}`
      * `:strict` - true if the existence of multiple matching links should cause a failure. Default: `false`
    """
  def link_target(a_doc, name, opts \\ %{}) do
    opts = Map.new(opts)
    tmpl_vars = Map.get(opts, :tmpl_vars, %{})
    strict?   = Map.get(opts, :strict, false)

    case figure_link(a_doc, name, !strict?) do
      {:ok, link} -> find_link_target(link, tmpl_vars)
      (r = _) -> r
    end
  end

  def link_targets(a_doc, name, opts \\ %{}) do
    opts = Map.new(opts)
    tmpl_vars = Map.get(opts, :tmpl_vars, %{})
    case ExHal.get_links_lazy(a_doc, name, fn -> :missing end) do
      :missing -> {:error, %Error{reason: "no such link: #{name}"}}
      (links = [_|[_|_]]) ->
        links
        |> Enum.map(fn(link) -> {:ok, target} = find_link_target(link, tmpl_vars); target end)
    end
  end

  def link_targets_lazy(a_doc, name, opts \\ %{}, fun) do
    case link_targets(a_doc, name, opts) do
      links -> links
      {:error, _} -> fun.()
    end
  end

  def link_target_lazy(a_doc, name, opts \\ %{}, fun) do
    case link_target(a_doc, name, opts) do
      {:ok, target} -> target
      {:error, _} -> fun.()
    end
  end

  # privates

  defp find_link_target(link, tmpl_vars) do
    case Link.target_url(link, tmpl_vars) do
      :error -> {:error, %Error{reason: "link has no href member"}}
      successful -> successful
    end
  end

  defp figure_link(a_doc, name, pick_volunteer?) do
    case ExHal.get_links_lazy(a_doc, name, fn -> :missing end) do
      :missing -> {:error, %Error{reason: "no such link: #{name}"}}

      (ls = [_|[_|_]]) -> if pick_volunteer? do
                             {:ok, List.first(ls)}
                           else
                             {:error, %Error{reason: "multiple choices"}}
                           end

      [l] -> {:ok, l}
    end
  end

  defp _follow_link(client, link, tmpl_vars, opts) do
    cond do
      Link.embedded?(link) ->
        {:ok, link.target}
      :else ->
        Client.get(client, Link.target_url!(link, tmpl_vars), opts)
    end
  end
end
