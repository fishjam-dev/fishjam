defmodule Fishjam.RPCClient do
  @moduledoc """
  This modules serves as simple RPC client to communicate with other nodes in cluster.
  It utilizes the Enhanced version of Erlang `rpc` called `erpc`.

  Enhanced version allows to  distinguish between returned value, raised exceptions, and other errors.
  `erpc` also has better performance and scalability than the original rpc implementation.
  """
  require Logger

  @doc """
  Executes mfa on a remote node.
  Function returns {:ok, result} tuple only if the execution succeeded.
  In case of any exceptions we are catching them logging and returning the {:error, :rpc_failed} tuple.
  """
  @spec call(node(), module(), atom(), term(), timeout()) :: {:ok, term()} | {:error, :rpc_failed}
  def call(node, module, function, args \\ [], timeout \\ :infinity) do
    start_time = get_time()

    try do
      result = :erpc.call(node, module, function, args, timeout)
      emit_rpc_duration_event([:fishjam, :rpc_client, :call], start_time)

      {:ok, result}
    rescue
      e ->
        Logger.warning("RPC call to node #{node} failed with exception: #{inspect(e)}")
        emit_rpc_duration_event([:fishjam, :rpc_client, :call], start_time)

        {:error, :rpc_failed}
    end
  end

  @doc """
  Multicall to all nodes in the cluster, including this node.
  It filters out any errors or exceptions from return so you may end up with empty list.
  """
  @spec multicall(module(), atom(), term(), timeout()) :: list(term)
  def multicall(module, function, args \\ [], timeout \\ :infinity) do
    start_time = get_time()

    nodes()
    |> :erpc.multicall(module, function, args, timeout)
    |> handle_result()
    |> tap(fn _ -> emit_rpc_duration_event([:fishjam, :rpc_client, :multicall], start_time) end)
  end

  defp handle_result(result) when is_list(result) do
    result
    |> Enum.reduce([], fn
      {:ok, res}, acc ->
        [res | acc]

      {status, res}, acc ->
        Logger.warning(
          "RPC multicall to one of the nodes failed with status: #{inspect(status)} because of: #{inspect(res)}"
        )

        acc
    end)
  end

  defp nodes, do: [Node.self() | Node.list()]

  defp get_time, do: System.monotonic_time()

  defp emit_rpc_duration_event(event_name, start_time) do
    duration = System.monotonic_time() - start_time
    :telemetry.execute(event_name, %{duration: duration})
  end
end
