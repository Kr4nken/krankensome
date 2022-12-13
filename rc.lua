require("utils")
require("modules/create_class")
require("modules/screen")
require("modules/tag")
require("modules/panel")
require("modules/widgets/cpu_widget")
require("modules/widgets/memory_widget")
require("modules/widgets/network_widget")
require("modules/widgets/bluetooth_widget")
require("modules/widgets/brightness_widget")
require("modules/widgets/battery_widget")
require("modules/widgets/calendar_widget")
require("modules/widgets/clock_widget")
require("modules/widgets/menu_widget")
require("modules/widgets/keyboard_layout_widget")
require("modules/widgets/volume_widget")
require("modules/widgets/microphone_widget")
require("modules/widgets/launch_widget")
require("awful.autofocus")
require("modules/error_handling")

local awful =           		require("awful")
local gears =           		require("gears")
local wibox =           		require("wibox")
local vicious =         		require("vicious")
local beautiful =                       require("beautiful")
local naughty =                         require("naughty")
local lain =                            require("lain")
local executer =                        require("modules/executer")
local screens_manager =                 require("modules/screens_manager")


-- | Variable definitions | --

local config_path =                     "/usr/share/awesome"
local alacritty_opacity =               0.7
local modkey =                          "Mod4"
local terminal =                        "alacritty"
local browser =                         "firefox"
local system_monitor_command =          "alacritty -e gtop"
local network_configuration_command =   "alacritty -e nmtui"
local calender_configuration_command =  "alacritty -e calcurse"
local bluetooth_configuration_command = "alacritty -e bluetoothctl"
local launcher =                        "rofi -show drun"
local debugging =                       false
local wallpaper_image_path =            "/usr/share/backgrounds/japan.jpg"
local geolocation = {
  latitude =                            56.916667,
  longitude =                           14.5
}
local wired_interface =                 nil
local wireless_interface =              "wlp2s0"
local numpad_key_codes = { 87, 88, 89, 83, 84, 85, 79, 80, 81 }

awful.layout.layouts = {
     					awful.layout.suit.tile.left,
     					awful.layout.suit.floating,
    					-- awful.layout.suit.tile,
    					-- awful.layout.suit.tile.bottom,
    					-- awful.layout.suit.tile.top,
    					-- awful.layout.suit.fair,
    					-- awful.layout.suit.fair.horizontal,
    					-- awful.layout.suit.spiral,
    					-- awful.layout.suit.spiral.dwindle,
    					-- awful.layout.suit.max,
     					awful.layout.suit.max.fullscreen,
    					-- awful.layout.suit.magnifier,
    					-- awful.layout.suit.corner.nw,
    					-- awful.layout.suit.corner.ne,
    					-- awful.layout.suit.corner.sw,
    					-- awful.layout.suit.corner.se,
}
-- | Widgets | --

beautiful.init(gears.filesystem.get_themes_dir() .. "relz/theme.lua")

local cpu_widget = 			CpuWidget(false, system_monitor_command)
local memory_widget = 			MemoryWidget(false, system_monitor_command)
local brightness_widget = 		BrightnessWidget(true, 100)
local battery_widget = 			BatteryWidget(true, "")
local clock_widget = 			ClockWidget(calender_configuration_command)
local network_widget = 			NetworkWidget(true, network_configuration_command)
local bluetooth_widget = 		BluetoothWidget(true, bluetooth_configuration_command)
local volume_widget = 			VolumeWidget(true)
local microphone_widget = 		MicrophoneWidget(true)
local launch_widget = 			LaunchWidget(launcher)
local todo_widget = 			require("modules/widgets/todo_widget")
local layout_widget = 			require("modules/widgets/layout_widget")

network_widget.set_wireless_interface(wireless_interface)

-- | Functions | --
local function debug_text(text)
  if not debugging then return end
  naughty.notify({ preset = naughty.config.presets.normal,
                     title = "debug message",
                     text = text 
  })
end

