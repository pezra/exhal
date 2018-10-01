defmodule ExHal.NullAuthorizer do
  @typedoc """
  An authorizer that always responds :no_auth
  """
  @opaque t :: %__MODULE__{}

  defstruct([])

  def new(), do: %__MODULE__{}
end

defimpl ExHal.Authorizer, for: ExHal.NullAuthorizer do
  def authorization(_authorizer, _url), do: :no_auth
end
