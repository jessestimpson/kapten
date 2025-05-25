defmodule Kapten.Application do
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [Kapten.Nginx]

    opts = [strategy: :one_for_one, name: Kapten.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
