
ExHal
=====

[![Build Status](https://travis-ci.org/pezra/exhal.svg?branch=master)](https://travis-ci.org/pezra/exhal)
[![Hex.pm](https://img.shields.io/hexpm/v/exhal.svg)](https://hex.pm/packages/exhal)

An easy to use [HAL](http://stateless.co/hal_specification.html) API client for elixir.

Usage
----

Consider a resource `http://example.com/hal` whose HAL representation looks like

```json
{ "name": "Hello!",
  "_links": {
     "self"   : { "href": "http://example.com" },
      "profile": [{ "href": "http://example.com/special" },
                  { "href": "http://example.com/normal" }]
  }
}
```

```elixir
iex> doc = ExHal.client
...> |> ExHal.Client.add_headers("User-Agent": "MyClient/1.0")
...> |> ExHal.Client.get("http://example.com/hal")
%ExHal.Document{...}
```

### Navigation

Now we have an entry point to the API. From there we can follow links to navigate around.

```exlixir
iex> ExHal.follow_link(doc, "profile")
{:ok, %ExHal.Document{...}}

iex> ExHal.follow_link("self")
{:ok, %ExHal.Document{...}}

iex> ExHal.follow_links(doc, "profile")
[{:ok, %ExHal.Document{...}}, {:ok, %ExHal.Document{...}}]
```

We can specify headers for each request in addition to the headers specified in the client.

```elixir
iex> ExHal.follow_links(doc, "profile",
                        headers: ["Accept": "application/vnd.custom.json+type"])
[{:ok, %ExHal.Document{...}}, {:ok, %ExHal.Document{...}}]

```

If we try to follow a non-existent or compound link with `ExHal.follow_link` it will return an error tuple.

```elixir
iex> ExHal.follow_link(doc, "nonexistent")
{:error, %ExHal.Error{reason: "no such link"}}

iex> ExHal.follow_link(doc, "profile", strict: true)
{:error, %ExHal.Error{reason: "multiple choices"}}
```

If we try to follow a non-existent with `ExHal.follow_links` it will return a list of error tuples.

```elixir
iex> ExHal.follow_links(doc, "nonexistent")
[{:error, %ExHal.Error{reason: "no such link"}}]
```

### Actions

If you want to take an action (ie, make a PUT, POST, etc) request you can do that too.

```elixir
name_change = """
  { "name": "Bye!",
    "_links": {
       "self"   : { "href": "http://example.com" },
       "profile": [{ "href": "http://example.com/special" },
       { "href": "http://example.com/normal" }]
    }
  }
  """

# make a request that returns a HAL response
iex> ExHal.put(doc, "self", name_change)
{:ok, %ExHal.Document{...}}

# make a request that just returns a response without a body
iex> {:ok, resp} = ExHal.post(doc, "add-child", "{\"name\": \"child\"}")
{:ok, %ExHal.NonHalResponse{status_code: 201, headers: [{"Location", "http://example.com/child"}, ...], body: ""}}
iex> ExHal.url(resp)
"http://example.com/child"

```


### Collections

Consider a resource `http://example.com/hal-collection` whose HAL representation looks like

```json
{ "_links": {
     "self"   : { "href": "http://example.com/hal-collection" },
      "item": [{ "href": "http://example.com/beginning" },
               { "href": "http://example.com/middle" }]
      "next": { "href": "http://example.com/hal-collection?p=2" }
  }
}
```
and a resource `http://example.com/hal-collection?p=2` whose HAL representation looks like

```json
{ "_links": {
     "self"   : { "href": "http://example.com/hal-collection?p=2" },
      "item": [{ "href": "http://example.com/end" }]
  }
}
```

If we get the first HAL collection resource and turn it into a stream we can use all our favorite Stream functions on it.

```elixir
iex> collection = ExHal.client
...> |> ExHal.Client.add_headers("User-Agent": "MyClient/1.0")
...> |> ExHal.Client.get("http://example.com/hal-collection")
...> |> ExHal.to_stream
#Function<11.52512309/2 in Stream.resource/3>

iex> Stream.map(collection, fn follow_results ->
...>   case follow_results do
...>     {:ok, a_doc} -> ExHal.url(a_doc)}
...>     {:error, _}  -> :error
...>   end
...> end )
["http://example.com/beginning", "http://example.com/middle", "http://example.com/end"]
```

### Serialization

Collections and Document can render themselves to a json-like
structure that can then be serialized using your favorite json encoder
(e.g. Poison):

    ExHal.Collection.to_json_hash([ex_hal_doc]) |> Poison.encode!

or

    ExHal.Document.to_json_hash(ex_hal_doc) |> Poison.encode!


Installation
----

Add the following to your project `:deps` list:

```elixir
{:exhal, "~>2.0"}
```
