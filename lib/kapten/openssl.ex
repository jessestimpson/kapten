defmodule Kapten.OpenSSL do
  def openssl() do
    config()[:openssl] || "/usr/bin/openssl"
  end

  defp config() do
    Application.get_env(:kapten, __MODULE__, [])
  end

  def create_self_signed_if_necessary(certbot_config_root, domain) do
    certbot_path = Path.join([certbot_config_root, "self", "#{domain}"])
    keyout = Path.join([certbot_path, "privkey.pem"])
    out = Path.join([certbot_path, "fullchain.pem"])

    if File.exists?(keyout) do
      false
    else
      File.mkdir_p!(certbot_path)

      cmd = [
        openssl(),
        "req",
        "-nodes",
        "-new",
        "-x509",
        "-subj",
        "/CN=#{domain}",
        "-keyout",
        keyout,
        "-out",
        out
      ]

      System.cmd(hd(cmd), tl(cmd), stderr_to_stdout: true)

      certbot_path
    end
  end
end
