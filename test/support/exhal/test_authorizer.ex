defmodule ExHal.TestAuthorizer do
  defstruct([:headers])

  defimpl ExHal.Authorizer do
    def authorization(auther, _url), do: auther.headers
  end
end
