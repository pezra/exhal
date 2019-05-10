defmodule ExHal.Navigation do
  alias ExHal.Link
  alias ExHal.{Error, NoSuchLinkError}
  alias ExHal.ResponseHeader

  @doc """
  Follows a link in a HAL document.

  Returns `{:ok, %ExHal.Document{...}, %ExHal.ResponseHeader{...}}` if response is successful;
  `{:error, %ExHal.Error{...}}` if not
  """
  def follow_link(a_doc, name, opts \\ %{tmpl_vars: %{}, strict: false, headers: []}) do
    {tmpl_vars, strict?, opts} = interpret_nav_opts(opts)

    case figure_link(a_doc, name, strict?) do
      {:error, e} -> {:error, e}
      {:ok, link} -> _follow_link(a_doc.client, link, tmpl_vars, opts)
    end
  end

  @doc """
  Follows all links of a particular rel in a HAL document.

  Returns `[{:ok, %ExHal.Document{...}, %ExHal.ResponseHeader{...}}, {:error, %ExHal.Error{...} ...]` if link is found;
  `{:error, %ExHal.NoSuchLinkError{...}` if not
  """
  def follow_links(a_doc, name, opts) when is_map(opts) or is_list(opts) do
    follow_links(
      a_doc,
      name,
      fn _name -> {:error, %NoSuchLinkError{reason: "no such link: #{name}"}} end,
      opts
    )
  end

  def follow_links(a_doc, name, missing_link_handler, opts \\ %{}) do
    case ExHal.get_links_lazy(a_doc, name, fn -> :missing end) do
      :missing -> missing_link_handler.(name)
      links ->
        {tmpl_vars, _strict?, opts} = interpret_nav_opts(opts)
        _follow_links(a_doc.client, links, tmpl_vars, opts)
    end
  end

  def follow_links(a_doc, name) do
    follow_links(a_doc, name, %{})
  end

  @doc """
  Posts data to the named link in a HAL document.

  Returns `{:ok, %ExHal.Document{...}, %ExHal.ResponseHeader{...}}` if response is successful and body is HAL;
  `{:error, %ExHal.Error{...}}` if response is an error if not
  """
  def post(a_doc, name, body, opts \\ %{tmpl_vars: %{}, strict: true}) do
    update_document(a_doc, name, body, opts, &client_module().post/4)
  end

  @doc """
  PUTs data to the named link in a HAL document.

  Returns `{:ok, %ExHal.Document{...}, %ExHal.ResponseHeader{...}}` if response is successful and body is HAL;
  `{:error, %ExHal.Error{...}}` if response is an error if not
  """
  def put(a_doc, name, body, opts \\ %{tmpl_vars: %{}, strict: true}) do
    update_document(a_doc, name, body, opts, &client_module().put/4)
  end

  @doc """
  PATCHs data to the named link in a HAL document.

  Returns `{:ok, %ExHal.Document{...}, %ExHal.ResponseHeader{...}}` if response is successful and body is HAL;
  `{:error, %ExHal.Error{...}}` if response is an error if not
  """
  def patch(a_doc, name, body, opts \\ %{tmpl_vars: %{}, strict: true}) do
    update_document(a_doc, name, body, opts, &client_module().patch/4)
  end

  defp update_document(a_doc, name, body, opts, fun) do
    {tmpl_vars, strict?, opts} = interpret_nav_opts(opts)

    case figure_link(a_doc, name, strict?) do
      {:error, e} -> {:error, e}
      {:ok, link} -> fun.(a_doc.client, Link.target_url!(link, tmpl_vars), body, opts)
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
    {tmpl_vars, strict?, _opts} = interpret_nav_opts(opts)

    case figure_link(a_doc, name, strict?) do
      {:ok, link} -> find_link_target(link, tmpl_vars)
      r = _ -> r
    end
  end

  @doc """
  Returns `{:ok, [url1, ...]}` if a matching link is found or `{:error, %ExHal.NoSuchLinkError{...}}` if not.

  * a_doc - `ExHal.Document` in which to search for links
  * name - the rel of the link of interest
  * opts
    * `:tmpl_vars` - `Map` of variables with which to expand any templates found. Default: `%{}`
  """
  def link_targets(a_doc, name, opts \\ %{}) do
    {tmpl_vars, _strict?, _opts} = interpret_nav_opts(opts)

    case ExHal.get_links_lazy(a_doc, name, fn -> :missing end) do
      :missing ->
        {:error, %NoSuchLinkError{reason: "no such link: #{name}"}}

      links ->
        {:ok,
         links
         |> Enum.map(fn link ->
           {:ok, target} = find_link_target(link, tmpl_vars)
           target
         end)}
    end
  end

  def link_targets_lazy(a_doc, name, opts \\ %{}, fun) do
    case link_targets(a_doc, name, opts) do
      {:ok, links} -> links
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

  defp figure_link(a_doc, name, strict?) do
    case ExHal.get_links_lazy(a_doc, name, fn -> :missing end) do
      :missing ->
        {:error, %NoSuchLinkError{reason: "no such link: #{name}"}}

      [link] ->
        {:ok, link}

      [first | _rest] ->
        if strict? do
          {:error, %Error{reason: "multiple choices"}}
        else
          {:ok, first}
        end
    end
  end

  defp _follow_links(client, [link], tmpl_vars, opts) do
    [_follow_link(client, link, tmpl_vars, opts)]
  end

  defp _follow_links(client, links, tmpl_vars, opts) do
    {:ok, tsup} = Task.Supervisor.start_link()

    try do
      Task.Supervisor.async_stream_nolink(tsup, links, &_follow_link(client, &1, tmpl_vars, opts),
        figure_async_links_options(opts))
      |> Enum.map(fn
        {:ok, followed_link} -> followed_link
        {:exit, reason} -> raise inspect(reason)
      end)
    after
      Supervisor.stop(tsup, :normal)
    end
  end

  defp _follow_link(client, link, tmpl_vars, opts) do
    cond do
      Link.embedded?(link) ->
        {:ok, link.target, %ResponseHeader{status_code: 200}}

      :else ->
        client_module().get(client, Link.target_url!(link, tmpl_vars), opts)
    end
  end

  @typep template_vars :: map()
  @typep poison_options :: map()

  @spec interpret_nav_opts(map()) :: {template_vars(), boolean(), poison_options()}
  defp interpret_nav_opts(%{} = opts) do
    {nav_options, poison_options} = Map.split(opts, [:tmpl_vars, :strict])

    {Map.get(nav_options, :tmpl_vars, %{}), Map.get(nav_options, :strict, false), poison_options}
  end

  defp interpret_nav_opts(opts) do
    opts
    |> Map.new()
    |> interpret_nav_opts()
  end

  @default_poison_timeout 5000
  @default_poison_recv_timeout 8000
  @default_async_stream_timeout :timer.seconds(60)

  defp figure_async_links_options(poison_options) do
    # respect any timeout settings from the user
    timeout = case Map.take(poison_options, [:timeout, :recv_timeout]) do
      %{timeout: timeout, recv_timeout: recv_timeout} -> timeout + recv_timeout
      %{timeout: timeout} -> timeout + @default_poison_recv_timeout
      %{recv_timeout: recv_timeout} -> recv_timeout + @default_poison_timeout
      _ -> @default_async_stream_timeout
    end

    [timeout: timeout]
  end

  defp client_module(), do: Application.get_env(:exhal, :client, ExHal.Client)
end
