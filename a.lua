local component = require("component")
local fs = require("filesystem")
local internet = require("internet")
local shell = require("shell")

if not component.isAvailable("internet") then
  io.stderr:write("This program requires an internet card to run.")
  return
end

local function get(filename)
  local f, reason = io.open(filename, "w")
  if not f then
    io.stderr:write("Failed opening file for writing: " .. reason)
    return
  end

  io.write("Downloading http://www.carr-ireland.com/mc/" .. filename .. " ")
  local url = "http://www.carr-ireland.com/mc/" .. filename
  local result, response = pcall(internet.request, url)
  if result then
    io.write("OK.\nSaving " .. filename)
    for chunk in response do
      io.write(".")
      string.gsub(chunk, "\r\n", "\n")
      f:write(chunk)
    end

    f:close()
    io.write("OK\n")
  else
    io.write("failed.\n")
    f:close()
    fs.remove(filename)
    io.stderr:write("HTTP request failed: " .. response .. "\n")
  end
end

local path = shell.getWorkingDirectory()
--print(path)

if fs.exists("/usr/lib") == false then
  fs.makeDirectory("/usr/lib")
end
fs.makeDirectory("/usr/lib/windowmanager")
fs.makeDirectory("/etc/windowmanager")

shell.setWorkingDirectory("/usr/lib/windowmanager")

get("windowmanager.tar")
get("tar.lua")
shell.execute("tar -x -f -v windowmanager.tar", _ENV)
print("Removing windowmanager.tar ")
fs.remove("/usr/lib/windowmanager/windowmanager.tar")
print("Removing tar.lua ")
fs.remove("/usr/lib/windowmanager/tar.lua")

if fs.exists("/usr/bin") == false then
  fs.makeDirectory("/usr/bin")
end
shell.setWorkingDirectory("/usr/bin")

get("windowmanager.lua")

shell.setWorkingDirectory(path)
shell.execute("windowmanager save-config")

print("Done")
print("Start windowmanager.lua and enjoy")