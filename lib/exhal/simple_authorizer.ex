defmodule ExHal.SimpleAuthorizer do
  alias ExHal.Authorizer

  @typedoc """
  An authorizer that returns a fixed string for resources at a particular server.
  """
  @opaque t :: %__MODULE__{}

  defstruct([:authorization, :url_prefix])

  @spec new(Authorizer.url(), Authorizer.authorization_field_value()) :: __MODULE__.t()
  def new(url_prefix, authorization_str),
    do: %__MODULE__{authorization: authorization_str, url_prefix: url_prefix}
end

defimpl ExHal.Authorizer, for: ExHal.SimpleAuthorizer do
  def authorization(authorizer, url) do
    url
    |> String.starts_with?(authorizer.url_prefix)
    |> if do
      {:ok, authorizer.authorization}
    else
      :no_auth
    end
  end
end
