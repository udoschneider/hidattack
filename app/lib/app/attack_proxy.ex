defmodule App.AttackProxy do
  @moduledoc false



  use GenServer
  import USBGadget

  def start_link(state, opts \\ []) do
    GenServer.start_link(__MODULE__, state, opts)
  end

  def init(_state) do
    {path, name} = Enum.find(Hidraw.enumerate(), nil, &match_g29/1)
    hidraw = Hidraw.start_link(path)
    IO.inspect(create_hidg("g29"))
    {:ok, %{hidraw: hidraw, hidraw_path: path}}
  end

  def handle_call(_msg, _from, state) do
    {:reply, :ok, state}
  end

  def handle_cast(_msg, state) do
    {:noreply, state}
  end

  def handle_info({:hidraw, hidraw_path, {:descriptor, _descriptor}}, %{hidraw_path: hidraw_path} = state) do
    {:noreply, state}
  end


  def handle_info({:hidraw, hidraw_path, {:input, input}}, %{hidraw_path: hidraw_path} = state) do
    {:noreply, state}
  end

  defp match_g29({_, "Logitech G29 Driving Force Racing Wheel"}), do: true

  defp match_g29({_, _}), do: false

  defp create_hidg(name) do
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
          "serialnumber" => " "
        }
      }
    }

    hid_settings = %{
      "protocol" => "0",
      "subclass" => "0",
      "report_length" => "64",
      "report_desc" => "",
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
         {:link_os_desc, :ok} <- {:link_os_desc, link_os_desc(name, "c.1")} do
      :ok
    else
      {failed_step, {:error, reason}} -> {:error, {failed_step, reason}}
    end


  end
end
