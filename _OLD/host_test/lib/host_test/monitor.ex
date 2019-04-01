defmodule HostTest.Monitor do
  @moduledoc false



  use GenServer
  require Logger

  def start_link(state \\ %{}, opts \\ []) do
    GenServer.start_link(__MODULE__, state, opts)
  end

  def init(_opts) do
    {path, _name} = Enum.find(Hidraw.enumerate(), nil, &match_g29/1)
    {:ok, hidraw} = Hidraw.start_link(path)
    {:ok, %{hidraw: hidraw}}
  end

  def handle_call(_msg, _from, state) do
    {:reply, :ok, state}
  end

  def handle_cast(_msg, state) do
    {:noreply, state}
  end

  def handle_info({:hidraw, _path, report}, state) when is_binary(report) do
    Logger.debug(fn -> "#{__MODULE__} IN (#{byte_size(report)} Bytes: #{inspect(report)})" end)
    {:noreply, state}
  end

  def handle_info({:hidraw, _path, {:report_descriptor, report}}, state) do
    Logger.debug(fn -> "Descriptor report #{inspect(report)}" end)
    {:noreply, state}
  end

  defp match_g29({_, string}) do
    string =~ "Logitech"
  end

end