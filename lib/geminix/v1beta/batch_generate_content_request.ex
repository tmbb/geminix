defmodule Geminix.V1beta.BatchGenerateContentRequest do
  use Geminix.Meta.Schema, json: "vendor/v1beta_api.json"

  @url_prefix "https://generativelanguage.googleapis.com/"
  @api_version "v1beta"

  require Logger

  alias Geminix.Utils
  alias Geminix.Config
  alias Geminix.V1beta.File, as: GeminixFile
  alias Geminix.V1beta.InlinedRequest

  @doc """
  Start a new batch request.
  Raises in case of error.
  """
  @spec start!(binary(), list(InlinedRequest.t()), keyword()) :: t()
  def start!(model, inlined_requests, opts \\ []) do
    {:ok, batch} = start(model, inlined_requests, opts)
    batch
  end

  @doc """
  Start a new batch request.
  """
  @spec start(binary(), list(InlinedRequest.t()), keyword()) :: {:ok, t()} | {:error, any()}
  def start(model, inlined_requests, opts \\ []) do
    api_key = Config.fetch_api_key!(opts)
    plug = Config.get_plug(opts)

    display_name = Keyword.fetch!(opts, :display_name)

    full_url = @url_prefix
      <> "#{@api_version}/models/#{model}:batchGenerateContent"

    {:ok, %Geminix.V1beta.File{} = geminix_file} =
      Utils.with_tmp_path("-requests.jsonl", fn path ->
        jsonl_data =
          inlined_requests
          |> Enum.map(&Jason.encode!/1)
          |> Enum.intersperse("\n")

        File.write!(path, jsonl_data)
        GeminixFile.upload(path, opts)
      end)

    batch_generate_content_request =
      %Geminix.V1beta.BatchGenerateContentRequest{
        batch: %Geminix.V1beta.GenerateContentBatch{
          display_name: display_name,
          input_config: %Geminix.V1beta.InputConfig{
            file_name: geminix_file.name
          }
        }
      }

    start_batch_request =
      Req.new(
        method: :post,
        url: full_url,
        headers: [
          {"x-goog-api-key", api_key},
          {"content-type", "application/json"}
        ],
        body: Jason.encode_to_iodata!(batch_generate_content_request)
      )

    start_batch_response = Req.post!(start_batch_request, plug: plug)

    handle_errors(start_batch_response, fn ->
      metadata = start_batch_response.body["metadata"]
      Geminix.V1beta.GenerateContentBatch.from_map(metadata)
    end)
  end

  @doc """
  Update the state of a batch request by polling the API.
  Doesn't download the output of the request even if the batch has succeeded.
  """
  def update_state(batch, opts \\ []) do
    api_key = Config.fetch_api_key!(opts)
    plug = Config.get_plug(opts)

    full_url =
      Path.join([
        @url_prefix,
        @api_version,
        batch.name
      ])

    request_get_status =
      Req.new(
        method: :get,
        url: full_url,
        headers: [
          {"x-goog-api-key", api_key},
          {"content-type", "application/json"}
        ]
      )

    response = Req.get!(request_get_status, plug: plug)

    handle_errors(response, fn ->
      metadata = response.body["metadata"]
      Geminix.V1beta.GenerateContentBatch.from_map(batch, metadata)
    end)
  end

  @doc """
  Wait for the completion of a batch of requests, polling it periodically.
  Raises if there is an error.
  """
  @spec await!(t(), keyword()) :: t()
  def await!(batch, opts \\ []) do
    {:ok, batch} = await(batch, opts)
    batch
  end

  @doc """
  Wait for the completion of a batch of requests, polling it periodically.
  """
  @spec await(t(), keyword()) :: {:ok, t()} | {:error, t()}
  def await(batch, opts \\ []) do
    poll_interval = Keyword.get(opts, :poll_interval, 30 * 60_000)
    await_helper(batch, poll_interval, opts)
  end

  defp await_helper(batch, poll_interval, opts) do
    {:ok, updated_batch} = update_state(batch, opts)
    on_update = Keyword.get(opts, :on_update, &on_update_batch/1)

    case updated_batch.state do
      "BATCH_STATE_SUCCEEDED" ->
        on_update.(updated_batch)
        {:ok, updated_batch}

      waiting when waiting in ["BATCH_STATE_PENDING", "BATCH_STATE_RUNNING"] ->
        on_update.(updated_batch)
        :timer.sleep(poll_interval)
        await_helper(updated_batch, poll_interval, opts)

      _other ->
        {:error, updated_batch}
    end
  end

  defp on_update_batch(batch) do
    {completed, total} = completed_and_total(batch.batch_stats)
    ProgressBar.render(completed, total, suffix: :count)
  end

  defp completed_and_total(batch_stats) do
    completed = (batch_stats.successful_request_count || 0) + (batch_stats.failed_request_count || 0)
    total = batch_stats.request_count
    {completed, total}
  end

  @doc """
  Get the output of a batch and load it into memory.
  Raises in the case of error.
  """
  def get_output!(batch, opts \\ []) do
    {:ok, output} = get_output(batch, opts)
    output
  end

  @doc """
  Get the output of a batch and load it into memory.
  """
  def get_output(batch = %{output: output}, opts \\ [])
        when not is_nil(output) and
             not is_nil(output.responses_file) do
    {:ok, jsonl} = download_file_into_memory(batch.output.responses_file, opts)
    # Find out a better way of doing this with `{:ok, _}` tuples
    decoded = Utils.decode_jsonl!(jsonl)

    inlined_responses =
      %Geminix.V1beta.InlinedResponses{
        inlined_responses:
          Enum.map(decoded, fn map ->
            {:ok, response} = Geminix.V1beta.InlinedResponse.from_map(map)
            response
          end)
      }

    {:ok, inlined_responses}
  end

  defp download_file_into_memory(filename, opts) do
    api_key = Config.fetch_api_key!(opts)
    plug = Config.get_plug(opts)

    full_url =
      Path.join([
        @url_prefix,
        "download",
        @api_version,
        "#{filename}:download?alt=media"
      ])

    request =
      Req.new(
        method: :get,
        url: full_url,
        headers: [
          {"x-goog-api-key", api_key}
        ]
      )

    response = Req.get!(request, plug: plug)

    handle_errors(response, fn ->
      {:ok, response.body}
    end)
  end

  defp handle_errors(response, fun) do
    case response.status do
      200 ->
        case fun.() do
          {:ok, _} = result ->
            result

          {:error, error} ->
            {:error, {:invalid_data, error}}
        end

      _other ->
        {:error, {:bad_request, response}}
    end
  end
end
