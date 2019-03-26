defmodule App.G29Device do
  @moduledoc false

  use GenServer
  require Logger

  def start_link(args \\ [], opts \\ []) do
    GenServer.start_link(__MODULE__, args, opts ++ [name: __MODULE__])
  end

  def descriptor() do
    GenServer.call(__MODULE__, :descriptor)
  end

  def output(bytes) do
    GenServer.cast(__MODULE__, {:output, bytes})
  end

  ################################################################

  def init(args) do
    Logger.debug(fn -> "#{__MODULE__}.init = #{inspect(self())}" end)
    Process.flag :trap_exit, true
    callback = Keyword.get(args, :callback, nil)
    path = Keyword.get(args, :path, "/dev/hidraw0")
    with {:start_hidraw, {:ok, hidraw}} <- {:start_hidraw, start_hidraw(path)} do
      {:ok, %{hidraw: hidraw, callback: callback, path: path}}
    else
      {failed_step, {:error, reason}} -> {:stop, {failed_step, reason}}
    end
  end

  def handle_call(:descriptor, _from, state) do
    {:reply, Hidraw.descriptor(state.hidraw), state}
  end

  def handle_cast({:output, bytes}, state) do
    Hidraw.output(state.hidraw, <<0, bytes::binary>>)
    {:noreply, state}
  end

  def handle_info({:hidraw, _hidraw_path, {:input_report, report}}, state) when is_binary(report) do
    send(state.callback, {:hidin, report})
    {:noreply, state}
  end

  def handle_info(:reconnect, %{path: path} = state)   do
    Logger.error(fn -> "#{__MODULE__} :reconnect" end)
    with {:ok, hidraw} <- start_hidraw(path) do
      Logger.debug(fn -> "#{__MODULE__} Reconnect succeded" end)
      {:noreply, %{state | hidraw: hidraw}}
    else
      _ ->
        send_reconnect()
        {:noreply, state}
    end
  end

  def handle_info({:hidraw, _hidraw_path, {:error, :closed}}, state) do
    Logger.error(fn -> "#{__MODULE__} {:error, :closed}" end)
    send_reconnect()
    {:noreply, %{state | hidraw: nil}}
  end

  def handle_info({:EXIT, from, reason}, state) do
    Logger.error(fn -> "#{__MODULE__} :EXIT #{inspect(from)} #{inspect(reason)}" end)
    {:noreply, state}
  end

  ################################################################

  defp start_hidraw(path) do
    Logger.debug(fn -> "#{__MODULE__}.start_hidraw(#{path})" end)
    Hidraw.start_link(path)
  end

  defp send_reconnect() do
    Process.send_after(self(), :reconnect, 1000)
  end

end