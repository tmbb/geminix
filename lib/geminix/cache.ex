defmodule Geminix.Cache do
  @table_name :"_cache/geminix_cache.dets"
  @max_hash 4_294_967_296

  def start_link(opts \\ []) do
    # Create the cache dir if it doesn't already exist
    File.mkdir_p!("_cache")

    Task.start_link(fn ->
      {:ok, _} =
        :dets.open_file(
          @table_name,
          [{:auto_save, 500} | opts]
        )

      Process.hibernate(Function, :identity, [nil])
    end)
  end

  def child_spec(opts) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, [opts]},
      type: :worker,
      restart: :permanent,
      shutdown: 500
    }
  end

  @doc """
  Defines a function with automatically cached arguments.

  Results from this function will be cached to disk, so the results
  will be persisted between program runs.

  ## Example

      defcached f(a, b, c) do
        ...
      end
  """
  defmacro defcached(call, do: body) do
    {f, args} = Macro.decompose_call(call)

    args_without_defaults =
      for arg <- args do
        case arg do
          {:\\, _meta, [arg_var, _arg_value]} ->
            arg_var

          other ->
            other
        end
      end

    module = __CALLER__.module

    quote do
      def unquote(call) do
        args = unquote(args_without_defaults)
        Geminix.Cache.tagged_anonymous_function_with_cache(
          not Geminix.Config.get_ignore_cache_from_pdict(),
          {unquote(module), unquote(f), args},
          fn ->
            unquote(body)
          end
        )
      end
    end
  end

  @doc """
  Execute a function (`fun`) and cache the result if successful.
  The function should return `{:ok, result}` on success and anything
  else (probably an `{:error, reason}` tuple) on failure.
  This function returns the full `{:ok, ...}` or `{:error, ...}` tuple.
  Failed results won't be cached.

  The function call must be tagged with the `{module, function, args}`,
  so that the result can be retreived from the cache.
  This function doesn't check that the function actually uses
  the provided arguments, that is the responsability of the user.

  If you want `{:error, reason}` to be treated as a success,
  wrap it in an `{:ok, {:error, reason}}` tuple in the function
  you call and extract the value later.
  """
  def tagged_anonymous_function_with_cache(from_cache?, {module, function, args}, fun) do
    # Allow the user to remove options that won't chnange the end result,
    # such as `:max_retries` and other such options

    # Invalidate the cache if the module implementation changed
    hashed_module = module.__info__(:md5)
    hashed_args = hash_args(args)
    # Key that uniquely refers to a
    key = {module, hashed_module, function, hashed_args}

    case from_cache? do
      true ->
        case fetch(key) do
          # We've found the value in the cache; return it
          {:ok, value} ->
            value

          # We haven't found the value in the cache
          :error ->
            # Actually execute the expensive function
            case fun.() do
              {:ok, _} = result ->
                # Put the result in the cache
                put(key, result)
                # Return the result returned by the function
                result

              # Don't cache failed executions
              other ->
                other
            end
        end

      false ->
        # Actually execute the expensive function;
        # Even if we're not retreiving an element form the cache,
        # we will store it in the cache for subsequent runs.
        case fun.() do
          {:ok, _} = result ->
            # Put the result in the cache
            put(key, result)
            # Return the result returned by the function
            result

          # Don't cache failed executions
          other ->
            other
        end
    end
  end

  defp fetch(key) do
    case :dets.lookup(@table_name, key) do
      [{^key, value}] -> {:ok, value}
      [] -> :error
    end
  end

  defp put(key, value) do
    :dets.insert(@table_name, {key, value})
    :dets.sync(@table_name)
  end

  defp hash_args(args) do
    :erlang.phash2(args, @max_hash)
  end
end
