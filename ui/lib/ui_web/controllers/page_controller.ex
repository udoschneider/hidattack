defmodule UiWeb.PageController do
  use UiWeb, :controller

  require Logger

  def index(conn, _params) do
    render(conn, "index.html")
  end

  def attack(conn, params) do
    case Map.get(params, "action", nil) do
      "clear" -> App.AttackDemo.clear()
      "ransom" -> App.AttackDemo.ransom_note()
      "wiggle" -> App.AttackDemo.wiggle()
      "mirror" -> App.AttackDemo.mirror
      "reboot_ivi" -> App.AttackDemo.reboot_ivi()
      "reboot_hid" -> App.AttackDemo.reboot_hid()
      _ -> nil
    end
    render(conn, "attack.html", layout: {UiWeb.LayoutView, "attack.html"})
  end
end
