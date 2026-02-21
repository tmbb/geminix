# Geminix

Easy to use bindings to the Gemini API.
These functions and structs follow the API very closely,
making it very easy to follow their usage from the API docs.

## Installation

The package can be installed by adding `geminix` to your list
of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:geminix, "~> 0.1.0"}
  ]
end
```

The docs can be found at <https://hexdocs.pm/geminix>.

## Implementation strategy

These bindings are mostly automatically generated from the official
API spec published by Google in JSON format.
The compile-time code genrators don't write any files to disk.
They instead compile the quoted expressions directly.
All code files are manually written, often very heavily
complemented by macros that read the JSON API spec and
generate code accordingly.

When required, manually written code is written to help with things
such as polling long-running batch jobs.

For further details, see the [contributers' guide](CONTRIBUTING.md).
