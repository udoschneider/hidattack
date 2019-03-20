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
    callback = Keyword.get(args, :callback, nil)
    with  {:find_g29, {:ok, path}} <- {:find_g29, find_g29_path()},
          {:start_hidraw, {:ok, hidraw}} <- {:start_hidraw, start_hidraw(path)} do
      {:ok, %{hidraw: hidraw, callback: callback}}
    else
      {failed_step, {:error, reason}} -> {:stop, {failed_step, reason}}
    end
  end

  def handle_call(:descriptor, _from, state) do
    {:reply, Hidraw.descriptor(state.hidraw), state}
  end

  def handle_cast({:output, bytes},  state) do
    Hidraw.output(state.hidraw, bytes)
    {:noreply, state}
  end

  def handle_info({:hidraw, _hidraw_path, {:input_report, report}}, state) when is_binary(report) do
    Logger.debug(fn -> "#{__MODULE__} IN (#{byte_size(report)} Bytes: #{inspect(report)})" end)
    send(state.callback, {:hidin, report})
    {:noreply, state}
  end

  def handle_info({:hidraw, _hidraw_path, {:error, :closed}}, _state) do
    Logger.error(fn -> "#{__MODULE__} {:error, :closed}" end)
    {:stop, {:error, :closed}}
  end

  ################################################################

  defp find_g29_path() do
    with {path, _} <- Enum.find(Hidraw.enumerate(), nil, &match_g29/1) do
      {:ok, path}
    else
      _ -> {:error, :enotfound}
    end
  end

  defp match_g29({_, string}) do
    string =~ "Logitech"
  end

  defp start_hidraw(path) do
    Hidraw.start_link(path)
  end
end