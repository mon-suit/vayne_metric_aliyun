defmodule Vayne.Metric.Aliyun.Rds do

  @behaviour Vayne.Task.Metric

  alias Vayne.Metric.Aliyun.Util

  @metric ~w(
    CpuUsage DiskUsage IOPSUsage ConnectionUsage
    DataDelay MemoryUsage
  )
  @mysql_metric     ~w(MySQL_NetworkInNew MySQL_NetworkOutNew)
  @sqlserver_metric ~w(SQLServer_NetworkInNew SQLServer_NetworkOutNew)


  @doc """
  * `instanceId`: rds instanceId. Required.
  * `region`: db instance region. Required.
  * `db_type`: "mysql" or "sqlserver". Not required. Default "mysql".
  * `secretId`: secretId for monitoring. Not required.
  * `secretKey`: secretKey for monitoring. Not required.
  """

  def init(params) do
    with {:ok, instanceId} <- Util.get_option(params, "instanceId"),
      {:ok, region} <- Util.get_option(params, "region"),
      {:ok, secret} <- Util.get_secret(params),
      db_type       <- Map.get(params, "db_type", "mysql")
    do
      {:ok, {{instanceId, region, secret}, db_type}}
    else
      {:error, _} = e -> e
      error -> {:error, error}
    end
  end

  def run({stat, db_type}, log_func) do
    default_metrics = if db_type == "mysql" do
      @metric ++ @mysql_metric
    else
      @metric ++ @sqlserver_metric
    end

    metrics = Application.get_env(:vayne_metric_aliyun, :rds_metric, default_metrics)
    metrics = Enum.filter(metrics, &(&1 in default_metrics))

    ret = Util.request_metric("acs_rds_dashboard", metrics, stat, log_func, {[], []})

    {:ok, ret}
  end

  def clean(_), do: :ok

end
