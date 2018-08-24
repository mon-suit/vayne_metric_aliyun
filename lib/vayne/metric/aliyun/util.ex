defmodule Vayne.Metric.Aliyun.Util do

  def request_metric(project, metrics, {instanceId, region, secret}, log_func, {metric_kB, metric_mB}) do
    Enum.reduce(metrics, %{}, fn (metric, acc) ->
      resp = retry_when_sign_fail(project, metric, {instanceId, region, secret})

      case resp do
        {:ok, nil} ->
          log_func.("get empty value. instance: #{instanceId}, metric: #{metric}")
          acc
        {:error, error} ->
          log_func.("get instance: #{instanceId}, metric: #{metric} error: #{inspect error}")
          acc
        {:ok, value} ->
          value = if metric in metric_kB, do: value * 1024, else: value
          value = if metric in metric_mB, do: value * 1024 * 1024, else: value
          Map.put(acc, metric, value)
      end
    end)
  end

  #Don't know why sometimes sign fail, maybe fix in future.
  @retry 3
  def retry_when_sign_fail(project, metric, stat, retry \\ 0) do
    now = :os.system_time(:seconds)
    resp = project
      |> make_url(now, metric, stat)
      |> request_url()
    case resp do
      {:error, %HTTPotion.Response{status_code: 400}} ->
        if retry < @retry do
          retry_when_sign_fail(project, metric, stat, retry + 1)
        else
          resp
        end
      _ -> resp
    end
  end

  def get_option(params, key) do
    case Map.fetch(params, key) do
      {:ok, _} = v -> v
      _ -> {:error, "#{key} is missing"}
    end
  end

  def get_secret(params) do

    env_secretId = Application.get_env(:vayne_metric_aliyun, :secretId)
    env_secretKey = Application.get_env(:vayne_metric_aliyun, :secretKey)

    cond do
      Enum.all?(~w(secretId secretKey), &(Map.has_key?(params, &1))) ->
        {:ok, {params["secretId"], params["secretKey"]}}
      Enum.all?([env_secretId, env_secretKey], &(not is_nil(&1))) ->
        {:ok, {env_secretId, env_secretKey}}
      true ->
        {:error, "secretId or secretKey is missing"}
    end
  end

  @before -10
  def make_url(project, now, metric, {instanceId, region, {secretId, secretKey}}) do

    time      = Timex.from_unix(now)
    timestamp = time |> DateTime.to_iso8601
    nonce     = :crypto.strong_rand_bytes(32) |> Base.url_encode64 |> binary_part(0, 32)
    start     = time |> Timex.shift(minutes: @before) |> Timex.to_unix
    params = %{
      "Format"           => "JSON",
      "Version"          => "2017-03-01",
      "AccessKeyId"      => secretId,
      "SignatureMethod"  => "HMAC-SHA1",
      "Timestamp"        => timestamp,
      "SignatureVersion" => "1.0",
      "SignatureNonce"   => nonce,
      "Action"           => "QueryMetricLast",
      "Project"          => project,
      "Metric"           => metric,
      "StartTime"        => start * 1_000,
      "Dimensions"       => ~s({"instanceId":"#{instanceId}"})
    }

    query_string = URI.encode_query(params)
    string_to_sign = "GET" <> "&" <> URI.encode_www_form("/") <> "&" <> URI.encode_www_form(query_string)
    signature = :crypto.hmac(:sha, secretKey, string_to_sign) |> Base.encode64

    _url = "http://metrics.#{region}.aliyuncs.com/?" <> query_string <> "&Signature=#{signature}"
  end

  def request_url(url) do
    with {:ok, worker_pid} <- HTTPotion.spawn_worker_process(url),
      %{status_code: 200, body: body}
         <- HTTPotion.get(url, timeout: :timer.seconds(10), direct: worker_pid),
      {:ok, json} <- Poison.decode(body),
      %{"Datapoints" => points} <- json
    do
      if length(points) > 0 do
        point = List.first(points)
        {:ok, point["Maximum"]}
      else
        {:error, "no value"}
      end
    else
      {:error, _} = error -> error
      error               -> {:error, error}
    end
  end

end
