defmodule Jellyfish.Component.HLS.HTTPoison do
  @moduledoc false

  @behaviour ExAws.Request.HttpClient

  @impl true
  def request(method, url, body \\ "", headers \\ [], http_opts \\ []) do
    case HTTPoison.request(method, url, body, headers, http_opts ++ [recv_timeout: 10_000]) do
      {:ok, %HTTPoison.Response{} = response} ->
        {:ok, adapt_response(response)}

      {:error, %HTTPoison.Error{reason: reason}} ->
        {:error, %{reason: reason}}
    end
  end

  defp adapt_response(response) do
    # adapt the response to fit the shape expected by ExAWS
    flat_headers =
      Enum.flat_map(response.headers, fn
        {name, vals} when is_list(vals) -> Enum.map(vals, &{name, &1})
        {name, val} -> [{name, val}]
      end)

    %{
      body: response.body,
      status_code: response.status_code,
      headers: flat_headers
    }
  end
end
