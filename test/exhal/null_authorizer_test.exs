defmodule ExHal.NullAuthorizerTest do
  use ExUnit.Case, async: true
  alias ExHal.{Authorizer, NullAuthorizer}

  test ".new/0" do
    assert NullAuthorizer.new()
  end

  test ".authorization/2" do
    assert %{} == Authorizer.authorization(null_authorizer_factory(), "http://example.com")
  end

  defp null_authorizer_factory() do
    NullAuthorizer.new()
  end
end
