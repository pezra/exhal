defmodule ExHal.JsonFormEncoderTest do
  use ExUnit.Case, async: true

  alias ExHal.{JsonFormEncoder, Form, FormField}
  import ExHal.Assertions

  describe ".encode/1" do
    test "correctly encodes empty form" do
      assert %{} == JsonFormEncoder.encode(valid_empty_form()) |> Poison.decode!()
    end

    test "correctly encodes string fields" do
      assert_property(
        JsonFormEncoder.encode(
          valid_empty_form()
          |> add_field(:string, "/string_field", "hello")
        ),
        "string_field",
        eq("hello")
      )
    end

    test "correctly encodes number fields" do
      assert_property(
        JsonFormEncoder.encode(valid_empty_form() |> add_field(:number, "/number_field", 42)),
        "number_field",
        eq(42)
      )
    end

    test "correctly encodes boolean fields" do
      assert_property(
        JsonFormEncoder.encode(valid_empty_form() |> add_field(:boolean, "/boolean_field", true)),
        "boolean_field",
        eq(true)
      )
    end
  end

  # helper functions

  defp valid_empty_form do
    %{
      "_links" => %{
        "target" => %{"href" => "http://example.com/foo"}
      },
      "method" => "POST",
      "contentType" => "application/json",
      "fields" => []
    }
    |> Form.from_forms_entry()
  end

  defp add_field(form, type, path, value) do
    field = %FormField{name: path, path: path, type: type, value: value}
    %Form{form | fields: [field | form.fields]}
  end
end
