defmodule ExHal.NonHalResponseTest do
  use ExUnit.Case, async: true
  alias ExHal.NonHalResponse

  test "Locatable with Location header" do
    r = %NonHalResponse{status_code: 200, headers: [{"Location", "http://example.com"}], body: ""}

    assert "http://example.com" == ExHal.Locatable.url(r)
  end

  test "Locatable with Content-Location header" do
    r = %NonHalResponse{status_code: 200, headers: [{"Content-Location", "http://example.com"}], body: ""}

    assert "http://example.com" == ExHal.Locatable.url(r)
  end

  test "Locatable with non-locatable response" do
    r = %NonHalResponse{status_code: 200, headers: [], body: ""}

    assert :error == ExHal.Locatable.url(r)
  end

end
