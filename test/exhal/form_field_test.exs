defmodule ExHal.FormFieldTest do
  use ExUnit.Case, async: true

  alias ExHal.FormField

  doctest ExHal.FormField

  describe ".from_field_entry/1" do
    test "invalid field json" do
      invalid_field_json = %{
        "type" => "string"
      }

      assert_raise(ArgumentError, fn -> FormField.from_field_entry(invalid_field_json) end)
    end

    test "valid field json" do
      valid_field_json = %{
        "name" => "foo",
        "type" => "string"
      }

      assert %FormField{} = FormField.from_field_entry(valid_field_json)
    end

    test "extracts name correctly" do
      valid_field_json = %{
        "name" => "foo",
        "type" => "string"
      }

      assert "foo" == FormField.from_field_entry(valid_field_json).name
    end

    test "extract string type correctly" do
      valid_field_json = %{
        "name" => "foo",
        "type" => "string"
      }

      assert :string == FormField.from_field_entry(valid_field_json).type
    end
  end

  describe ".set_value/2" do
    setup do
      string_field = FormField.from_field_entry(%{"name" => "foo", "type" => "string"})

      {:ok, %{string_field: string_field}}
    end

    test "returns form field", %{string_field: field} do
      assert %FormField{} = FormField.set_value(field, "new value")
    end

    test "returned field has correct value", %{string_field: field} do
      assert %FormField{value: "new value"} = FormField.set_value(field, "new value")
    end
  end
end
