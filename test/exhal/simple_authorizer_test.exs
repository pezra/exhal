defmodule ExHal.SimpleAuthorizerTest do
  use ExUnit.Case, async: true
  alias ExHal.{Authorizer, SimpleAuthorizer}

  test ".new/2" do
    assert SimpleAuthorizer.new("http://example.com", "Bearer my-word-is-my-bond")
  end

  describe ".authorization/2" do
    test "alien resource" do
      assert :no_auth =
               Authorizer.authorization(simple_authorizer_factory(), "http://malware.com")
    end

    test "subtly alien resource" do
      assert :no_auth =
               Authorizer.authorization(simple_authorizer_factory(), "http://mallory.example.com")
    end

    test "recognized resource" do
      assert {:ok, "Bearer hello-beautiful"} =
               Authorizer.authorization(
                 simple_authorizer_factory("Bearer hello-beautiful"),
                 "http://example.com/foo"
               )
    end
  end

  defp simple_authorizer_factory(auth_string \\ "Bearer sometoken") do
    SimpleAuthorizer.new("http://example.com", auth_string)
  end
end
