defmodule ExHal.Collection do
  @moduledoc """
    Utility functions for dealing with RFC 6473 collections
    """

  alias ExHal.Document

  @doc """
    Returns a stream that iterate over the collection represented by `a_doc`.
    """
  def to_stream(a_doc) do
    Stream.resource(
      fn -> {:ok, a_doc} end,
      fn follow_result ->
        case follow_result do
          {:error, _} -> {:halt, follow_result}
          {:ok, page}  -> {ExHal.follow_links(page, "item", fn _ -> [] end),
                           ExHal.follow_link(page, "next", pick_volunteer: true)}
        end
      end,
      fn _ -> nil end
    )
  end

  @doc """
  """
  def to_json_hash(enum) do
    %{ "_embedded" => %{"item" => Enum.map(enum, &(Document.to_json_hash(&1)))} }
  end
end
