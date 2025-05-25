defmodule Kapten.Application do
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    nginx =
      case Kapten.Nginx.config() do
        {:ok, _} ->
          [Kapten.Nginx]

        _ ->
          []
      end

    children = nginx

    opts = [strategy: :one_for_one, name: Kapten.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
