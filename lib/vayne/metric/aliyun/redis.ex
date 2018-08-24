defmodule Vayne.Metric.Aliyun.Redis do

  @behaviour Vayne.Task.Metric

  alias Vayne.Metric.Aliyun.Util

  @metric ~w(
    MemoryUsage ConnectionUsage IntranetInRatio
    IntranetOutRatio IntranetIn IntranetOut
    FailedCount CpuUsage UsedMemory
  )

  @doc """
  * `instanceId`: mongodb instanceId. Required.
  * `region`: db instance region. Required.
  * `secretId`: secretId for monitoring. Not required.
  * `secretKey`: secretKey for monitoring. Not required.
  """

  def init(params) do
    with {:ok, instanceId} <- Util.get_option(params, "instanceId"),
      {:ok, region} <- Util.get_option(params, "region"),
      {:ok, secret} <- Util.get_secret(params)
    do
      {:ok, {instanceId, region, secret}}
    else
      {:error, _} = e -> e
      error -> {:error, error}
    end
  end

  def run(stat, log_func) do

    metrics = Application.get_env(:vayne_metric_aliyun, :redis_metric, @metric)

    ret = Util.request_metric("acs_kvstore", metrics, stat, log_func, {[], []})

    {:ok, ret}
  end

  def clean(_), do: :ok

end
