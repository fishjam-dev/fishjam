defmodule Jellyfish.Component.HLS.HTTPoison do
  @moduledoc false

  @behaviour ExAws.Request.HttpClient

  @impl true
  def request(method, url, body \\ "", headers \\ [], http_opts \\ []) do
    case HTTPoison.request(method, url, body, headers, http_opts) do
      {:ok, %HTTPoison.Response{status_code: status, headers: headers, body: body}} ->
        {:ok, %{status_code: status, headers: headers, body: body}}

      {:ok, %HTTPoison.Response{status_code: status, headers: headers}} ->
        {:ok, %{status_code: status, headers: headers}}

      {:error, %HTTPoison.Error{reason: reason}} ->
        {:error, reason}
    end
  end
end