function add_useless_gap()
  if awful.tag.selected(1).layout.name == "fullscreen" 
  then 
    awful.tag.selected(1).gap = 0
    awful.spawn.easy_async_with_shell('sed -i "s/  opacity: '.. alacritty_opacity ..'.*/  opacity: 1.0/g" ~/.alacritty.yml', function(e) end)
  else
    awful.spawn.easy_async_with_shell('sed -i "s/  opacity: 1.0.*/  opacity: ' .. alacritty_opacity .. '/g" ~/.alacritty.yml', function(e) end)
  end
  if awful.tag.selected(1).layout.name ~= "tileleft" 
  then 
    awful.tag.selected(1).gap = 0
    return 
  end
  local count = 0
  for c in awful.client.iterate(function(cli) 
    return cli.first_tag  == awful.tag.selected(1) and not cli.floating
  end) 
  do
    count = count + 1
  end
  if count == 1
  then
    awful.tag.selected(1).gap = 30
    awful.tag.selected(1).master_width_factor = 0.50
    awful.tag.selected(1).master_fill_policy = "master_width_factor"
    return
  end
  if count == 2
  then
    awful.tag.selected(1).gap = 30
    awful.tag.selected(1).master_width_factor = 0.50
    awful.tag.selected(1).master_fill_policy = "expand"
    return
  end
  if count == 3
  then
    awful.tag.selected(1).master_width_factor = 0.50
    awful.tag.selected(1).master_fill_policy = "expand"
    awful.tag.selected(1).gap = 5
    return
  end
  awful.tag.selected(1).master_width_factor = 0.50
  awful.tag.selected(1).master_fill_policy = "expand"
  awful.tag.selected(1).gap = 0
end

function configure_clients_to_layout()
  if awful.tag.selected(1).layout.name == "floating"
  then
    for c in awful.client.iterate(function(cli) 
      return cli.first_tag  == awful.tag.selected(1) 
     end) 
    do
      awful.titlebar.show(c)
      c.height = c.height - 24
    end 
  else
    for c in awful.client.iterate(function(cli) 
      return cli.first_tag  == awful.tag.selected(1)
    end) 
    do
      awful.titlebar.hide(c) 
    end 
    add_useless_gap()
  end
end

-- Panels
local task_left_button_press_action = function(c)
  if not is_client_in_tag(c, awful.tag.selected()) then
    return
  end

  if c == client.focus then
    c.minimized = true
  else
    c:emit_signal(
      "request::activate",
      "tasklist",
      { raise = true }
    )
  end
end

local set_brightness = function(step_percent, increase)
  set_system_brightness(
    step_percent,
    increase,
    function(new_value_percent)
      brightness_widget.update(new_value_percent)
    end
  )
end

local mute = function()
  local command = "pamixer --toggle-mute"
  awful.spawn.easy_async(command, function() vicious.force({ volume_widget.icon }) end)
end

local set_volume = function(step, increase)
  set_sink_volume(step, increase, function() vicious.force({ volume_widget.icon }) end)
end

-- | Panels | --
local screen_0_panel = Panel()
screen_0_panel.position = "top"
screen_0_panel.tags.list = {
  Tag("1", awful.layout.suit.tile.left),
  Tag("2", awful.layout.suit.tile.left),
  Tag("3", awful.layout.suit.tile.left),
  Tag("4", awful.layout.suit.tile.left),
  Tag("5", awful.layout.suit.tile.left),
}
screen_0_panel.tags.key_bindings = awful.util.table.join(
  awful.button({}, 1, awful.tag.viewonly),
  awful.button({ "Mod4" }, 1, awful.client.movetotag)
)
screen_0_panel.tasks.key_bindings = awful.util.table.join(
  awful.button({}, 1, task_left_button_press_action)
)
screen_0_panel.widgets = {
  --todo_widget(),
  cpu_widget,
  memory_widget,
  network_widget,
  bluetooth_widget,
  volume_widget,
  microphone_widget,
  brightness_widget,
  battery_widget,
  clock_widget,
  menu_widget
}
screen_0_panel.launcher = launch_widget

