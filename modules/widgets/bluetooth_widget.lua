local awful = require("awful")
local wibox = require("wibox")
local gears = require("gears")
local beautiful = require("beautiful")

BluetoothWidget_prototype = function()
  local this = {}

  this.__public_static = {
    -- Public Static Variables
    -- Public Static Funcs
  }

  this.__private_static = {
    -- Private Static Variables
    config_path = gears.filesystem.get_configuration_dir()
    -- Private Static Funcs
  }

  this.__public = {
    -- Public Variables
    name = "BluetoothWidget",
    icon = wibox.widget.imagebox(),
    value = wibox.container.background(),
    -- Public Funcs
    on_container_created = function(container, panel_position)
      if this.__private.on_click_command ~= nil then
        container:buttons(
          awful.util.table.join(
            awful.button({}, 1, function() awful.spawn(this.__private.on_click_command) end)
          )
        )
      end
    end
  }

  this.__private = {
    -- Private Variables
    bluetooth_status = false,
    bluetooth_device = nil,
    on_click_command = nil,
    -- Private Funcs
    update = function()
      get_bluetooth_device(function(bluetooth_device)
        this.__private.bluetooth_device = bluetooth_device

        local icon_file_name = "bluetooth"
        if not this.__private.bluetooth_status then
          icon_file_name = icon_file_name .. "_off"
        elseif bluetooth_device.connected then
          icon_file_name = icon_file_name .. "_connected"
        end
        this.__public.icon.image = gears.color.recolor_image(this.__private_static.config_path .. "/themes/relz/icons/widgets/bluetooth/" .. icon_file_name .. ".svg", beautiful.text_color)

        if this.__private.show_text and bluetooth_device ~= nil then
          this.__public.value.text = ""
          if bluetooth_device.alias ~= nil then
            this.__public.value.text = bluetooth_device.alias
          end
          if bluetooth_device.battery_percentage ~= nil then
            if this.__public.value.text ~= "" then
              this.__public.value.text = this.__public.value.text .. " "
            end
            this.__public.value.text = this.__public.value.text .. string.rep(" ", 3 - get_percent_number_digits_count(bluetooth_device.battery_percentage)) .. bluetooth_device.battery_percentage .. "%"
          end
          if this.__public.value.text ~= "" then
            this.__public.value.text = " " .. this.__public.value.text .. " "
          end
        end
      end)
    end
  }

  this.__construct = function(show_text, on_click_command)
    -- Constructor
    this.__private.show_text = show_text
    this.__private.on_click_command = on_click_command
    if this.__private.show_text then
      this.__public.value = wibox.widget.textbox()
      this.__public.value.font = beautiful.font_family_mono .. "Bold 9"
    end

    subscribe_bluetooth_status(function(bluetooth_status)
      this.__private.bluetooth_status = bluetooth_status
      this.__private.update()
    end)

    dbus.add_match("system", "interface='org.freedesktop.DBus.Properties'")
    dbus.connect_signal("org.freedesktop.DBus.Properties", function(data, interface, chprop)
      if interface == "org.bluez.Device1" then
        if chprop.Connected ~= nil then
          local mac_address = data.path:match("dev_(.+)"):gsub("_", ":")
          if chprop.Connected or mac_address == this.__private.bluetooth_device.mac_address then
            this.__private.update()
          end
        end
      elseif interface == "org.bluez.MediaControl1"and data.member == "PropertiesChanged" then
        this.__private.update()
      end
    end)
  end

  return this
end

BluetoothWidget = createClass(BluetoothWidget_prototype)
