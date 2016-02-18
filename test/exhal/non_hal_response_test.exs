defmodule ExHal.NonHalResponseTest do
  use ExUnit.Case, async: true
  alias ExHal.NonHalResponse

  test "Locatable" do
    r = %NonHalResponse{status_code: 200, headers: [Location: "http://example.com"], body: ""}

    assert "http://example.com" == ExHal.Locatable.url(r)
  end
end
