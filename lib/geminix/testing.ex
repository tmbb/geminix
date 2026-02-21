defmodule Geminix.Testing do
  alias Geminix.Config

  @cassette_mode_pdict_key :"$geminix_cassette_mode"

  @doc """
  Returns true if the user has explicitly setting the cassette mode
  to `:replay`. Will return false if the cassete is replaying but
  the mode is `:record`.

  This is meant to be used when testing functions that poll APIs.
  When hitting the real API, you will often wait a long time
  (i.e. many seconds or minutes). But when testing your code,
  if you are just replaying a cassette there is no need to wait
  that long to run the tests.
  """
  def replaying?() do
    case Process.get(@cassette_mode_pdict_key) do
      :replay -> true
      _other -> false
    end
  end

  @filter_request_headers [
    "x-goog-api-key"
  ]

  @doc """
  Run the given function with a cassette using `ReqCassette`.

  This function encapsulates some utilities to make it easier
  to test the `Geminix` functions, such as automatically adding
  the right testing plug to the process dictionary and
  automatically redacting the API key headers.

  This function disables the cache (the goal is to work on cached
  requests while actually calling the functions that process those
  requests)
  """
  def with_cassette(cassette_name, opts \\ [], fun) when is_function(fun, 0) do
    {ignore_cache, opts} = Keyword.pop(opts, :ignore_cache, true)
    all_opts = update_opts(opts)

    mode = Keyword.get(opts, :mode)
    Process.put(@cassette_mode_pdict_key, mode)

    Config.with_ignore_cache(ignore_cache, fn ->
      ReqCassette.with_cassette(
        cassette_name,
        all_opts,
        fn plug ->
          Config.with_plug(plug, fun)
        end
      )
    end)
  end

  @doc """
  Run the given function with a shared cassette using `ReqCassette`.
  A shared cassete is required if one is making requests from
  different processes.

  This function encapsulates some utilities to make it easier
  to test the `Geminix` functions, such as automatically adding
  the right testing plug to the process dictionary and
  automatically redacting the API key headers.

  This function disables the cache (the goal is to work on cached
  requests while actually calling the functions that process those
  requests)
  """
  def with_shared_cassette(cassette_name, opts \\ [], fun) when is_function(fun, 0) do
    {ignore_cache, opts} = Keyword.pop(opts, :ignore_cache, true)
    all_opts = update_opts(opts)

    Config.with_ignore_cache(ignore_cache, fn ->
      ReqCassette.with_shared_cassette(
        cassette_name,
        all_opts,
        fn plug ->
          Config.with_plug(plug, fun)
        end
      )
    end)
  end

  @doc false
  # I'm not sure we should re-export this function here...
  def with_ignore_cache(ignore_cache, fun) do
    Config.with_ignore_cache(ignore_cache, fun)
  end

  defp update_opts(opts) do
    Keyword.put_new(
      opts,
      :filter_request_headers,
      @filter_request_headers
    )
  end
end
