defmodule ExHal.Collection do
  @moduledoc """
    Utility functions for dealing with RFC 6473 collections
    """

  alias ExHal.Document
  alias ExHal.Error

  @doc """
    Returns a stream that iterate over the collection represented by `a_doc`.
    """
  def to_stream(a_doc) do
    first_page_getter = fn -> a_doc end

    Stream.resource(
      fn -> {:ok, a_doc} end,
      fn follow_result ->
        case follow_result do
          {:error, _} -> {:halt, follow_result}
          {:ok, page}  -> {ExHal.follow_links(page, "item"),
                           ExHal.follow_link(page, "next", pick_volunteer: true)}
        end
      end,
      fn _ -> end
    )
  end
end
