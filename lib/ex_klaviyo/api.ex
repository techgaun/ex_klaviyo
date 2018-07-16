defmodule ExKlaviyo.Api do
  @moduledoc """
  A simple API wrapper for Klaviyo
  """
  @type status_code :: pos_integer()
  @type response :: {:ok, [struct]} | {:ok, struct} | :ok | {:error, map, status_code} | {:error, map}

  defmacro __using__(type) do
    quote location: :keep do
      alias ExKlaviyo.Api

      @spec get(String.t, map) :: Api.response
      def get(path, params \\ %{}) do
        request(:get, path, params: params)
      end

      @spec post(String.t, Keyword.t) :: Api.response
      def post(path, req_body) do
        request(:post, path, req_body: {:form, req_body})
      end

      @spec request(atom, String.t, Keyword.t) :: Api.response
      def request(method, path, opts) do
        params = opts[:params] || %{}
        req_body = opts[:req_body] || %{}

        req_body = if is_map(req_body), do: Poison.encode!(req_body), else: req_body

        method
        |> 
        HTTPoison.request(
          Api.build_url(unquote(type), path, params),
          req_body,
          Api.get_request_headers(),
          []
        )
        |> Api.parse()
      end
    end
  end

  @doc """
  Parses the response from auth0 api calls
  """
  @spec parse(tuple) :: response
  def parse(response) do
    case response do
      {:ok, %HTTPoison.Response{body: body, headers: _, status_code: status}} when status in [200, 201] ->
        {:ok, Poison.decode!(body)}

      {:ok, %HTTPoison.Response{body: body}, status_code: status} when status in [400, 401, 403, 404, 429] ->
        {:error, Poison.decode!(body)}

      {:error, %HTTPoison.Error{id: _, reason: reason}} ->
        {:error, %{reason: reason}}
      _ ->
        response
    end
  end

  @spec build_url(type :: atom(), path :: String.t, params :: map()) :: String.t
  def build_url(type, path, params) do
    "#{get_base_url(type)}/#{path}?" <> build_query_string(type, params)
  end

  defp get_base_url(:public), do: base_url()
  defp get_base_url(_), do: "#{base_url()}/v1"

  defp build_query_string(:public, params) do
    data =
      params
      |> Map.put(:token, public_key())
      |> Poison.encode!()
      |> Base.url_encode64()

    %{data: data}
    |> URI.encode_query()
  end

  defp build_query_string(:private, params) do
    params
    |> Map.put(:api_key, api_key())
    |> URI.encode_query()
  end

  defp build_query_string(_, params), do: params

  def get_request_headers, do: [{"Content-Type", "application/x-www-form-urlencoded"}]

  defp api_key, do: config(:api_key)
  defp public_key, do: config(:public_key)
  defp base_url, do: config(:base_url) <> "/api"
  defp config(key), do: Application.get_env(:ex_klaviyo, key)
end
