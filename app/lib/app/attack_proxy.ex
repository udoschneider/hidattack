defmodule App.AttackProxy do
  @moduledoc false

  use GenServer
  require Logger
  alias App.SensorData
  alias App.G29Device
  import Ease


  @tick_hz 20
  @tick_duration 1 / @tick_hz # in s
  @change_duration 1 # in s

  @args Application.get_env(:app, __MODULE__)
  @gadget Keyword.fetch!(@args, :gadget) # @App.G29Gadget

  def start_link(args \\ %{}, opts \\ []) do
    GenServer.start_link(__MODULE__, args, opts ++ [name: __MODULE__])
  end

  def wiggle(f, a) do
    GenServer.cast(__MODULE__, {:wiggle, f, a})
  end

  def mirror(v) do
    GenServer.cast(__MODULE__, {:mirror, v})
  end

  def clear() do
    wiggle(0, 0)
    mirror(1)
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
          wiggle: {0, 0, 0, 0, 0, 0},
          mirror: {0, 0, 1, 1},
          last_report: {0, nil},
        }
      }
    else
      {failed_step, {:error, reason}} -> {:stop, {failed_step, reason}}
    end

  end

  def handle_info({:hidin, report}, state) do
    send_compromised_report(report, state)
    {:noreply, %{state | last_report: {current_time(), report}}}
  end

  def handle_info(:tick, %{last_report: {last_send, report}} = state) do
    schedule_tick()
    t = current_time()
    if (t - last_send) > @tick_duration do
      send_compromised_report(report, state)
      {:noreply, %{state | last_report: {t, report}}}
    else
      {:noreply, state}
    end
  end

  def handle_info({:hidout, report}, state) do
    # Logger.debug(fn -> "#{__MODULE__} OUT (#{byte_size(report)} Bytes: #{inspect(report)})" end)
    device_send(report)
    {:noreply, state}
  end

  def handle_cast({:wiggle, fe, ae}, %{wiggle: {_, _, _, fs, _, as}} = state) do
    t = current_time()
    {:noreply, %{state | wiggle: {t, t + @change_duration, fs, fe, as, ae}}}
  end

  def handle_cast({:mirror, ve}, %{mirror: {_, _, _, vs}} = state) do
    t = current_time()
    {:noreply, %{state | mirror: {t, t + @change_duration, vs, ve}}}
  end

  ################################################################

  defp start_hypervisor() do
    DynamicSupervisor.start_link(strategy: :one_for_one, name: App.DynamicSupervisor)
  end

  defp start_device() do
    DynamicSupervisor.start_child(App.DynamicSupervisor, {G29Device, callback: self(), path: "/dev/hidraw0"})
  end

  defp start_gadget() do
    DynamicSupervisor.start_child(App.DynamicSupervisor, {@gadget, callback: self(), path: "/dev/hidg0"})
  end

  defp get_descriptor() do
    G29Device.descriptor()
  end

  def create_gadget(descriptor) do
    case byte_size(descriptor) do
      157 ->
        Logger.debug(fn -> "Descriptor size is #{byte_size(descriptor)} Bytes - Assuming PS3 Gamepad Config" end)
        @gadget.create_gadget("g29ps3", :ps3, descriptor)
      123 ->
        Logger.debug(fn -> "Descriptor size is #{byte_size(descriptor)} Bytes - Assuming PS3 Wheel Config" end)
        # @gadget.create_gadget("g29ps3", :ps3, @g29ps3fixed)
        @gadget.create_gadget("g29ps3", :ps3, descriptor)
      160 ->
        Logger.debug(fn -> "Descriptor size is #{byte_size(descriptor)} Bytes - Assuming PS4 Wheel Config" end)
        @gadget.create_gadget("g29ps4", :ps4, descriptor)
      _ ->
        Logger.warn(fn -> "Descriptor size is #{byte_size(descriptor)} Bytes - Unknown config!" end)
        @gadget.create_gadget("g29ps3", :ps3, descriptor)
    end

  end

  ################################################################

  defp send_compromised_report(report, state) do
    report
    |> compromise_report(state)
    |> gadget_send()
  end

  defp compromise_report(nil, _state) do
    nil
  end

  # TODO: Limit to matching report size!
  defp compromise_report(<<head :: binary - size(4), d :: little - size(16), tail :: binary>> = _report, state) do
    t = current_time()
    wiggle = calculate_wiggle(t, state.wiggle)
    mirror = calculate_mirror(t, state.mirror)

    dn = d
         |> uint16_to_float()
         |> compromise_steering(mirror, wiggle)
         |> float_to_uint16()

    <<head :: binary - size(4), dn :: little - size(16), tail :: binary>>
  end

  defp compromise_steering(t, m, w), do: (t * m) + w

  defp calculate_wiggle(t, {ts, te, fs, fe, as, ae} = _state) do
    if t < te do
      td = t - ts
      f = ease_in_out_quad(td, fs, fe - fs, te - ts)
      a = ease_in_out_quad(td, as, ae - as, te - ts)
      :math.cos(t * f) * a
    else
      :math.cos(t * fe) * ae
    end
  end

  defp calculate_mirror(t, {ts, te, vs, ve} = _state) do
    if t < te, do: ease_in_out_quad(t - ts, vs, ve - vs, te - ts), else: ve
  end

  defp gadget_send(nil), do: nil

  defp gadget_send(report), do: @gadget.output(report)

  defp device_send(report), do: G29Device.output(report)

  ################################################################

  defp schedule_tick() do
    Process.send_after(self(), :tick, round(@tick_duration * 1000))
  end

  defp current_time() do
    :os.system_time(:millisecond) / 1000
  end

  defp uint16_to_float(uint16) do
    (uint16 - 32768) / 32768
  end

  defp float_to_uint16(float) do
    (float * 32768 + 32768)
    |> Kernel.round()
    |> Kernel.min(65535)
    |> Kernel.max(0)
  end

end
