defmodule ExHal.NonHalResponseTest do
  use ExUnit.Case, async: true
  alias ExHal.NonHalResponse

  describe ".url/1" do
    test "with Location header" do
      r = %NonHalResponse{status_code: 200, headers: [{"Location", "http://example.com"}], body: ""}

      assert {:ok, "http://example.com"} == ExHal.Locatable.url(r)
    end

    test "with Content-Location header" do
      r = %NonHalResponse{status_code: 200, headers: [{"Content-Location", "http://example.com"}], body: ""}

      assert {:ok, "http://example.com"} == ExHal.Locatable.url(r)
    end

    test "with non-locatable response" do
      r = %NonHalResponse{status_code: 200, headers: [], body: ""}

      assert :error == ExHal.Locatable.url(r)
    end
  end
end
