defmodule ExHal.Transcoder do
  @moduledoc """
    Helps to build transcoders for HAL documents.

    Given a document like

    ```json
    {
      "name": "Jane Doe",
      "mailingAddress": "123 Main St",
      "_links": {
        "app:department": { "href": "http://example.com/dept/42" },
        "app:manager":    { "href": "http://example.com/people/84" }
      }
    }
    ```

    We can define an transcoder for it.

    ```elixir
    defmodule PersonTranscoder do
      use ExHal.Transcoder

      defproperty "name"
      defproperty "mailingAddress", param: :address
      deflink     "app:department", param: :department_url
      deflink     "app:manager",    param: :manager_id, value_converter: PersonUrlConverter
    end
    ```

    `PersonUrlConverter` is a module that has adopted the `ExHal.ValueConverter` behavior.

    ```elixir
    defmodule PersonUrlConverter do
      @behaviour ExHal.ValueConveter

      def from_hal(person_url) do
        to_string(person_url)
        |> String.split("/")
        |> List.last
      end

      def to_hal(person_id) do
        "http://example.com/people/\#{person_id}"
      end
    end
    ```

    We can use this transcoder to to extract the pertinent parts of the document into a map.

    ```elixir
    iex> PersonTranscoder.decode!(doc)
    %{name: "Jane Doe",
      address: "123 Main St",
      department_url: "http://example.com/dept/42",
      manager_id: 84}
    ```
    iex> PersonTranscoder.encode!(%{name: "Jane Doe",
      address: "123 Main St",
      department_url: "http://example.com/dept/42",
      manager_id: 84})
    ~s(
    {
      "name": "Jane Doe",
      "mailingAddress": "123 Main St",
      "_links": {
        "app:department": { "href": "http://example.com/dept/42" },
        "app:manager":    { "href": "http://example.com/people/84" }
       }
    } )
    ```
    """

  @type t :: module

  @callbackdoc"""
  Returns a decoded version of HAL document merged with the initial params.

  initial_params - the initial params with which the newly extracted info should
    merged.
  src_doc - the document to interpret
  opts - options for use by modules adopting ExHal.ValueConverterWithOptions behaviour
  """
  @callback decode!(ExHal.Document.t) :: %{}
  @callback decode!(%{}, ExHal.Document.t) :: %{}
  @callback decode!(ExHal.Document.t, keyword) :: %{}
  @callback decode!(%{}, ExHal.Document.t, keyword) :: %{}

  @callbackdoc"""
  Returns an HAL version of params provided, combined with the initial doc.

  initial_doc - the initial document with which the newly encoded info should
    merged.
  src_params - the params to encoded into HAL
  opts - options for use by modules adopting ExHal.ValueConverterWithOptions behaviour
  """
  @callback encode!(%{}) :: ExHal.Document.t
  @callback encode!(Exhal.Document.t, %{}) :: ExHal.Document.t
  @callback encode!(%{}, keyword) :: ExHal.Document.t
  @callback encode!(Exhal.Document.t, %{}, keyword) :: ExHal.Document.t


  defmacro __using__(_opts) do
    quote do
      import unquote(__MODULE__)

      Module.register_attribute __MODULE__, :extractors, accumulate: true, persist: false
      Module.register_attribute __MODULE__, :injectors,  accumulate: true, persist: false

      @before_compile unquote(__MODULE__)
    end
  end

  defmacro __before_compile__(_env) do
    quote do
      @behaviour ExHal.Transcoder

      def decode!(initial_params, %ExHal.Document{} = doc, opts) do
        @extractors
        |> Enum.reduce(initial_params, &(apply(__MODULE__, &1, [doc, &2, opts])))
      end
      def decode!(doc, [_|_] = opts), do: decode!(%{}, doc, opts)
      def decode!(initial_params, %ExHal.Document{} = doc), do: decode!(initial_params, doc, [])
      def decode!(doc), do: decode!(%{}, doc, [])

      def encode!(%ExHal.Document{} = initial_doc, params, opts) do
        @injectors
        |> Enum.reduce(initial_doc, &(apply(__MODULE__, &1, [&2, params, opts])))
      end
      def encode!(params, [_|_] = opts), do: encode!(%ExHal.Document{}, params, opts)
      def encode!(%ExHal.Document{} = initial_doc, params), do: encode!(initial_doc, params, [])
      def encode!(params), do: encode!(%ExHal.Document{}, params, [])
    end
  end

  defmodule ValueConverter do
    @type t :: module

    @callbackdoc"""
    Returns Elixir representation of HAL value.

    hal_value - The HAL representation of the value to convert.
    """
    @callback from_hal(any) :: any

    @callbackdoc"""
    Returns HAL representation of Elixir value.

    elixir_value - The Elixir representation of the value to convert.
    """
    @callback to_hal(any) :: any
  end

  defmodule ValueConverterWithOptions do
    @type t :: module

    @callbackdoc"""
    Returns Elixir representation of HAL value.

    hal_value - The HAL representation of the value to convert.
    opts - Options to be used by the converter.
    """
    @callback from_hal(any, keyword) :: any

    @callbackdoc"""
    Returns HAL representation of Elixir value.

    elixir_value - The Elixir representation of the value to convert.
    opts - Options to be used by the converter.
    """
    @callback to_hal(any, keyword) :: any
  end

  defmodule IdentityConverter do
    @behaviour ValueConverter

    def from_hal(it), do: it
    def to_hal(it), do: it
  end

  defp interpret_opts(options, name) do
    param_names = options |> Keyword.get(:param, String.to_atom(name)) |> List.wrap
    templated = options |> Keyword.get(:templated, false)
    value_converter = Keyword.get(options, :value_converter, IdentityConverter)
    extractor_name = :"extract_#{Enum.join(param_names,".")}"
    injector_name = :"inject_#{Enum.join(param_names,".")}"

    {param_names, value_converter, extractor_name, injector_name, templated}
  end

  @doc """
  Define a property extractor and injector.

   * name - the name of the property in HAL
   * options - Keywords arguments
     - :param - the key(s) in the param structure that map to this property. Default is `String.to_atom(name)`.
     - :value_converter - a `ExHal.Transcoder.ValueConverter` with which to convert the value to and from HAL
  """
  defmacro defproperty(name, options \\ []) do
    {param_names, value_converter, extractor_name, injector_name, _} =
      interpret_opts(options, name)

    quote do
      def unquote(extractor_name)(doc, params, opts) do
        ExHal.get_lazy(doc, unquote(name), fn -> nil end)
        |> decode_value(unquote(value_converter), opts)
        |> put_param(params, unquote(param_names))
      end
      @extractors unquote(extractor_name)

      def unquote(injector_name)(doc, params, opts) do
        get_in(params, unquote(param_names))
        |> encode_value(unquote(value_converter), opts)
        |> put_property(doc, unquote(name))
      end
      @injectors unquote(injector_name)
    end
  end

  @doc """
  Define a link extractor & injector.

   * rel - the rel of the link in HAL
   * options - Keywords arguments
     - :param - the key(s) in the param structure that maps to this link. Required.
     - :templated - a boolean that adds a `templated: true` parameter if true
     - :value_converter - a `ExHal.Transcoder.ValueConverter` with which to convert the link target when en/decoding HAL
  """
  defmacro deflink(rel, options \\ []) do
    {param_names, value_converter, extractor_name, injector_name, templated} =
      interpret_opts(options, rel)

    quote do
      def unquote(extractor_name)(doc, params, opts) do
        ExHal.get_links_lazy(doc, unquote(rel), fn -> [] end)
        |> Enum.map(&Map.get(&1, :href))
        |> List.first
        |> decode_value(unquote(value_converter), opts)
        |> put_param(params, unquote(param_names))
      end
      @extractors unquote(extractor_name)

      def unquote(injector_name)(doc, params, opts) do
        get_in(params, unquote(param_names))
        |> encode_value(unquote(value_converter), opts)
        |> put_link(doc, unquote(rel), unquote(templated))
      end
      @injectors unquote(injector_name)
    end
  end

  @doc """
  Define a link extractor & injector for links that may have more than one item.

   * rel - the rel of the link in HAL
   * options - Keywords arguments
     - :param - the key(s) in the param structure that maps to this link. Required.
     - :value_converter - a `ExHal.Transcoder.ValueConverter` with which to convert the link target when en/decoding HAL
  """
  defmacro deflinks(rel, options \\ []) do
    {param_names, value_converter, extractor_name, injector_name, _} =
      interpret_opts(options, rel)

    quote do
      def unquote(extractor_name)(doc, params, opts) do
        ExHal.link_targets_lazy(doc, unquote(rel), fn -> nil end)
        |> decode_value(unquote(value_converter), opts)
        |> put_param(params, unquote(param_names))
      end
      @extractors unquote(extractor_name)

      def unquote(injector_name)(doc, params, opts) do
        get_in(params, unquote(param_names))
        |> encode_value(unquote(value_converter), opts)
        |> Enum.reduce(doc, &(put_link(&1, &2, unquote(rel))))
      end
      @injectors unquote(injector_name)
    end
  end

  def decode_value(nil, _opts), do: nil
  def decode_value(raw_value, converter, opts) do
    if :erlang.function_exported(converter, :from_hal, 2) do
      converter.from_hal(raw_value, opts)
    else
      converter.from_hal(raw_value)
    end
  end

  def put_param(nil, params, _), do: params
  def put_param(value, params, param_names) do
    params = build_out_containers(params, param_names)

    put_in(params, param_names, value)
  end

  def encode_value(nil, _, _opts), do: nil
  def encode_value(raw_value, converter, opts) do
    if :erlang.function_exported(converter, :to_hal, 2) do
      converter.to_hal(raw_value, opts)
    else
      converter.to_hal(raw_value)
    end
  end

  def put_link(nil, doc, _), do: doc
  def put_link(target, doc, rel, templated \\ false) do
    ExHal.Document.put_link(doc, rel, target, templated)
  end

  def put_property(nil, doc, _), do: doc
  def put_property(value, doc, prop_name) do
    ExHal.Document.put_property(doc, prop_name, value)
  end

  defp build_out_containers(params, [_h] = _param_names), do: params
  defp build_out_containers(params, param_names) do
    (1..(Enum.count(param_names) - 1))
    |> Enum.map(&Enum.take(param_names, &1))
    |> Enum.reduce(params, fn(c, acc) -> case get_in(acc, c) do
                                           nil -> put_in(acc, c, %{})
                                           _ -> acc
                                         end
    end)
  end
end
