defmodule ExHal.ClientTest do
  use ExUnit.Case, async: true

  alias ExHal.Client

  test "adding headers to client" do
    assert (%Client{}
            |> Client.add_headers("hello": "bob")
            |> Client.add_headers("hello": ["alice","jane"]))
    |> to_have_header("hello", ["bob", "alice", "jane"])
  end


  # background

  defp to_have_header(client, expected_name, expected_value) do
    expected_name = String.to_atom(expected_name)
    {:ok, actual_value} = Keyword.fetch(client.headers, expected_name)

    actual_value == expected_value
  end
end
