[
  import_deps: [:phoenix, :open_api_spex, :protobuf],
  inputs:
    Enum.flat_map(
      ["{mix,.formatter}.exs", "{config,lib,test}/**/*.{ex,exs}"],
      &Path.wildcard(&1, match_dot: true)
    ) -- Path.wildcard("lib/protos/**/*.*", match_dot: true)
]
