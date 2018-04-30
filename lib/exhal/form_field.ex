defmodule ExHal.FormField do
  @moduledoc """
  Functions for working with HAL form fields.
  """

  @typedoc """
  A HAL form field.
  """
  @type t :: %__MODULE__{
          name: String.t(),
          type: field_types,
          path: String.t(),
          value: field_value
        }
  defstruct [
    :name,
    :type,
    :path,
    :value
  ]

  @typedoc """
  Field types.
  """
  @type field_types ::
          :boolean
          | :string
          | :number
          | :date
          | :time
          | :datetime
          | :sensitive
          | :hidden
          | :text
          | :email
          | :tel
          | :file

  @typedoc """
  Possible value types.
  """
  @type field_value :: nil | true | false | list | float | integer | String.t()

  @spec from_field_entry(%{}) :: __MODULE__.t()
  @doc """
  Create a new form field from parsed form json.

  Raises `ArgumentError` if json is invalid.
  """
  def from_field_entry(a_map) do
    %__MODULE__{
      name: extract_name(a_map),
      type: extract_type(a_map),
      path: extract_path(a_map),
      value: extract_value(a_map)
    }
  end

  @spec set_value(__MODULE__.t(), field_value) :: __MODULE__.t()
  @doc """
  Returns a form field with the specified value.

  Raises `ArgumentError` if the new value is the wrong type.
  """
  def set_value(field, new_value) do
    %__MODULE__{field | value: new_value}
  end

  # Private functions
  defp extract_name(a_map) do
    a_map["name"] || raise(ArgumentError, "field name missing")
  end

  defp extract_type(a_map) do
    raw_type = a_map["type"] || raise(ArgumentError, "field name missing")

    cond do
      Regex.match?(~r/string/i, raw_type) ->
        :string

      true ->
        :string
    end
  end

  defp extract_path(a_map) do
    a_map["path"]
  end

  defp extract_value(a_map) do
    a_map["value"]
  end
end
