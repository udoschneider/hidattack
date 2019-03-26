defmodule App.AttackProxy do
  @moduledoc false

  use GenServer
  require Logger


  def start_link(args \\ %{}, opts \\ []) do
    GenServer.start_link(__MODULE__, args, opts)
  end

  ################################################################

  def init(_args) do
    with  {:start_hypervisor, {:ok, _}} <- {:start_hypervisor, start_hypervisor()},
          {:start_device, {:ok, _}} <- {:start_device, start_device()},
          {:get_descriptor, {:ok, descriptor}} <- {:get_descriptor, get_descriptor()},
          {:create_gadget, :ok} <- {:create_gadget, create_gadget(descriptor)},
          {:start_gadget, {:ok, _}} <- {:start_gadget, start_gadget()} do
      {:ok, %{}}
    else
      {failed_step, {:error, reason}} -> {:stop, {failed_step, reason}}
    end

  end

  def handle_info({:hidin, report}, state) do
    # Logger.debug(fn -> "#{__MODULE__} IN (#{byte_size(report)} Bytes: #{inspect(report)})" end)

    <<head :: binary - size(4), steering_angle :: size(16), tail :: binary>> = report
    Logger.debug(fn -> "#{__MODULE__} steering_angle #{steering_angle}" end)
    steering_angle_f = (steering_angle - 32768) / 32768
    Logger.debug(fn -> "#{__MODULE__} steering_angle_f #{steering_angle_f}" end)
    new_steering_angle_f = steering_angle_f * -1
    Logger.debug(fn -> "#{__MODULE__} new_steering_angle_f #{new_steering_angle_f}" end)
    new_steering_angle = (new_steering_angle_f * 32768 + 32768)
                         |> Kernel.round()
                         |> Kernel.min(65535)
                         |> Kernel.max(0)
    Logger.debug(fn -> "#{__MODULE__} new_steering_angle #{new_steering_angle}" end)
    report = <<head :: binary - size(4), new_steering_angle :: size(16), tail :: binary>>
    App.G29Gadget.output(report)
    {:noreply, state}
  end


  def handle_info({:hidout, report}, state) do
    # Logger.debug(fn -> "#{__MODULE__} OUT (#{byte_size(report)} Bytes: #{inspect(report)})" end)
    App.G29Device.output(report)
    {:noreply, state}
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

end
