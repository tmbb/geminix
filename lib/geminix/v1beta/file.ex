defmodule Geminix.V1beta.File do
  use Geminix.Meta.Schema, json: "vendor/v1beta_api.json"

  alias Geminix.Utils
  alias Geminix.Config

  @url_prefix "https://generativelanguage.googleapis.com/"
  @api_version "v1beta"

  @doc """
  Upload a file from a local path.
  """
  @spec upload(Path.t(), keyword()) ::
          {:ok, t()} |
          {:error, {:invalid_data, Ecto.Changeset.t()}} |
          {:error, {:bad_response, Req.Response.t()}}

  def upload(local_path, opts \\ []) do
    api_key = Config.fetch_api_key!(opts)
    plug = Config.get_plug(opts)

    full_url = Path.join(@url_prefix, "upload/#{@api_version}/files")
    extension = Path.extname(local_path)
    num_bytes = File.stat!(local_path).size

    mime_type = Keyword.get(opts, :mime_type, mime_type(local_path))
    display_name = Keyword.get(opts, :display_name, Utils.random_id() <> extension)

    request_prepare_upload =
      Req.new(
        method: :post,
        url: full_url,
        headers: [
          {"x-goog-api-key", api_key},
          {"x-goog-upload-protocol", "resumable"},
          {"x-goog-upload-command", "start"},
          {"x-goog-upload-header-content-length", num_bytes},
          {"x-goog-upload-header-content-type", mime_type},
          {"content-type", "application/jsonl"}
        ],
        body: Jason.encode_to_iodata!(%{
          file: %{
            display_name: display_name
          }
        })
      )

    response_prepare_upload =
      Req.post!(
        request_prepare_upload,
        plug: plug,
        receive_timeout: Config.default_receive_timeout()
      )

    [google_upload_url] = Req.Response.get_header(response_prepare_upload, "x-goog-upload-url")

    request_upload =
      Req.new(
        method: :post,
        url: google_upload_url,
        headers: [
          {"content-length", num_bytes},
          {"x-goog-api-key", api_key},
          {"x-goog-upload-offset", "0"},
          {"x-goog-upload-command", "upload, finalize"}
        ],
        body: File.read!(local_path)
      )

    response_upload = Req.post!(
      request_upload,
      plug: plug,
      receive_timeout: Config.default_receive_timeout()
    )

    case response_upload.status do
      200 ->
        params = response_upload.body["file"]
        case Geminix.V1beta.File.from_map(params) do
          {:ok, _} = result ->
            result

          {:error, changeset} ->
            {:error, {:invalid_data, changeset}}
        end

      code when code >= 400 ->
        {:error, {:bad_response, response_upload}}
    end
  end


  @doc """
  Extract the MIME type from the file path by inspecting
  the file extension or the file contents.
  """
  @spec mime_type(Path.t()) :: binary()
  def mime_type(local_path) do
    case Path.extname(local_path) do
      ".jsonl" -> "application/jsonl"
      ".json" -> "application/json"
      _other -> "application/text"
    end
  end
end
