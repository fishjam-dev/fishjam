# Versioning Strategy for APIs

## Motivation

The Jellyfish API consists of two transports: http REST API 
and WebSocket using protobuf. The two APIs can be found in
the [api-description repository](https://github.com/jellyfish-dev/protos).

In order to ensure ease of use we introduce versioning to the Jellyfish API.
The versioning of the API provides reference points when comparing
changes and allows to name compatible (and incompatible)
versions of the API.

## Workflow

Whenever it is possible, we try to introduce backward-compatible changes
in the API, allowing for a smoother transition between Jellyfish versions.

The API is versioned separately from Jellyfish, so a Jellyfish release
does not necessarily cause a change to the API.

When we decide to remove a particular functionality, we first mark
it as `deprecated` and only then remove it in a later version of Jellyfish.
This makes the older versions of the SDKs still compatible with 
newer Jellyfish until they are upgraded as well.

## Testing

In order to assure quality, all the versions declared compatible
should be tested for compatibility.
That means, that when introducing a feature, new tests should
be created, but the past functionalities should be tested 
as well.

We should also check that there are no breaking changes
between API versions, or that the breaking changes are only
related to resources previously marked deprecated.
