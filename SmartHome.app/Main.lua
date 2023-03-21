local GUI = require("GUI")
local system = require("System")
local fs = require("Filesystem")
local paths = require("Paths")
local component = require("Component")
local event = require("Event")

-- Useful tools

local locale = system.getCurrentScriptLocalization()

local function default(value, default)
  if not value or value == "" then
    return default
  else
    return value
  end
end

--------------------------------- Configuration ---------------------------------

local config = { data = {} }
local configPath = paths.user.applicationData .. "SmartHome/config.cfg"
if (fs.exists(configPath)) then
  config.data = fs.readTable(configPath)
else
  fs.makeDirectory(paths.user.applicationData .. "SmartHome/")
end

function config.resolve(address)
  if (config.data[address] == nil) then
    config.data[address] = {
      name = nil,
      side = 1,
      strength = 1,
      invert = false
    }

    config.save()
  end
  
  return config.data[address]
end

function config.save()
  fs.writeTable(configPath, config.data)
end

-------------------------------- User interface ---------------------------------

local workspace, window, menu = system.addWindow(GUI.filledWindow(1, 1, 60, 20, 0xE1E1E1))

local mainLayout = window:addChild(GUI.layout(1, 1, window.width, window.height, 1, 1))
mainLayout:setDirection(1, 1, GUI.DIRECTION_HORIZONTAL)
local mainList = mainLayout:addChild(GUI.layout(1, 1, 0, 0, 0, 1))
mainList.columns = 0

window.actionButtons:moveToFront()

local gui = {}
local noComponents = mainLayout:addChild(GUI.text(1, 1, 0x0, locale.noComponents))

------------- Update layout -------------

local function updateLayout(resize)
  if not resize then
    table.sort(gui, function(bundle1, bundle2)
      if not (bundle1 and bundle2 and bundle1.profile.name) then
        return false
      else
        return (not bundle2.profile.name) or bundle1.profile.name < bundle2.profile.name
      end
    end)
  end

  local guiLength, editLength, unknownLength = #gui, #locale.edit, #locale.unknown
  if guiLength == 0 and not noComponents then
    noComponents = mainLayout:addChild(GUI.text(1, 1, 0x0, locale.noComponents))
  end
  if guiLength > 0 and noComponents then
    noComponents = noComponents:remove()
  end
  local columns = math.ceil(guiLength / ((window.height / 2) - 4))
  local rows = math.ceil(guiLength / columns)

  -- Adapt mainList columns
  if mainList.columns > columns then -- Remove columns
    -- for i = mainList.columns, columns, -1 do
    --   mainList.columns = i
    --   local p = (i - 1) * 3
    --   mainList:removeColumn(p + 3)
    --   mainList:removeColumn(p + 2)
    --   mainList:removeColumn(p + 1)
    -- end
  elseif mainList.columns < columns then -- Add columns
    for i = mainList.columns, columns, 1 do
      mainList.columns = i

      mainList:addColumn(GUI.SIZE_POLICY_ABSOLUTE, 0)
      mainList:setAlignment(i * 3 + 1, 1, GUI.ALIGNMENT_HORIZONTAL_RIGHT, GUI.ALIGNMENT_VERTICAL_CENTER)

      mainList:addColumn(GUI.SIZE_POLICY_ABSOLUTE, 9)

      mainList:addColumn(GUI.SIZE_POLICY_ABSOLUTE, editLength + 2)
    end
  end

  mainList:removeChildren()
  mainList.width = ((11 + editLength) * columns)
  mainList.height = rows * 2

  local function finishColumn(column, length)
    if column > 0 then
      length = length + 5
    end
    mainList:setColumnWidth(column * 3 + 1, GUI.SIZE_POLICY_ABSOLUTE, length)
    mainList.width = mainList.width + length
  end

  for i = 0, columns - 1 do
    local length = unknownLength
    for j = 1, rows do
      local bundle = gui[i * rows + j]
      if bundle == nil then
        finishColumn(i, length)
        return
      end
      if bundle.profile.name and #bundle.profile.name > length then
        length = #bundle.profile.name
      end
      mainList:setPosition(i * 3 + 1, 1, mainList:addChild(bundle.label))
      mainList:setPosition(i * 3 + 2, 1, mainList:addChild(bundle.stateSwitch))
      mainList:setPosition(i * 3 + 3, 1, mainList:addChild(bundle.editButton))
    end
    finishColumn(i, length)
  end
end

------------ Settings dialog ------------