-- | Screens | --
update_screens = function(card)
  local xrandr_output = run_command_sync("xrandr")
  local primary_output = xrandr_output:match("([a-zA-Z0-9-]+) connected primary")
  if primary_output == nil then
    primary_output = xrandr_output:match("([a-zA-Z0-9-]+) connected")
  end
  local primary_output_rect = xrandr_output:match("\n" .. primary_output:gsub("-", "[-]") .. " connected[a-z ]* ([0-9x+]+) [(]")
  local is_secondary_output_in_use = false
  local is_screen_duplicated = false

  for _,secondary_output_name in ipairs({"HDMI", "DisplayPort", "DVI", "eDP", "DP"}) do
    is_secondary_output_in_use = is_secondary_output_in_use or string.match(xrandr_output, secondary_output_name .. "[0-9-]+ connected [^(]") ~= nil
    local unused_secondary_output = xrandr_output:match("(" .. secondary_output_name .. "[0-9-]+) connected [(]")
    local used_secondary_output = xrandr_output:match("(" .. secondary_output_name .. "[0-9-]+) connected [^(]")
    local used_secondary_output_rect = xrandr_output:match(secondary_output_name .. "[0-9-]+ connected[a-z ]* ([0-9x+]+) [(]")
    local disconnected_secondary_output_rect = xrandr_output:match(secondary_output_name .. "[0-9-]+ disconnected[a-z ]* ([0-9x+]+) [(]")
    local is_secondary_output_disconnected = unused_secondary_output == nil and used_secondary_output == nil
    is_screen_duplicated =  primary_output_rect == used_secondary_output_rect
    if  is_secondary_output_in_use == nil  or is_screen_duplicated then
      local secondary_output = secondary_output_name 
      run_command_sync(
        "xrandr " ..
        "--output " .. primary_output .. " --preferred --primary " ..
        "--output " .. secondary_output .. " --left-of " .. primary_output .. " --preferred "
      )
      break
    else
      if is_secondary_output_disconnected and disconnected_secondary_output_rect then
        run_command_sync("xrandr --auto")
        break
      end
    end
  end

  if card == nil then
    local screen0 = Screen()
    screen0.wallpaper = wallpaper_image_path
    screen0.panels = { screen_0_panel }

      if is_screen_duplicated then
      end
    if is_secondary_output_in_use and not is_screen_duplicated then
      local screen1 = Screen()
      screen1.wallpaper = wallpaper_image_path
      screen1.panels = { screen_0_panel }

      screens_manager.set_screens({ screen0, screen1 })
    else
      screens_manager.set_screens({ screen0})
    end

    screens_manager.apply_screens()
  end
end

update_screens()

screen.connect_signal("added", function()
  if screen.count() > screens_manager.get_screen_count() then
    local newScreen = Screen()
    newScreen.wallpaper = wallpaper_image_path
    newScreen.panels = { screen_0_panel }

    screens_manager.add_screen(newScreen)
  end
  screens_manager.apply_screen(screens_manager.get_screen_count())
end)

