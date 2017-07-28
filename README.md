
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
iex> {:ok, doc, response_header} = ExHal.client
...> |> ExHal.Client.add_headers("User-Agent": "MyClient/1.0")
...> |> ExHal.Client.get("http://example.com/hal")
%ExHal.Document{...}
```

### Navigation

Now we have an entry point to the API. From there we can follow links to navigate around.

```elixir
iex> ExHal.follow_link(doc, "profile")
{:ok, %ExHal.Document{...}, %ExHal.ResponseHeader{...}}

iex> ExHal.follow_link(doc, "self")
{:ok, %ExHal.Document{...}, %ExHal.ResponseHeader{...}}

iex> ExHal.follow_links(doc, "profile")
[{:ok, %ExHal.Document{...}, %ExHal.ResponseHeader{...}}, {:ok, %ExHal.Document{...}, %ExHal.ResponseHeader{...}}]
```

We can specify headers for each request in addition to the headers specified in the client.

```elixir
iex> ExHal.follow_links(doc, "profile",
                        headers: ["Accept": "application/vnd.custom.json+type"])
[{:ok, %ExHal.Document{...}, %ExHal.ResponseHeader{...}}, {:ok, %ExHal.Document{...}, %ExHal.ResponseHeader{...}}]

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
{:ok, %ExHal.Document{...}, %ExHal.ResponseHeader{...}}

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
               { "href": "http://example.com/middle" }],
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
...>     {:ok, a_doc, %ResponseHeader{}} -> ExHal.url(a_doc)
...>     {:ok, a_doc} -> ExHal.url(a_doc)
...>     {:error, _}  -> :error
...>   end
...> end )
["http://example.com/beginning", "http://example.com/middle", "http://example.com/end"]
```

### Serialization

Collections and Document can render themselves to a json-like
structure that can then be serialized using your favorite json encoder
(e.g. Poison):

    ExHal.Collection.render!

or

    ExHal.Document.render!

### Transcoding

ExHal also supports interpreting HAL documents. The following is a HAL document interpreter

Given a document like

```json
{
  "name": "Jane Doe",
  "mailingAddress": "123 Main St",
  "_links": {
    "app:department": { "href": "http://example.com/dept/42" },
    "app:manager":    { "href": "http://example.com/people/84" },
    "tag": [
      {"href": "foo:1"},
      {"href": "http://2"},
      {"href": "urn:1"}
    ]
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
  deflinks    "tags"
end
```

`PersonUrlConverter` is a module that has adopted the `ExHal.ValueConverter` behavior.

```elixir
defmodule PersonUrlConverter do
  @behaviour ExHal.ValueConverter

  def from_hal(person_url) do
    to_string(person_url)
    |> String.split("/")
    |> List.last
  end

  def to_hal(person_id) do
    "http://example.com/people/#{person_id}"
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


This can be used to, for example, build Ecto changesets via a `changeset/2` functions and to render HAL responses to HTTP requests.

#### Patching

ExHal.Transcoder also supports modifying objects with [JSON patch](https://tools.ietf.org/html/rfc6902).

```elixir
defmodule PetTranscoder do
  use ExHal.Transcoder

  defproperty "name"
  defproperty "animalType",   param: species, protected: true
  deflink     "favoriteToy",  param: :favorite_toy
  deflinks    "friends"
end
```

Create an object from the transcoder, then modify it

```elixir
iex> spot = PetTranscoder.decode!(doc)
%{name: "Spot",
  species: "dog",
  favorite_toy: "http://a.co/56guxwO"
  friends: ["https://petbook.com/u/fifi", "https://petbook.com/u/fido"]}

iex> json_patches = [
  %{"op" => "replace", "path" => "/name",       "value" => "Bowser"},
  %{"op" => "replace", "path" => "/animalType", "value" => "dragon"},
  %{"op" => "replace", "path" => "/_links/favoriteToy", "value" => %{"href" => "http://a.co/9cs2VQd"}},
  %{"op" => "add",     "path" => "/_links/friends/-",   "value" => %{"href" => "https://doggo.biz/12345"}}]
...

iex> spot |> PetTranscoder.patch!(json_patches)
%{name: "Bowser",
  species: "dog",
  favorite_toy: "http://a.co/9cs2VQd",
  friends: ["https://petbook.com/u/fifi", "https://petbook.com/u/fido", "https://doggo.biz/12345"]}
```

`"replace"` operations are supported for properties and links.  `"add"` (append) is supported for link collections (`deflinks`) with `/propertyName/-` path syntax.  Any properties or links marked with `protected: true` cannot be changed via `patch!`.  Patch operations against properties or links not defined in the transcoder are ignored.

#### Composing

Transcoders are also chainable. For example, given a `ManagerTranscoder` the following would produce a Map that includes all person params and all the manager params: `PersonTranscoder.decode!(doc) |> ManagerTranscoder.decode!(doc)`. Similarly `PersonTranscoder.encode!(model) |> ManagerTranscoder.encode!(module)` would produce an `ExHal.Document` that has all the properties and links defined in those transcoders.

Similarly, `patch!` operations can be chained:

```elixir
iex> employee = PersonTranscoder.decode!(doc) |> ManagerTranscoder.decode!(doc)
...
iex> json_patches = [%{"op" => "replace", "path" => "/mailingAddress", "value" => "..."}, ...]
...
iex> employee |> PersonTranscoder.patch!(json_patches) |> ManagerTranscoder.patch!(json_patches)
```

### Assertions about HAL documents

Several assertion and helper functions are available to support testing. These functions accept a `ExHal.Document` or a string.

```elixir
iex> import ExUnit.Assertions
nil
iex> import ExHal.Assertions
nil
iex> assert_property ~s({"name": "foo"}), "name"
true
iex> assert_property ~s({"name": "foo"}), "address"
** (ExUnit.AssertionError) address is absent
iex> assert_property ~s({"name": "foo"}), "name", eq "foo"
true
iex> assert_property ~s({"name": "foo"}), "name", matches ~r/fo/
true
iex> assert_property ~s({"name": "foo"}), "name", eq "bar"
** (ExUnit.AssertionError) expected property `name` to eq("bar")
iex> assert_link_target ~s({"_links": { "profile": {"href": "http://example.com" }}}),
...>   "profile"
true
iex> assert_link_target ~s({"_links": { "profile": {"href": "http://example.com" }}}),
...>   "item"
** (ExUnit.AssertionError) link `item` is absent
iex> assert_link_target ~s({"_links": { "profile": {"href": "http://example.com" }}}),
...>   "profile", eq "http://example.com"
true
iex> assert_link_target ~s({"_links": { "profile": {"href": "http://example.com" }}}),
...>   "profile", matches ~r/example.com/
true
iex> assert_link_target ~s({"_links": { "profile": {"href": "http://example.com" }}}),
...>   "profile", eq "http://bad.com"
** (ExUnit.AssertionError) expected (at least one) `item` link to eq("http://bad.com") but found only http://example.com
iex> assert collection("{}") |> Enum.empty?
true
iex> assert 1 == collection("{}") |> Enum.count
** (ExUnit.AssertionError) Assertion with == failed
```

Installation
----

Add the following to your project `:deps` list:

```elixir
{:exhal, "~> 6.0"}
```
