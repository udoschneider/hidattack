defmodule App.AttackProxy do
  @moduledoc false

  use GenServer
  require Logger


  def start_link(args \\ %{}, opts \\ []) do
    GenServer.start_link(__MODULE__, args, opts)
  end

  ################################################################

  def init(_args) do
    # List all child processes to be supervised
    # App.G29Gadget.create_gadget()
    # {App.G29Gadget, %{callback: self(), path: "/dev/hidg0"}},
    #  {App.G29Device, callback: self()},

    with  {:start_hypervisor, {:ok, _}} <- {:start_hypervisor, start_hypervisor()},
          {:start_device, {:ok, _}} <- {:start_device, start_device()},
          {:get_descriptor, {:ok, descriptor}} <- {:get_descriptor, get_descriptor()},
          {:create_gadget, :ok} <- {:create_gadget, App.G29Gadget.create_gadget(descriptor)},
          {:start_gadget, {:ok, _}} <- {:start_gadget, start_gadget()} do
      Logger.debug(fn -> "Descriptor size is #{byte_size(descriptor)} Bytes" end)
      {:ok, %{}}
    else
      {failed_step, {:error, reason}} -> {:stop, {failed_step, reason}}
    end

  end

  def handle_info({:hidin, report}, state) do
    Logger.debug(fn -> "#{__MODULE__} IN (#{byte_size(report)} Bytes: #{inspect(report)})" end)
    App.G29Gadget.output(report)
    {:noreply, state}
  end


  def handle_info({:hidout, report}, state) do
    Logger.debug(fn -> "#{__MODULE__} OUT (#{byte_size(report)} Bytes: #{inspect(report)})" end)
    App.G29Device.output(report)
    {:noreply, state}
  end

  ################################################################

  defp start_hypervisor() do
    DynamicSupervisor.start_link(strategy: :one_for_one, name: App.DynamicSupervisor)
  end

  defp start_device() do
    DynamicSupervisor.start_child(App.DynamicSupervisor, {App.G29Device, callback: self()})
  end

  defp get_descriptor() do
    App.G29Device.descriptor()
  end

  defp start_gadget() do
    DynamicSupervisor.start_child(App.DynamicSupervisor, {App.G29Gadget, callback: self(), path: "/dev/hidg0"})
  end

end
