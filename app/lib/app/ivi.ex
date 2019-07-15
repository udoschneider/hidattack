defmodule App.Ivi do
  @moduledoc false

  @ivi_host "192.168.50.225"
  @ivi_user "root"
  @ivi_password "root"
  @ivi_timeout 10_000

  use GenServer
  require Logger

  def start_link(args \\ %{}, opts \\ []) do
    GenServer.start_link(__MODULE__, args, opts ++ [name: __MODULE__])
  end

  def clear_attack() do
    GenServer.call(__MODULE__, {:clear}, @ivi_timeout)
  end

  def start_attack(level \\ 1) do
    GenServer.call(__MODULE__, {:attack, level}, @ivi_timeout)
  end

  def reboot() do
    GenServer.cast(__MODULE__, {:reboot})
  end


  def init(_opts) do
    {:ok, %{level: nil}}
  end

  def handle_call({:clear}, _from, %{level: 0} = state) do
    Logger.debug(fn -> "#{__MODULE__} {:clear} - Do nothing/is 0" end)
    {:reply, nil, state}
  end

  def handle_call({:clear}, _from, state) do
    Logger.debug(fn -> "#{__MODULE__} {:clear}" end)
    {:ok, conn} = _connect_to_ivi()
    SSHEx.run(conn, "killall wannadrive2_1 wannadrive2_2 wannadrive2_3")
    {:reply, nil, %{state | level: 0}}
  end

  def handle_call({:attack, level}, _from, %{level: level} = state) do
    Logger.debug(fn -> "#{__MODULE__} {:attack, #{level}} - same level - Do nothing" end)
    {:reply, nil, state}
  end

  def handle_call({:attack, new_level}, _from, %{level: old_level} = state) do
    Logger.debug(fn -> "#{__MODULE__} {:attack, #{new_level}}" end)
    {:ok, conn} = _connect_to_ivi()
    if old_level != 0 do
      Logger.debug(fn -> "#{__MODULE__} Old level was #{old_level} - clearing" end)
      SSHEx.run(conn, "killall wannadrive2_1 wannadrive2_2 wannadrive2_3")
    end
    Logger.debug(fn -> "#{__MODULE__} Start new attack level #{new_level}" end)
    SSHEx.run(conn, "QT_QPA_PLATFORM=wayland-egl /opt/wannadrive2_#{new_level}/bin/wannadrive2_#{new_level}")
    {:reply, nil, %{state | level: new_level}}
  end

  def handle_cast({:reboot}, state) do
    Logger.debug(fn -> "#{__MODULE__} {:reboot}" end)
    {:ok, conn} = _connect_to_ivi()
    SSHEx.run(conn, "reboot")
    {:noreply, state}
  end

  def handle_info({:ssh_cm, pid, msg}, state) do
    Logger.error(fn -> "#{__MODULE__} {:ssh_cm, #{inspect(pid)}, #{inspect(msg)}}," end)
    {:noreply, state}
  end

  defp _connect_to_ivi() do
    SSHEx.connect ip: @ivi_host, user: @ivi_user, password: @ivi_password
  end

end