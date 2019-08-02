defmodule App.AttackProxy do
  @moduledoc false

  use GenServer
  require Logger

  @tick_hz 20
  @tick_duration round(1_000 / @tick_hz)

  @change_duration_ms 1_000

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
    wiggle(0,0)
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
    report
    |> compromise_report(state)
    |> gadget_send()
    {:noreply, %{state | last_report: {current_time(), report}}}
  end

  def handle_info({:hidout, report}, state) do
    # Logger.debug(fn -> "#{__MODULE__} OUT (#{byte_size(report)} Bytes: #{inspect(report)})" end)
    device_send(report)
    {:noreply, state}
  end

  def handle_info(:tick, %{last_report: {last_send, report}} = state) do
    schedule_tick()
    t = current_time()
    if (t - last_send) > @tick_duration do
      report
      |> compromise_report(state)
      |> gadget_send()
      {:noreply, %{state | last_report: {t, report}}}
    else
      {:noreply, state}
    end
  end

  def handle_cast(
        {:wiggle, end_frequency, end_amplitude},
        %{wiggle: {_, _, _, start_frequency, _, start_amplitude}} = state
      ) do
    start_time = current_time()
    end_time = start_time + @change_duration_ms
    new_state = %{
      state |
      wiggle: {start_time, end_time, start_frequency, end_frequency, start_amplitude, end_amplitude}
    }
    {:noreply, new_state}
  end

  def handle_cast({:mirror, end_value}, %{mirror: {_, _, _, start_value}} = state) do
    start_time = current_time()
    end_time = start_time + @change_duration_ms
    new_state = %{
      state |
      mirror: {start_time, end_time, start_value, end_value}
    }
    {:noreply, new_state}
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

  defp start_gadget() do
    DynamicSupervisor.start_child(App.DynamicSupervisor, {@gadget, callback: self(), path: "/dev/hidg0"})
  end

  defp schedule_tick() do
    Process.send_after(self(), :tick, @tick_duration)
  end

  defp calculate_wiggle(t, state) do
    {start_time, end_time, start_frequency, end_frequency, start_amplitude, end_amplitude} = state
    if t < end_time do
      {
        Ease.ease_in_out_quad(
          t - start_time,
          start_frequency,
          end_frequency - start_frequency,
          end_time - start_time
        ),
        Ease.ease_in_out_quad(
          t - start_time,
          start_amplitude,
          end_amplitude - start_amplitude,
          end_time - start_time
        )
      }
    else
      {end_frequency, end_amplitude}
    end
  end

  defp calculate_mirror(t, state) do
    {start_time, end_time, start_value, end_value} = state
    if t < end_time do
      Ease.ease_in_out_quad(
        t - start_time,
        start_value,
        end_value - start_value,
        end_time - start_time
      )
    else
      end_value
    end
  end

  defp current_time() do
    :os.system_time(:millisecond)
  end

  defp compromise_report(nil, state) do
    t = current_time()
    {frequency, amplitude} = calculate_wiggle(t, state.wiggle)
    mirror = calculate_mirror(t, state.mirror)
    Logger.debug(fn -> "Wiggle #{frequency}Hz #{amplitude} - Mirror #{mirror}" end)
    nil
  end

  defp compromise_report(report, state) do

    t = current_time()
    {frequency, amplitude} = calculate_wiggle(t, state.wiggle)
    mirror = calculate_mirror(t, state.mirror)
    Logger.debug(fn -> "Wiggle #{frequency}Hz #{amplitude} - Mirror #{mirror}" end)

    <<head :: binary - size(4), steering_angle :: little - size(16), tail :: binary>> = report

    steering_angle_f = (steering_angle - 32768) / 32768

    wiggle = :math.cos((t / 1000) * frequency) * amplitude
    mirror = :math.cos((t / 1000) * mirror)
    new_steering_angle_f = (steering_angle_f * mirror) + wiggle

    new_steering_angle = (new_steering_angle_f * 32768 + 32768)
                         |> Kernel.round()
                         |> Kernel.min(65535)
                         |> Kernel.max(0)
    <<head :: binary - size(4), new_steering_angle :: little - size(16), tail :: binary>>
  end

  defp gadget_send(nil), do: nil

  defp gadget_send(report), do: @gadget.output(report)

  defp device_send(report), do: App.G29Device.output(report)

end
