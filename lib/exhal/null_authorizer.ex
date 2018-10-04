defmodule ExHal.NullAuthorizer do
  @moduledoc """

  A placeholder authorizer that adds nothing to the request.

  """

  @typedoc """
  An authorizer that always responds :no_auth
  """
  @opaque t :: %__MODULE__{}

  defstruct([])

  @spec new() :: t()
  def new(), do: %__MODULE__{}

  defimpl ExHal.Authorizer do
    @spec authorization(Authorizer.t(), Authorizer.url()) :: %{optional(Authorizer.header_field_name()) => String.t()}
    def authorization(_authorizer, _url), do: %{}
  end

end


