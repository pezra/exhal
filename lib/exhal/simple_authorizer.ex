defmodule ExHal.SimpleAuthorizer do
  @moduledoc """

  An authorizer that always sets the `Authorization` header
  field to a fixed value.

  """

  alias ExHal.Authorizer

  @typedoc """
  An authorizer that returns a fixed string for resources at a particular server.
  """
  @opaque t :: %__MODULE__{}

  defstruct([:authorization, :url_prefix])

  @spec new(Authorizer.url(), Authorizer.credentials()) :: t()
  @doc """

  Create a new #{__MODULE__}.

  """
  def new(url_prefix, authorization_str),
    do: %__MODULE__{authorization: authorization_str, url_prefix: url_prefix}

  defimpl ExHal.Authorizer do
    @spec authorization(Authorizer.t(), Authorizer.url()) :: %{optional(Authorizer.header_field_name()) => String.t()}
    def authorization(authorizer, url) do
      url
      |> String.starts_with?(authorizer.url_prefix)
      |> if do
        %{"Authorization" =>  authorizer.authorization}
      else
        %{}
      end
    end
  end

end

