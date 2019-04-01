defmodule UiWeb.PageController do
  use UiWeb, :controller

  require Logger

  def index(conn, _params) do
    render(conn, "index.html")
  end

  def attack(conn, params) do
    case Map.get(params, "action", nil) do
      "clear" -> Logger.debug(fn -> "Clear Attacks" end)
                 App.AttackProxy.wiggle(1, 0)
                 App.AttackProxy.mirror(0, 1)
                 App.Ivi.clear_attack()
      "ransom" -> Logger.debug(fn -> "Ransom" end)
                  App.AttackProxy.wiggle(1, 0)
                  App.AttackProxy.mirror(0, 1)
                  App.Ivi.start_attack(1)
      "wiggle" -> Logger.debug(fn -> "Wiggle" end)
                  App.AttackProxy.wiggle(1, 0.5)
                  App.AttackProxy.mirror(0, 1)
                  App.Ivi.start_attack(2)
      "mirror" -> Logger.debug(fn -> "Mirror" end)
                  App.AttackProxy.wiggle(1, 0)
                  App.AttackProxy.mirror(0, -1)
                  App.Ivi.start_attack(3)
      "reboot_ivi" -> Logger.debug(fn -> "Reboot IVI" end)
                      App.Ivi.reboot()
      "reboot_hid" -> Logger.debug(fn -> "Reboot HID" end)
                      Nerves.Runtime.reboot()
      _ -> nil
    end
    render(conn, "attack.html", layout: {UiWeb.LayoutView, "attack.html"})
  end
end
