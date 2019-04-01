defmodule UiWeb.PageController do
  use UiWeb, :controller

  require Logger

  def index(conn, _params) do
    render(conn, "index.html")
  end

  def attack(conn, params) do
    case Map.get(params, "level", nil) do
      "0" -> Logger.debug(fn -> "Clear Attacks" end)
             App.AttackProxy.wiggle(1, 0)
             App.AttackProxy.mirror(0, 1)
      "1" -> Logger.debug(fn -> "Ransom" end)
             App.AttackProxy.wiggle(1, 0)
             App.AttackProxy.mirror(0, 1)
      "2" -> Logger.debug(fn -> "Wiggle" end)
             App.AttackProxy.wiggle(1, 0.5)
             App.AttackProxy.mirror(0, 1)
      "3" -> Logger.debug(fn -> "Mirror" end)
             App.AttackProxy.wiggle(1, 0)
             App.AttackProxy.mirror(0, -1)
      _ -> nil
    end
    render(conn, "attack.html", layout: {UiWeb.LayoutView, "attack.html"})
  end
end
