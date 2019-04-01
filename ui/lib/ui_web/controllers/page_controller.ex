defmodule UiWeb.PageController do
  use UiWeb, :controller

  require Logger

  def index(conn, _params) do
    render(conn, "index.html")
  end

  def attack(conn, params) do
    case Map.get(params, "level", nil) do
      "0" -> Logger.debug(fn -> "Clear Attacks" end)
      "1" -> Logger.debug(fn -> "Ransom" end)
      "2" -> Logger.debug(fn -> "Wiggle" end)
      "3" -> Logger.debug(fn -> "Mirror" end)
      _ -> nil
    end
    render(conn, "attack.html", layout: {UiWeb.LayoutView, "attack.html"})
  end
end
