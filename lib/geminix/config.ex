defmodule Geminix.Config do
  @moduledoc """
  Config options for Geminix functions.

  Usually, these config options can be given in the following ways:
  - As keyword arguments to the functions
  - As a key in the process dictionary
  - As keys in the `:geminix` application environment

  Each way of supplying config options overrides those lower on the list
  (i.e. keyword arguments override options in the process dictionarty,
  which override options given in the application config).
  """

  @plug_pdict_key :"$geminix_plug"
  @api_key_pdict_key :"$geminix_api_key"
  @ignore_cache_pdict_key :"$geminix_ignore_cache"

  def default_receive_timeout() do
    :timer.minutes(30)
  end

  @doc false
  def put_ignore_cache_in_pdict(plug) do
    Process.put(@ignore_cache_pdict_key, plug)
  end

  @doc false
  def delete_ignore_cache_from_pdict() do
    Process.delete(@ignore_cache_pdict_key)
  end

  @doc false
  def get_ignore_cache_from_pdict() do
    Process.get(@ignore_cache_pdict_key, false)
  end

  @doc false
  def put_plug_in_pdict(plug) do
    Process.put(@plug_pdict_key, plug)
  end

  @doc false
  def delete_plug_from_pdict() do
    Process.delete(@plug_pdict_key)
  end

  @doc false
  def get_plug_from_pdict() do
    Process.get(@plug_pdict_key)
  end

  @doc """
  Run the function with the given plug stored in the process dictionary.
  """
  def with_plug(plug, fun) do
    try do
      put_plug_in_pdict(plug)
      fun.()
    after
      delete_plug_from_pdict()
    end
  end

  @doc """
  Run the function with the `ignore_cache` set to `true`` or `false`
  in the process dictionary.
  """
  def with_ignore_cache(ignore_cache, fun) do
    try do
      put_ignore_cache_in_pdict(ignore_cache)
      fun.()
    after
      delete_ignore_cache_from_pdict()
    end
  end

  @doc false
  def get_plug(opts) do
    get_from_opts_pdict_app_env(
      opts,
      :plug,
      @plug_pdict_key,
      {:geminix, :plug}
    )
  end

  @doc false
  def pop_ignore_cache(opts, default \\ false) do
    case Keyword.fetch(opts, :ignore_cache) do
      {:ok, _value} ->
        Keyword.pop(opts, :ignore_cache)

      :error ->
        case Process.get(@ignore_cache_pdict_key) do
          nil ->
            case Application.fetch_env(:geminix, :ignore_cache) do
              {:ok, value} ->
                {value, opts}

              :error ->
                {default, opts}
            end

          non_nil ->
            {non_nil, opts}
        end
    end
  end

  @doc false
  def fetch_api_key!(opts) do
    fetch_from_opts_pdict_app_env!(
      opts,
      :api_key,
      @api_key_pdict_key,
      {:geminix, :api_key}
    )
  end

  @doc false
  def fetch_from_opts_pdict_app_env(
        opts,
        opts_key,
        pdict_key,
        {app_name, app_env_key}
      ) do
    case Keyword.fetch(opts, opts_key) do
      {:ok, value} ->
        {:ok, value}

      :error ->
        case Process.get(pdict_key) do
          nil ->
            Application.fetch_env(app_name, app_env_key)

          non_nil ->
            {:ok, non_nil}
        end
    end
  end

  defp get_from_opts_pdict_app_env(
        opts,
        opts_key,
        pdict_key,
        {app_name, app_env_key}
      ) do

    fetch_result =
      fetch_from_opts_pdict_app_env(
        opts,
        opts_key,
        pdict_key,
        {app_name, app_env_key}
      )

    case fetch_result do
      {:ok, value} ->
        value

      :error ->
        nil
    end
  end

  defp fetch_from_opts_pdict_app_env!(
        opts,
        opts_key,
        pdict_key,
        {app_name, app_env_key}
      ) do

    fetch_result =
      fetch_from_opts_pdict_app_env(
        opts,
        opts_key,
        pdict_key,
        {app_name, app_env_key}
      )

    case fetch_result do
      {:ok, value} ->
        value

      :error ->
        exception = %Geminix.ConfigOptionError{
          message: "Coudn't find parameter :#{opts_key} in the `opts`," <>
            "process dictionary or application environment"
        }

        raise exception
    end
  end
end
