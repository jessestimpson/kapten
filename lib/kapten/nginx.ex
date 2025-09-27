defmodule Kapten.Nginx do
  @moduledoc false

  @proxy_template Path.join([:code.priv_dir(:kapten), "nginx_http_proxy.eex"])
  @static_template Path.join([:code.priv_dir(:kapten), "nginx_http_static.eex"])

  def root() do
    config = config()

    default =
      Path.join([:code.priv_dir(:kapten), "nginx"])
      |> Path.expand()

    config[:root] || default
  end

  def nginx() do
    config()[:nginx]
  end

  def tls_servers() do
    config()[:tls_servers] || []
  end

  def child_spec(init_arg) do
    default = %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, [init_arg]}
    }

    Supervisor.child_spec(default, [])
  end

  def config() do
    Application.get_env(:kapten, __MODULE__)
  end

  def start_link(_arg) do
    tls_servers = tls_servers()

    prepare_tls_servers!(tls_servers)

    config_file = Path.join([root(), "nginx.conf"])
    cmd = [nginx(), "-g", "daemon off;", "-c", config_file]
    {:ok, pid, _os_pid} = :exec.run_link(cmd, [:stdout, :stderr])

    for {cert_name, _server_config} <- tls_servers do
      Kapten.Certbot.run!([], cert_name, [cert_name])
      interval = :timer.hours(24)
      :timer.apply_interval(interval, Kapten.Certbot, :run!, [[], cert_name, [cert_name]])
    end

    {:ok, pid}
  end

  defp prepare_tls_servers!([]) do
    :ok
  end

  defp prepare_tls_servers!([{cert_name, server_config} | tls_servers]) do
    certbot_config_dir = Kapten.Certbot.config_dir()
    Kapten.OpenSSL.create_self_signed_if_necessary(certbot_config_dir, cert_name)

    otp_app_priv = :code.priv_dir(Application.fetch_env!(:kapten, :otp_app))

    nginx_root = root()
    servers_path = Path.join([nginx_root, "servers"])
    File.mkdir_p!(servers_path)

    server_file = Path.join([servers_path, "#{cert_name}.conf"])

    if File.exists?(server_file) do
      :ok
    else
      server_n_conf =
        create_nginx_conf(server_config,
          otp_app_priv: otp_app_priv,
          certbot: certbot_config_dir,
          server_name: "#{cert_name}"
        )

      :ok = File.write!(server_file, server_n_conf)
    end

    prepare_tls_servers!(tls_servers)
  end

  defp create_nginx_conf(server_config, assigns) do
    case server_config[:http] do
      nil ->
        case server_config[:static] do
          nil ->
            raise "Server must either have :http or :static config var"

          static_root ->
            create_nginx_conf_static(static_root, assigns)
        end

      port ->
        create_http_conf_proxy(port, assigns)
    end
  end

  defp create_nginx_conf_static(static_root, assigns) do
    EEx.eval_file(@static_template,
      assigns: assigns ++ [static_root: static_root]
    )
  end

  defp create_http_conf_proxy(port, assigns) do
    EEx.eval_file(@proxy_template,
      assigns: assigns ++ [port: port]
    )
  end
end