-- | Key bindings | --
local global_keys = awful.util.table.join(
  awful.key(
    {modkey}, "s",
    function()
      hotkeys_popup.show_help()
    end,	
    {description="show help", group="awesome"}
  ),
  awful.key(
    {modkey}, "Left",
    function()
      awful.screen.focus_relative(-1)
    end,
    {description = "previous screen", group = "screen"}
),
  awful.key(
    {modkey}, "Right",
    function()
      awful.screen.focus_relative(1)
    end,
    {description = "next screen", group = "screen"}
  ),
  awful.key(
    {modkey}, "Escape",
    awful.tag.history.restore,
    {description = "go back", group = "tag"}
  ),
  awful.key(
    {modkey}, "j",
    function()
      awful.client.focus.byidx(1)
    end,
    {description = "focus next by index", group = "client"}
  ),
  awful.key(
    {modkey}, "k",
    function()
      awful.client.focus.byidx(-1)
    end,
    {description = "focus previous by index", group = "client"}
  ),
  awful.key(
    {modkey, "Shift"}, "j",
    function()
      awful.client.swap.byidx(1)
    end,
    {description = "swap with next client by index", group = "client"}
  ),
  awful.key(
    {modkey, "Shift"}, "k",
    function()
      awful.client.swap.byidx(-1)
    end,
    {description = "swap with previous client by index", group = "client"}
  ),
  awful.key(
    {modkey, "Control"}, "j",
    function()
      awful.screen.focus_relative(1)
    end,
    {description = "focus the next screen", group = "screen"}
  ),
  awful.key(
    {modkey, "Control"}, "k",
    function()
      awful.screen.focus_relative(-1)
    end,
    {description = "focus the previous screen", group = "screen"}
  ),
  awful.key(
    {modkey}, "u",
    awful.client.urgent.jumpto,
    {description = "jump to urgent client", group = "client"}
  ),
  awful.key(
    {modkey}, "Tab",
    function()
      awful.client.focus.history.previous()
      if client.focus then
        client.focus:raise()
      end
    end,
    {description = "go back", group = "client"}
  ),
  awful.key(
    {modkey, "Shift"}, "s",
    function()
      awful.spawn("xfce4-screenshooter")
    end,
    {description = "opens screenshooter", group = "launcher"}
  ),
  awful.key(
    {modkey}, "Return",
    function()
      awful.spawn(terminal, {screen = awful.screen.focused()})
    end,
    {description = "open a terminal", group = "launcher"}
  ),
  awful.key(
    {modkey, "Control"}, "r",
    awesome.restart,
    {description = "reload awesome", group = "awesome"}
  ),
  awful.key(
    {modkey, "Shift"}, "q",
    awesome.quit,
    {description = "quit awesome", group = "awesome"}
  ),
  awful.key(
    {modkey}, "l",
    function()
      awful.tag.incmwfact(-0.05)
    end,
    {description = "increase master width factor", group = "layout"}
  ),
  awful.key(
    {modkey}, "h",
    function()
      awful.tag.incmwfact(0.05)
    end,
    {description = "decrease master width factor", group = "layout"}
  ),
  awful.key(
    {modkey, "Shift"}, "h",
    function()
      awful.tag.incnmaster(1, nil, true)
    end,
    {description = "increase the number of master clients", group = "layout"}
  ),
  awful.key(
    {modkey, "Shift"}, "l",
    function()
      awful.tag.incnmaster(-1, nil, true)
    end,
    {description = "decrease the number of master clients", group = "layout"}
  ),
  awful.key(
    {modkey, "Control"}, "h",
    function()
      awful.tag.incncol(1, nil, true)
    end,
    {description = "increase the number of columns", group = "layout"}
  ),
  awful.key(
    {modkey, "Control"}, "l",
    function()
      awful.tag.incncol(-1, nil, true)
    end,
    {description = "decrease the number of columns", group = "layout"}
  ),
  awful.key(
    {modkey}, "space",
    function()
      awful.layout.inc( 1)
      configure_clients_to_layout()
    end,
    {description = "select next", group = "layout"}
  ),
  awful.key(
    {modkey, "Shift"}, "space",
    function()
      awful.layout.inc(-1)
      configure_clients_to_layout()
    end,
    {description = "select previous", group = "layout"}
  ),
  awful.key(
    {modkey, "Control"}, "n",
    function()
      local c = awful.client.restore()
      -- Focus restored client
      if c then
        c:emit_signal(
                "request::activate", "key.unminimize", {raise = true}
        )
      end
    end,
    {description = "restore minimized", group = "client"}
  ),
  awful.key(
    {modkey}, "p",
    function()
      awful.spawn(launcher, {screen = awful.screen.focused()})
    end,
    {description = "show the menubar", group = "launcher"}
  ),
  awful.key(
    {modkey}, "o",
    function()
      awful.spawn(browser, {screen = awful.screen.focused()})
    end,
    {description = "launch browser", group = "launcher"}
  )
)

