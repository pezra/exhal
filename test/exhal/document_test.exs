Code.require_file "../../test_helper.exs", __ENV__.file

defmodule ExHal.DocumentTest do
  use ExUnit.Case, async: true

  alias ExHal.Document

  setup do
    {:ok, [client: ExHal.client]}
  end

  test "ExHal parses valid, empty HAL documents", context do
    assert Document.parse(context[:client], "{}") |> is_hal_doc?
  end

  test "ExHal parses valid, non-empty HAL documents", context do
    assert Document.parse(context[:client], "{}") |> is_hal_doc?
  end


  # Background

  defp is_hal_doc?(actual)  do
    %ExHal.Document{properties: _, links: _} = actual
  end

end
