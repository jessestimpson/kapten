defmodule Kapten.Nginx.Limits do
  @moduledoc """
  Per-address request limits for a server's paths, from its `:limits`:

      "myapp.example.com": [
        http: 4000,
        limits: [[path: "/signup", methods: ["POST"], rate: "10r/m", burst: 5]]
      ]

  Each limit counts requests from one client address to one exact path,
  optionally only those with the given methods. `rate` is nginx's, in
  requests per second or minute ("5r/s", "10r/m"); `burst` is how many more
  may arrive at once before requests are refused, with 429. Other paths are
  not counted, so players behind one address are only held back on the
  paths named.

  The limits are rendered into one nginx file at the `http` level, which is
  rewritten on every start. A server's own file is written once and then
  edited by certbot, so they cannot live there. At the `http` level each
  limit applies to every server, but counts only requests whose host,
  method and path match it: for any other request its key is empty, which
  nginx does not count.
  """

  @doc "The nginx `http`-level configuration for the servers' limits."
  def conf(tls_servers) do
    limits =
      for {server_name, server_config} <- tls_servers,
          limit <- Keyword.get(server_config, :limits, []),
          do: {to_string(server_name), validate!(server_name, limit)}

    [
      "# Written by Kapten on start, from each server's :limits. Do not edit.\n",
      if(limits == [], do: [], else: "limit_req_status 429;\nlimit_req_log_level warn;\n"),
      limits
      |> Enum.with_index()
      |> Enum.map(fn {{server_name, limit}, index} -> limit_conf(server_name, limit, index) end)
    ]
    |> IO.iodata_to_binary()
  end

  defp limit_conf(server_name, limit, index) do
    name = "kapten_limit_#{index}"

    methods =
      case limit[:methods] do
        nil -> "[A-Z]+"
        methods -> "(" <> Enum.join(methods, "|") <> ")"
      end

    pattern = "~^#{Regex.escape(server_name)}:#{methods}:#{Regex.escape(limit[:path])}$"

    """

    # #{server_name}: #{Enum.join(limit[:methods] || ["any method"], ", ")} #{limit[:path]}
    map "$host:$request_method:$uri" $#{name} {
        default "";
        "#{pattern}" $binary_remote_addr;
    }
    limit_req_zone $#{name} zone=#{name}:1m rate=#{limit[:rate]};
    limit_req zone=#{name} burst=#{limit[:burst] || 0} nodelay;
    """
  end

  # Values go into the nginx file as they are, so each is checked for its
  # shape, and a mistake stops the start rather than nginx.
  defp validate!(server_name, limit) do
    path = limit[:path]
    rate = limit[:rate]
    burst = limit[:burst] || 0
    methods = limit[:methods] || []

    cond do
      not (is_binary(path) and path =~ ~r{^/[A-Za-z0-9/._~-]*$}) ->
        invalid!(server_name, limit, "path must be a plain path, such as \"/signup\"")

      not (is_binary(rate) and rate =~ ~r{^[1-9][0-9]*r/[sm]$}) ->
        invalid!(server_name, limit, "rate must be like \"5r/s\" or \"10r/m\"")

      not (is_integer(burst) and burst >= 0) ->
        invalid!(server_name, limit, "burst must be a non-negative integer")

      not (is_list(methods) and Enum.all?(methods, &(is_binary(&1) and &1 =~ ~r/^[A-Z]+$/))) ->
        invalid!(server_name, limit, "methods must be a list such as [\"POST\"]")

      true ->
        limit
    end
  end

  defp invalid!(server_name, limit, reason) do
    raise ArgumentError, "invalid limit for #{server_name}: #{reason}, got: #{inspect(limit)}"
  end
end