local function openSettings(bundle)
  local profile, proxy = bundle.profile, bundle.proxy
  local container = GUI.addBackgroundContainer(workspace, true, true, bundle.address)

  -- Name
  local nameInput = container.layout:addChild(GUI.input(1, 1, 34, 3, 0xEEEEEE, 0x555555, 0x999999, 0xFFFFFF, 0x2D2D2D, profile.name, locale.name))
  nameInput.onInputFinished = function()
    bundle.label.text = default(nameInput.text, locale.unknown)
    profile.name = nameInput.text
    updateLayout()
    config.save()
  end

  -- Side
  local function updateSide(side)
    if (bundle.stateSwitch.state ~= profile.invert) then
      proxy.setOutput(profile.side, 0)
      proxy.setOutput(side, profile.strength)
    end
    profile.side = side
    config.save()
  end
  local sideBox = container.layout:addChild(GUI.comboBox(3, 2, 34, 3, 0xEEEEEE, 0x2D2D2D, 0xCCCCCC, 0x888888))
  local function addOption(label, value)
    sideBox:addItem(label).onTouch = function()
      updateSide(value)
    end
  end
  addOption(locale.bottom, 0)
  addOption(locale.top, 1)
  addOption(locale.north, 2)
  addOption(locale.south, 3)
  addOption(locale.west, 4)
  addOption(locale.east, 5)
  sideBox.selectedItem = profile.side + 1

  -- Strength
  local strengthSlider = container.layout:addChild(GUI.slider(1, 1, 30, 0x66DB80, 0x0, 0xFFFFFF, 0xAAAAAA, 1, 15, profile.strength, true, locale.strength))
  strengthSlider.roundValues = true
  strengthSlider.onValueChanged = function()
    profile.strength = strengthSlider.value
    if (bundle.stateSwitch.state ~= profile.invert) then
      proxy.setOutput(profile.side, strengthSlider.value)
    end
    config.save()
  end
  strengthSlider.height = strengthSlider.height + 1

  -- Invert
  local invertSwitch = container.layout:addChild(GUI.switchAndLabel(1, 1, #locale.invert + 7, 5, 0x66DB80, 0x0, 0xEEEEEE, 0x999999, locale.invert, profile.invert))
  invertSwitch.switch.onStateChanged = function(switch)
    if (bundle.stateSwitch.state ~= switch.state) then
      proxy.setOutput(profile.side, profile.strength)
    else
      proxy.setOutput(profile.side, 0)
    end
    profile.invert = switch.state
    config.save()
  end
end

-------------- Change list --------------

local function addAddress(address)
  local proxy = component.proxy(address)
  local profile = config.resolve(address)

  local bundle = {
    address = address,
    profile = profile,
    proxy = proxy
  }

  bundle.label = GUI.text(1, 1, 0x000000, default(profile.name, locale.unknown))

  local state = not ((proxy.getOutput(profile.side) == 0) ~= profile.invert)
  bundle.stateSwitch = GUI.switch(1, 1, 5, 0x66DB80, 0x1D1D1D, 0xBBBBBB, state)
  bundle.stateSwitch.onStateChanged = function(switch)
    if (switch.state ~= profile.invert) then
      proxy.setOutput(profile.side, profile.strength)
    else
      proxy.setOutput(profile.side, 0)
    end
  end
  
  bundle.editButton = GUI.button(1, 1, #locale.edit + 2, 1, 0xAAAAAA, 0x000000, 0x888888, 0x000000, locale.edit)
  bundle.editButton.onTouch = function()
    openSettings(bundle)
  end

  table.insert(gui, bundle)
  
end

local function removeAddress(address)
  for i, bundle in ipairs(gui) do
    if bundle.address == address then
      gui[i] = nil
      break
    end
  end
  updateLayout()
end

------------ Event listener -------------

if redstoneComponentChangeListener then
  event.removeHandler(redstoneComponentChangeListener)
end
redstoneComponentChangeListener = event.addHandler(function(event, address, type)
  if type == "redstone" then
    if event == "component_added" then
      addAddress(address)
      updateLayout()
    elseif event == "component_removed" then
      removeAddress(address)
      updateLayout()
    end
  end
end)

------------------------------- Menu integration --------------------------------

menu:removeChildren()
local appMenu = menu:addContextMenuItem("SmartHome", 0x0)
appMenu:addItem(system.getSystemLocalization().closeWindow .. " SmartHome", false, "^W").onTouch = function()
  window:remove()
end
appMenu:addSeparator()
appMenu:addItem(locale.about .. " SmartHome").onTouch = function()
  local container = GUI.addBackgroundContainer(workspace, true, true)

  local textBox = container.layout:addChild(GUI.textBox(1, 1, 40, 1, nil, 0xB4B4B4, { "SmartHome", "Copyright © 2021, filtys00", " " }, 1, 0, 0, true, true))
  table.insert(textBox.lines, { text = locale.help, color = 0xB4B4B4 })
  textBox.passScreenEvents = true
  textBox:setAlignment(GUI.ALIGNMENT_HORIZONTAL_CENTER, GUI.ALIGNMENT_VERTICAL_TOP)
end

-- Toggles menu

local togglesMenu = menu:addContextMenuItem(locale.toggles)

togglesMenu:addItem(locale.cleanup).onTouch = function()
  local keep = {}
  for address in component.list("redstone", true) do
    keep[address] = config.data[address]
  end
  config.data = keep
  config.save()
end

----------------------------- Final initialization ------------------------------

for address in component.list("redstone", true) do
  addAddress(address)
end
updateLayout()

-- Last system initialization

window.onResize = function(newWidth, newHeight)
  window.backgroundPanel.width, window.backgroundPanel.height = newWidth, newHeight
  mainLayout.width, mainLayout.height = newWidth, newHeight
  updateLayout(true)
end

workspace:draw()
