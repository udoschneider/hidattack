defmodule App.AttackProxy do
  @moduledoc false

  use GenServer
  require Logger
  import USBGadget

  def start_link(init_args \\ %{}, opts \\ []) do
    GenServer.start_link(__MODULE__, init_args, opts)
  end

  def init(_init_args) do
    with  {:find_g29, {hidraw_path, _}} <- {:find_g29, Enum.find(Hidraw.enumerate(), nil, &match_g29/1)},
          {:start_hidraw, {:ok, hidraw}} <- {:start_hidraw, Hidraw.start_link(hidraw_path)} do
      {:ok, %{hidraw: hidraw, hidg: nil, descriptor: nil}}
    else
      {failed_step, {:error, reason}} -> {:stop, {failed_step, reason}}
    end
  end

  def handle_info({:hidraw, _hidraw_path, {:descriptor, report}}, state) when is_binary(report) do
    Logger.debug(fn -> "#{__MODULE__} descriptor (#{byte_size(report)} Bytes: #{inspect(report)}" end)
    with  {:create_gadget, :ok} <- {:create_gadget, create_gadget("g29", report)},
          {:start_hidg, {:ok, hidg}} <- {:start_hidg, Hidg.start_link("/dev/hidg0")} do
      {:noreply, %{state | descriptor: report, hidg: hidg}}
    else
      {failed_step, {:error, reason}} -> {:stop, {failed_step, reason}}
    end
  end

  def handle_info({:hidraw, _hidraw_path, {:input, report}}, %{hidg: hidg} = state) when is_binary(report) do
    Logger.debug(fn -> "#{__MODULE__} input (#{byte_size(report)} Bytes: #{inspect(report)}" end)
    Hidg.output(hidg, report)
    {:noreply, state}
  end

  def handle_info({:hidg, _hidg_path, {:exit, exit_code}}, state) do
    {:stop, {:hidg, :exit, exit_code}}
  end

  defp match_g29({_, string}) do
    string =~ "Logitech"
  end

  # @report_desc elem(File.read("../g29ps3.desc"), 1)

  def create_gadget(name \\ "g29", descriptor) do
    if File.exists?("/dev/hidg0") do
      :ok
    else
      device_settings = %{
        "bcdUSB" => "0x0100",
        "bDeviceClass" => "0x0",
        "bDeviceSubClass" => "0x00",
        "bDeviceProtocol" => "0x00",
        "idVendor" => "0x046d",
        "idProduct" => "0xc260",
        "bcdDevice" => "0x8900",
        "strings" => %{
          "0x409" => %{
            "manufacturer" => "Logitech, Inc.",
            "product" => "Logitech G29 Driving Force Racing Wheel",
            "serialnumber" => "0"
          }
        }
      }

      hid_settings = %{
        "protocol" => "0",
        "subclass" => "0",
        "report_length" => "64",
        "report_desc" => descriptor,
      }

      config1_settings = %{
        "bmAttributes" => "0xC0",
        "MaxPower" => "500",
        "strings" => %{
          "0x409" => %{
            "configuration" => "Logitech G29 Driving Force Racing Wheel Config"
          }
        }
      }

      function_list = ["hid.usb0"]

      with {:create_device, :ok} <- {:create_device, create_device(name, device_settings)},
           {:create_hid, :ok} <- {:create_hid, create_function(name, "hid.usb0", hid_settings)},
           {:create_config, :ok} <- {:create_config, create_config(name, "c.1", config1_settings)},
           {:link_functions, :ok} <- {:link_functions, link_functions(name, "c.1", function_list)},
           {:link_os_desc, :ok} <- {:link_os_desc, link_os_desc(name, "c.1")},
           {:enable_device, :ok} <- {:enable_device, enable_device(name)}do
        :ok
      else
        {failed_step, {:error, reason}} -> {:error, {failed_step, reason}}
      end
    end
  end

end