local client_keys = awful.util.table.join(
  awful.key(
    {modkey, "Shift"}, "Left",
    function(c)
      c.move_to_screen(awful.screen[c.screen.index-1])
    end,
    {description = "move client to previous screen", group = "screen"}
  ),
  awful.key(
    {modkey, "Shift"}, "Right",
    function(c)
      c.move_to_screen()
    end,
    {description = "move client to next screen", group = "screen"}
  ),
  awful.key(
    {modkey}, "f",
    function(c)
      c.fullscreen = not c.fullscreen
      c:raise()
    end,
    {description = "toggle fullscreen", group = "client"}
  ),
  awful.key(
    {modkey, "Shift"}, "c",
       function(c)
         c:kill()
       end,
       {description = "close", group = "client"}
     ),
  awful.key(
    {modkey, "Control"}, "space",
      function(c) 
        awful.client.floating.toggle() 
        if c.floating == true
        then
          awful.titlebar.show(c)
          c.height = c.height - 24
        else
          awful.titlebar.hide(c)
        end
        add_useless_gap()
      end,
    {description = "toggle floating", group = "client"}
  ),
  awful.key(
    {modkey, "Control"}, "Return",
    function(c)
      c:swap(awful.client.getmaster())
    end,
    {description = "move to master", group = "client"}
  ),
  awful.key(
    {modkey}, "n",
    function(c)
      -- The client currently has the input focus, so it cannot be
      -- minimized, since minimized clients can't have the focus.
      c.minimized = true
    end ,
    {description = "minimize", group = "client"}
  ),
  awful.key(
    {modkey}, "m",
    function(c)
      c.maximized = not c.maximized
      c:raise()
    end,
    {description = "(un)maximize", group = "client"}),
  awful.key(
    {modkey, "Control"}, "m",
    function(c)
      c.maximized_vertical = not c.maximized_vertical
      c:raise()
    end,
    {description = "(un)maximize vertically", group = "client"}
  ),
  awful.key(
    {modkey, "Shift"}, "m",
    function(c)
      c.maximized_horizontal = not c.maximized_horizontal
      c:raise()
    end,
    {description = "(un)maximize horizontally", group = "client"})
)

for i = 1, 9 do
  client_keys = awful.util.table.join(client_keys,
    awful.key(
	{ "Mod4", "Shift"   }, "#" .. i + 9,
	function(c) 
	  do_for_tag(i, function(tag) c:move_to_tag(tag) end) 
	end, 
	{ description="Move focused client to tag #", group="Client" })
  )
end

for i = 1, 9 do
  global_keys = awful.util.table.join(global_keys,
    awful.key({ "Mod4"            }, "#" .. i + 9, function() do_for_tag(i, function(tag) tag:view_only() end) end, { description="View only tag #", group="Tag" }),
    awful.key({ "Mod4", "Control" }, "#" .. i + 9, function() do_for_tag(i, function(tag) awful.tag.viewtoggle(tag) end) end, { description="Add view tag #", group="Tag" })
  )
end

awful.menu.menu_keys = {
  up    = { "Up" },
  down  = { "Down" },
  exec  = { "Return", "Space" },
  enter = { "Right" },
  back  = { "Left" },
  close = { "Escape" }
}

root.keys(global_keys)

-- | Rules | --

local function hide_dropdowns()
  volume_widget.hide_dropdown()
  brightness_widget.hide_dropdown()
end

local client_buttons = awful.util.table.join(
  awful.button({ }, 1, hide_dropdowns),
  awful.button({ }, 2, hide_dropdowns),
  awful.button({ }, 3, hide_dropdowns),
  awful.button({ "Mod4" }, 1, move_client),
  awful.button({ "Mod4" }, 3, resize_client)
)

local hotkeys_popup = require("awful.hotkeys_popup.widget")
hotkeys_popup.add_hotkeys({
  ["Client"] = {{
    modifiers = {"Mod4"},
    keys = {
        LMB="Move focused client",
        RMB="Resize focused client"
    }
  }}
})
hotkeys_popup.add_group_rules("Client")

