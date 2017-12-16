defmodule WT do
  use Application

  def start(_type, _args) do
    children = [
      Manager.Supervisor
    ]
    Supervisor.start_link(children, strategy: :one_for_one)
  end

end
