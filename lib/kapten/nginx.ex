defmodule Kapten.Nginx do
  @moduledoc false

  @server_template Path.join([:code.priv_dir(:kapten), "nginx_http_server.eex"])

  def root() do
    config = config()

    default =
      Path.join([:code.priv_dir(:kapten), "nginx"])
      |> Path.expand()

    config[:root] || default
  end

  def ctl() do
    config()[:ctl]
  end

  def domains() do
    config()[:domains]
  end

  def child_spec(init_arg) do
    default = %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, [init_arg]}
    }

    Supervisor.child_spec(default, [])
  end

  defp config() do
    Application.fetch_env!(:kapten, __MODULE__)
  end

  def start_link(_arg) do
    domains = domains()

    prepare_domains!(domains)

    config_file = Path.join([root(), "nginx.conf"])
    cmd = [ctl(), "-g", "daemon off;", "-c", config_file]
    {:ok, pid, _os_pid} = :exec.run_link(cmd, [:stdout, :stderr])

    for {domain, _domain_config} <- domains do
      Kapten.Certbot.run!([], domain, [domain])
      interval = :timer.seconds(20)
      # interval = :timer.hours(24)
      :timer.apply_interval(interval, Kapten.Certbot, :run!, [[], domain, [domain]])
    end

    {:ok, pid}
  end

  defp prepare_domains!([]) do
    :ok
  end

  defp prepare_domains!([{domain, domain_config} | domains]) do
    certbot_config_dir = Kapten.Certbot.config_dir()
    Kapten.OpenSSL.create_self_signed_if_necessary(certbot_config_dir, domain)

    port = domain_config[:http]
    nginx_root = root()
    servers_path = Path.join([nginx_root, "servers"])
    File.mkdir_p!(servers_path)

    server_file = Path.join([servers_path, "#{domain}.conf"])

    if File.exists?(server_file) do
      :ok
    else
      server_conf =
        EEx.eval_file(@server_template,
          assigns: [certbot: certbot_config_dir, domain: "#{domain}", port: port]
        )

      :ok = File.write!(server_file, server_conf)
    end

    prepare_domains!(domains)
  end
end
