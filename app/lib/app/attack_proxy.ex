defmodule App.AttackProxy do
  @moduledoc false

  use GenServer
  require Logger

  @tick_hz 20
  @tick_ms round(1_000 / @tick_hz)

  @frequency_change_ms 5_000
  @amplitude_change_ms 5_000


  def start_link(args \\ %{}, opts \\ []) do
    GenServer.start_link(__MODULE__, args, opts ++ [name: __MODULE__])
  end

  def wiggle(f, a) do
    GenServer.cast(__MODULE__, {:wiggle, f, a})
  end

  def mirror(f, a) do
    GenServer.cast(__MODULE__, {:mirror, f, a})
  end

  ################################################################

  def init(_args) do
    with  {:start_hypervisor, {:ok, _}} <- {:start_hypervisor, start_hypervisor()},
          {:start_device, {:ok, _}} <- {:start_device, start_device()},
          {:get_descriptor, {:ok, descriptor}} <- {:get_descriptor, get_descriptor()},
          {:create_gadget, :ok} <- {:create_gadget, create_gadget(descriptor)},
          {:start_gadget, {:ok, _}} <- {:start_gadget, start_gadget()} do
      schedule_tick()
      {
        :ok,
        %{
          t: 0,
          wiggle: {1, 0},
          wiggle_c: {0, 0},
          wiggle_t: {1, 0},
          mirror: {0, 1},
          mirror_c: {0, 0},
          mirror_t: {0, 1}
        }
      }
    else
      {failed_step, {:error, reason}} -> {:stop, {failed_step, reason}}
    end

  end

  def handle_info({:hidin, report}, %{t: t, wiggle: {wf, wa}, mirror: {mf, ma}} = state) do
    # Logger.debug(fn -> "#{__MODULE__} IN (#{byte_size(report)} Bytes: #{inspect(report)})" end)

    <<head :: binary - size(4), steering_angle :: little - size(16), tail :: binary>> = report
    # Logger.debug(fn -> "#{__MODULE__} steering_angle #{steering_angle}" end)
    steering_angle_f = (steering_angle - 32768) / 32768
    # Logger.debug(fn -> "#{__MODULE__} steering_angle_f #{steering_angle_f}" end)

    wiggle = :math.cos((t / 1000) * wf) * wa
    mirror = :math.cos((t / 1000) * mf) * ma
    new_steering_angle_f = (steering_angle_f * mirror) + wiggle

    # Logger.debug(fn -> "#{__MODULE__} new_steering_angle_f #{new_steering_angle_f}" end)
    new_steering_angle = (new_steering_angle_f * 32768 + 32768)
                         |> Kernel.round()
                         |> Kernel.min(65535)
                         |> Kernel.max(0)
    # Logger.debug(fn -> "#{__MODULE__} new_steering_angle #{new_steering_angle}" end)
    report = <<head :: binary - size(4), new_steering_angle :: little - size(16), tail :: binary>>
    App.G29Gadget.output(report)
    {:noreply, state}
  end

  def handle_info({:hidout, report}, state) do
    # Logger.debug(fn -> "#{__MODULE__} OUT (#{byte_size(report)} Bytes: #{inspect(report)})" end)
    App.G29Device.output(report)
    {:noreply, state}
  end

  def handle_info(:tick, state) do
    old_t = state.t
    new_t = rem(round(old_t + @tick_ms), 5 * 60 * 1000)
    {w, wc} = correction(state.wiggle, state.wiggle_t, state.wiggle_c)
    {m, mc} = correction(state.mirror, state.mirror_t, state.mirror_c)
    schedule_tick()
    {:noreply, %{state | t: new_t, wiggle: w, wiggle_c: wc, mirror: m, mirror_c: mc}}
  end

  def handle_cast({:wiggle, tf, ta}, %{wiggle: {f, a}} = state) do
    df = tf - f
    da = ta - a
    cf = df / (@frequency_change_ms / @tick_ms)
    ca = da / (@amplitude_change_ms / @tick_ms)
    {:noreply, %{state | wiggle_t: {tf, ta}, wiggle_c: {cf, ca}}}
  end

  def handle_cast({:mirror, tf, ta}, %{mirror: {f, a}} = state) do
    df = tf - f
    da = ta - a
    cf = df / (@frequency_change_ms / @tick_ms)
    ca = da / (@amplitude_change_ms / @tick_ms)
    {:noreply, %{state | mirror_t: {tf, ta}, mirror_c: {cf, ca}}}
  end

  ################################################################

  defp start_hypervisor() do
    DynamicSupervisor.start_link(strategy: :one_for_one, name: App.DynamicSupervisor)
  end

  defp start_device() do
    DynamicSupervisor.start_child(App.DynamicSupervisor, {App.G29Device, callback: self(), path: "/dev/hidraw0"})
  end

  defp get_descriptor() do
    App.G29Device.descriptor()
  end

  # @g29ps3fixed  File.read!("../g29ps3_fixed.desc")

  def create_gadget(descriptor) do
    case byte_size(descriptor) do
      157 ->
        Logger.debug(fn -> "Descriptor size is #{byte_size(descriptor)} Bytes - Assuming PS3 Gamepad Config" end)
        App.G29Gadget.create_gadget("g29ps3", :ps3, descriptor)
      123 ->
        Logger.debug(fn -> "Descriptor size is #{byte_size(descriptor)} Bytes - Assuming PS3 Wheel Config" end)
        # App.G29Gadget.create_gadget("g29ps3", :ps3, @g29ps3fixed)
        App.G29Gadget.create_gadget("g29ps3", :ps3, descriptor)
      160 ->
        Logger.debug(fn -> "Descriptor size is #{byte_size(descriptor)} Bytes - Assuming PS4 Wheel Config" end)
        App.G29Gadget.create_gadget("g29ps4", :ps4, descriptor)
      _ ->
        Logger.warn(fn -> "Descriptor size is #{byte_size(descriptor)} Bytes - Unknown config!" end)
        App.G29Gadget.create_gadget("g29ps3", :ps3, descriptor)
    end

  end

  defp start_gadget() do
    DynamicSupervisor.start_child(App.DynamicSupervisor, {App.G29Gadget, callback: self(), path: "/dev/hidg0"})
  end

  defp schedule_tick() do
    Process.send_after(self(), :tick, @tick_ms)
  end

  defp correction({f, a}, {tf, ta}, {cf, ca}) do
    df = tf - f
    da = ta - a
    {nf, ncf} = if abs(df) > 0.001, do: {f + cf, cf}, else: {tf, 0}
    {na, nca} = if abs(da) > 0.001, do: {a + ca, ca}, else: {ta, 0}
    {{nf, na}, {ncf, nca}}
  end

end
