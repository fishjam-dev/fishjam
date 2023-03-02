# Server notifications

Client SDKs communicate with Jellyfish using so called Media Events (ME), which are messages exchanged using Websockets.

A few examples when Media events are sent:
* `join` - sent when peer joins WebRTC room
* `peerDenied` - sent if peer was rejected by server when joining to server
* `tracksAdded` - sent when some tracks (video or audio) were added by a peer

Those messages have to be serialized in some way.

## Data serialization

In general we have two major options here:

### JSON

JSON has been used for a long time in [membrane_rtc_engine](https://github.com/jellyfish-dev/membrane_rtc_engine).

This solution has several drawbacks:
* there is no versioning so it’s hard to track which version of ME is used on the server side and which one on the client side
* each client SDK has to implement type definitions, serialization and deserialization on its own. Adding new media events requires a lot of the same work in each client library
* introducing changes in already existing ME is error-prone

This renders JSON on it's own unsuitable for ME.

However, there are ways to harness JSON and make it easier to manage - both when it comes to versioning and generating code.

#### GraphQL schema

The GraphQL specification defines a human-readable schema definition language (or SDL) that you use to define your schema and store it as a string.


```graphql
type Book {
  title: String
  author: Author
}

type Author {
  name: String
  books: [Book]
}
```

A schema defines a collection of types and the relationships between those types.

Using the schema code can be generated, for example using the [GraphQL Code Generator].
In Elixir, using [Absinthe](https://hexdocs.pm/absinthe/overview.html) (a GraphQL toolkit for Elixir) schema is created as an Elixir module, from which Graphql schema can be generated - not the other way around.
That means, that we would first create schema in Elixir and then generate types for each client SDK.

Importantly, GraphQL allows for deprecating fields. When greater changes are introduced it might be easier to introduce new endpoint with newer API.

Features:
- generating type specification from schema
- backward compatibility (deprecating fields)

#### Json Schema

JSON Schema is a declarative language that allows you to annotate and validate JSON documents.

```
{
  "title": "Product",
  "description": "A product from Acme's catalog",
  "type": "object",
  "properties": {
    "productId": {
      "description": "The unique identifier for a product",
      "type": "integer"
    }
  },
  "required": [ "productId" ]
}
```

Json schema allows for code generation for multiple languages, but not for Elixir.
That means, that we would have to create it by hand (and validate it using existing validators) or create our own generator.

Features:
- defining schema, used for code generation, data validation and providing documentation
- no support for Elixir code generation :c, which would gave to be created

#### AsyncAPI

AsyncAPI defines AsyncAPI document, which specifies the API and allows for generating code and documentation. 

```yaml
message:
    name: LightMeasured
    payload:
        type: object
        properties:
        id:
            type: integer
            minimum: 0
            description: Id of the streetlight.
```    

The problem with AsyncAPI is that there isn't code generation tool for Elixir, so one had to be created using the template for [code generator](https://github.com/asyncapi/generator/blob/master/docs/index.md).

Features:
- defines AsyncAPI document API specification
- no code generation for Elixir yet

### Protocol Buffers

Protocol Buffers (protobuf) are a language-neutral, platform-neutral extensible mechanism for serializing structured data.

```proto
message Person {
  optional string name = 1;
  optional int32 id = 2;
  optional string email = 3;
}
```

Protobufs are fast and allow for compact messages. 
Protobufs have built-in backward- and forward-compatibility as well as code generation features
for many languages, including Elixir.

Features:
- automatically-generated classes for multiple languages
- built-in forward- and backward-compatibity