awful.rules.rules = {
  {
    rule = { },
    properties = {
      border_width = beautiful.border_width,
      border_color = beautiful.border_normal,
      focus = awful.client.focus.filter,
      raise = true,
      keys = client_keys,
      buttons = client_buttons,
      titlebars_enabled = false,
      placement = awful.placement.no_overlap+awful.placement.no_offscreen
    }
  }
}

-- Add a titlebar if titlebars_enabled is set to true in the rules.
client.connect_signal("request::titlebars", function(c)
  -- Default buttons for the titlebar
  local buttons = awful.util.table.join(
    awful.button({ }, 1, function() move_client(c) end),
    awful.button({ }, 3, function() resize_client(c) end)
  )

  awful.titlebar(c, {size = 24}) : setup {
    { -- Left
      wibox.container.margin(awful.titlebar.widget.closebutton(c), 0, 0, 2, 2),
      wibox.container.margin(awful.titlebar.widget.maximizedbutton(c), 0, 0, 2, 2),
      wibox.container.margin(awful.titlebar.widget.minimizebutton(c), 0, 0, 2, 2),
      layout = wibox.layout.fixed.horizontal
    },
    { -- Middle
      { -- Title
        align  = "center",
        widget = awful.titlebar.widget.titlewidget(c)
      },
      buttons = buttons,
      layout  = wibox.layout.flex.horizontal
    },
    { -- Right
      buttons = buttons,
      layout = wibox.layout.fixed.horizontal()
    },
      layout = wibox.layout.align.horizontal
  }
end)
client.connect_signal("unmanage", function(c)
  add_useless_gap()
end
)
client.connect_signal("manage", function(c, startup)
  c:connect_signal("mouse::enter", function(c)
    if awful.layout.get(c.screen) ~= awful.layout.suit.magnifier and awful.client.focus.filter(c) 
    then
      client.focus = c
    end
  end)
  if not startup and not c.size_hints.user_position and not c.size_hints.program_position 
  then
    awful.placement.no_overlap(c)
    awful.placement.no_offscreen(c)
    if awful.tag.selected(1).layout.name == "floating"
    then
      awful.titlebar.show(c)
      c.height = c.height - 24
    end
  end
  add_useless_gap()
end)

-- | RedShift Initialization | --
local redshift_config_directory = gears.filesystem.get_xdg_config_home() .. "redshift"
if not gears.filesystem.dir_readable(redshift_config_directory) 
then
  gears.filesystem.make_directories(redshift_config_directory)
end
local redshift_config_path = redshift_config_directory .. "/redshift.conf"
if not gears.filesystem.file_readable(redshift_config_path) 
then
  write_file_content(redshift_config_directory .. "/redshift.conf", "[redshift]\n")
end
get_system_brightness(function(value_percent)
  brightness_widget.update(value_percent)
end)
if geolocation.latitude == 0 and geolocation.longitude == 0 
then
  local latitude_string = read_file_content(gears.filesystem.get_configuration_dir() .. "latitude")
  local longitude_string = read_file_content(config_path .. "longitude")
  geolocation.latitude = tonumber(latitude_string) or 0
  geolocation.longitude = tonumber(longitude_string) or 0
  if geolocation.latitude == 0 and geolocation.longitude == 0 
  then
    get_geolocation(function(latitude, longitude)
      require("naughty").notify({title=longitude})
      geolocation.latitude = latitude
      geolocation.longitude = longitude
      write_file_content(config_path .. "latitude", geolocation.latitude)
      write_file_content(config_path .. "longitude", geolocation.longitude)
      brightness_widget.set_geolocation(geolocation)
    end)
  else
    brightness_widget.set_geolocation(geolocation)
  end
else
  brightness_widget.set_geolocation(geolocation)
end

-- | Autostart | --

executer.execute_commands({
  	"picom --experimental-backends --backend glx"
})
