local savedLayouts = {}
local layoutFile = os.getenv("HOME") .. "/.hammerspoon/layouts.json"

local function getDisplaySignature()
  local screens = hs.screen.allScreens()
  local sig = {}
  for _, s in ipairs(screens) do
    table.insert(sig, s:name() .. ":" .. s:id())
  end
  table.sort(sig)
  return table.concat(sig, "|")
end

local function persistLayouts()
  local data = hs.json.encode(savedLayouts)
  local f = io.open(layoutFile, "w")
  if f then
    f:write(data)
    f:close()
  end
end

local function loadLayouts()
  local f = io.open(layoutFile, "r")
  if f then
    local data = f:read("*a")
    f:close()
    local decoded = hs.json.decode(data)
    if decoded then
      savedLayouts = decoded
    end
  end
end

local function saveLayout()
  local sig = getDisplaySignature()
  local layout = {}
  for _, win in ipairs(hs.window.allWindows()) do
    if win:isStandard() and win:title() ~= "" then
      local app = win:application()
      local f = win:frame()
      layout[#layout + 1] = {
        appName = app and app:name() or "unknown",
        windowTitle = win:title(),
        frame = { x = f.x, y = f.y, w = f.w, h = f.h },
        screenName = win:screen():name(),
      }
    end
  end
  savedLayouts[sig] = layout
  persistLayouts()
end

local function restoreLayout()
  hs.timer.doAfter(3, function()
    local sig = getDisplaySignature()
    local layout = savedLayouts[sig]
    if not layout then return end

    for _, entry in ipairs(layout) do
      local targetScreen = nil
      for _, s in ipairs(hs.screen.allScreens()) do
        if s:name() == entry.screenName then
          targetScreen = s
          break
        end
      end

      if targetScreen then
        local app = hs.application.get(entry.appName)
        if app then
          for _, win in ipairs(app:allWindows()) do
            if win:title() == entry.windowTitle then
              win:setFrame(hs.geometry.rect(entry.frame.x, entry.frame.y, entry.frame.w, entry.frame.h))
              break
            end
          end
        end
      end
    end
  end)
end

loadLayouts()

screenWatcher = hs.screen.watcher.new(function()
  restoreLayout()
end)
screenWatcher:start()

saveTimer = hs.timer.new(30, saveLayout, true):start()
saveLayout()

hs.hotkey.bind({ "cmd", "alt", "ctrl" }, "S", function()
  saveLayout()
  hs.alert.show("Layout saved")
end)

hs.hotkey.bind({ "cmd", "alt", "ctrl" }, "R", function()
  restoreLayout()
  hs.alert.show("Layout restored")
end)
