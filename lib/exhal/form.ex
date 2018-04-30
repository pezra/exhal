defmodule ExHal.Form do
  @moduledoc """

  Represents a [Dwolla style HAL
  form](https://github.com/Dwolla/hal-forms). Generally these are
  acquired from `ExHal.Document.get_form/2`,
  `ExHal.Document.fetch_form/2`, etc

  """

  alias ExHal.{
    FormField,
    JsonFormEncoder
  }

  @typedoc """
  A from that can be completed and submitted. This type is opaque and
  should use only as a argument to functions in this `ExHal.Form` module.
  """
  @opaque t :: %__MODULE__{}

  defstruct [
    :target,
    :method,
    :content_type,
    :fields
  ]

  @spec from_forms_entry(%{}) :: __MODULE__.t()
  @doc """
  Creates a new form from raw form JSON.

  Raises `ArgumentError` if `a_map` is not a valid form fragment.
  """
  def from_forms_entry(a_map) do
    %__MODULE__{
      target: extract_target(a_map),
      method: extract_method(a_map),
      content_type: extract_content_type(a_map),
      fields: extract_fields(a_map)
    }
  end

  @spec get_fields(__MODULE__.t()) :: [FormField.t()]
  @doc """
  Returns list of the fields in this form.
  """
  def get_fields(a_form) do
    a_form.fields
  end

  @spec set_field_value(__MODULE__.t(), String.t(), FormField.field_value()) :: __MODULE__.t()
  @doc """
  Returns form with the specified fields value updated.

  Raises `ArgumentError` if the specified field doesn't exist.
  """
  def set_field_value(form, field_name, new_value) do
    updated_field =
      get_field(form, field_name)
      |> FormField.set_value(new_value)

    replace_field(form, field_name, updated_field)
  end

  @spec submit(__MODULE__.t(), Client.t()) :: Client.http_response()
  @doc """
  Submits form and returns the response.
  """
  def submit(form, client) do
    apply(client_module(),
      form.method,
      [client,
       form.target,
       encode(form),
       [headers: ["Content-Type": form.content_type]]
      ]
    )
  end

  # --- private functions ---

  def client_module do
    Application.get_env(:exhal, :client, ExHal.Client)
  end

  defp encode(form) do
    cond do
      Regex.match?(~r/application\/json/i, form.content_type) ->
        JsonFormEncoder.encode(form)

      Regex.match?(~r/\+json$/i, form.content_type) ->
        JsonFormEncoder.encode(form)

      true ->
        raise ArgumentError, "unrecognized content type: #{form.content_type.inspect}"
    end
  end

  defp get_field(form, field_name) do
    form
    |> get_fields()
    |> Enum.find(&(&1.name == field_name)) || raise(ArgumentError, "no such field: #{field_name}")
  end

  defp replace_field(form, field_name, updated_field) do
    fields_sans_update =
      form
      |> get_fields()
      |> Enum.reject(&(&1.name == field_name))

    %__MODULE__{form | fields: [updated_field | fields_sans_update]}
  end

  defp extract_target(a_map) do
    case get_in(a_map, ["_links", "target", "href"]) do
      nil ->
        raise ArgumentError, "form target link missing"

      val ->
        val
    end
  end

  defp extract_method(a_map) do
    Map.get_lazy(a_map, "method", fn -> raise ArgumentError, "form method missing" end)
    |> String.downcase
    |> String.to_atom
  end

  defp extract_content_type(a_map) do
    Map.get_lazy(a_map, "contentType", fn -> raise ArgumentError, "form contentType missing" end)
  end

  defp extract_fields(a_map) do
    a_map["fields"]
    |> Enum.map(fn entry -> FormField.from_field_entry(entry) end)
  end
end
