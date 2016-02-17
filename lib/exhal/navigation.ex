defmodule ExHal.Navigation do
  alias ExHal.Link
  alias ExHal.Error
  alias ExHal.Client
  import ExHal

  @doc """
  Follows a link in a HAL document.

  Returns `{:ok,    %ExHal.Document{...}}` if response is successful; 
  `{:error, %ExHal.Error{...}}` if not
  """
  def follow_link(a_doc, name, opts \\ %{tmpl_vars: %{}, strict: false, headers: []}) do
    opts = Map.new(opts)
    pick_volunteer? = !(Map.get opts, :strict, false)

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

  # privates

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
