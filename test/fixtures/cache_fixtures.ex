defmodule GeminixTest.CacheFixtures do
  import Geminix.Cache

  defcached bad_function(arg) do
    _ignore = arg
    {:ok, Enum.random(0..1000_000)}
  end
end
