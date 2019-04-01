defmodule UiWeb.PageController do
  use UiWeb, :controller

  def index(conn, _params) do
    render(conn, "index.html")
  end

  def attack(conn, _params) do
    render(conn, "attack.html", layout: {UiWeb.LayoutView, "attack.html"})
  end
end
