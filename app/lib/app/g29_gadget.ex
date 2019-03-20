defmodule App.G29Gadget do
  @moduledoc false

  use GenServer
  require Logger
  import USBGadget

  def start_link(args \\ [], opts \\ []) do
    GenServer.start_link(__MODULE__, args, opts ++ [name: __MODULE__])
  end

  # @ps3_descriptor elem(File.read("../g29ps3.desc"), 1)
  # @ps3_gp_descriptor elem(File.read("../g29ps3GP.desc"), 1)
  # @ps4_descriptor elem(File.read("../g29ps4.desc"), 1)

  def create_gadget(name \\ "g29", descriptor) do
    create_ps3_gadget(name, descriptor)
    # create_ps3_gadget(name, @ps3_descriptor
    # create_ps3_gadget(name, @ps3_gp_descriptor)
    # create_ps4_gadget(name, @ps4_descriptor)
  end

  def output(bytes) do
    GenServer.cast(__MODULE__, {:output, bytes})
  end

  ################################################################

  def init(args) do
    callback = Keyword.get(args, :callback, nil)
    path = Keyword.get(args, :path, "/dev/hidg0")
    with {:start_hidraw, {:ok, hidraw}} <- {:start_hidraw, start_hidraw(path)} do
      {:ok, %{hidraw: hidraw, callback: callback}}
    else
      {failed_step, {:error, reason}} -> {:stop, {failed_step, reason}}
    end
  end

  def handle_cast({:output, bytes},  state) do
    Hidraw.output(state.hidraw, bytes)
    {:noreply, state}
  end

  def handle_info({:hidraw, _hidraw_path, {:input_report, report}}, state) when is_binary(report) do
    Logger.debug(fn -> "#{__MODULE__} IN (#{byte_size(report)} Bytes: #{inspect(report)})" end)
    send(state.callback, {:hidout, report})
    {:noreply, state}
  end

  def handle_info({:hidraw, _hidraw_path, {:error, :closed}}, _state) do
    Logger.error(fn -> "#{__MODULE__} {:error, :closed}" end)
    {:stop, {:error, :closed}}
  end


  ################################################################

  defp create_ps3_gadget(name, descriptor) do
    if File.exists?("/dev/hidg0") do
      {:error, :exists}
    else
      device_settings = %{
        "bcdUSB" => "0x0200",
        "bDeviceClass" => "0x0",
        "bDeviceSubClass" => "0x00",
        "bDeviceProtocol" => "0x00",
        "idVendor" => "0x046d",
        "idProduct" => "0xc24f",
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
        "report_length" => "27",
        "report_desc" => descriptor,
      }

      config1_settings = %{
        "bmAttributes" => "0x80",
        "MaxPower" => "200",
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

  defp create_ps4_gadget(name, descriptor) do
    if File.exists?("/dev/hidg0") do
      {:error, :exists}
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

  defp start_hidraw(path) do
    Hidraw.start_link(path)
  end

end


