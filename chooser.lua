require("hs.screen")
require("hs.geometry")
require("hs.timer")
require("hs.osascript")
require("hs.layout")
require("hs.application")
require("hs.image")
require("hs.chooser")
require("hs.window")
local utils = require("knedel.utils")
local logger = require("knedel.logger")

local Chooser = {}
Chooser.__index = Chooser

function Chooser:new()
    local o = {}
    setmetatable(o, Chooser)
    -- Actions that can be performed on window.
    o.actions = {
        -- Close window.
        c = function(win)
            win:close()
            -- Update choices because one window was just closed.
            me:buildChoices():resetChoices()
        end,
        f = function(win)
            win:raise():focus()
        end,
        -- Maximize window.
        -- Use hs.layout, gives better results then window:maximize
        max = function(win)
            local screen = win:screen()
            local frame = screen:frame()
            hs.layout.apply({
                { nil, win, screen, nil, hs.geometry.rect(0, 0, frame.w, frame.h), nil }
            })
            win:raise()
        end,
        -- Minimize window.
        min = function(win)
            win:minimize()
        end,
        l = function(win)
            win:moveOneScreenWest()
            local screen = win:screen()
            local frame = screen:frame()
            hs.layout.apply({
                { nil, win, screen, nil, hs.geometry.rect(0, 0, frame.w, frame.h), nil }
            })
            win:raise()
        end,
        r = function(win)
            win:moveOneScreenEast()
            local screen = win:screen()
            local frame = screen:frame()
            hs.layout.apply({
                { nil, win, screen, nil, hs.geometry.rect(0, 0, frame.w, frame.h), nil }
            })
            win:raise()
        end,
        -- Resize to 50% and move to left.
        ["1"] = function(win)
            local screen = win:screen()
            local frame = screen:frame()
            hs.layout.apply({
                { nil, win, win:screen(), nil, hs.geometry.rect(0, 0, frame.w/2, frame.h), nil }
            })
            win:raise()
        end,
        -- Resize to 50% and move to right.
        ["2"] = function(win)
            local screen = win:screen()
            local frame = screen:frame()
            hs.layout.apply({
                { nil, win, win:screen(), nil, hs.geometry.rect(frame.w/2, 0, frame.w/2, frame.h), nil }
            })
            win:raise()
        end,
    }
    -- Window that was focused just before chooser where shown.
    o.focusedWindow = nil
    -- Chooser choices.
    o.choices = {}
    -- Actions typed by user to be execute on window.
    o.currentActions = {}
    -- hs.chooser instance.
    o.chooser = hs.chooser.new(function(choice)
        if choice == nil then
            return
        end

        local actions = o.currentActions
        if #actions == 0 then
            choice.win:raise():focus()
        else
            o:runActions(choice.win, actions)
        end

        action = nil
    end)
                  :width(600)
                  :queryChangedCallback(function(query)
        o:onInput(query)
    end)

    o:buildChoices():resetChoices()

    -- Refresh choices every 10 seconds.
    hs        .timer.new(10, function()
        o:buildChoices()
    end, true):start()

    return o
end

function Chooser:buildChoices()
    -- Use AppleScript because window.filter/application.allWindows are
    -- randomly slow and lags the whole spoon. I'm sure its because of my
    -- lack of knowledge related to Hammerspoon but don't want to spend
    -- on this too much time.
    local success, pids = hs.osascript._osascript([[tell application "System Events"
    set listOfProcesses to (unix id of every process where background only is false)
    return listOfProcesses
end tell]], "AppleScript")
    if success == false then
        return
    end
    self.choices = {}
    for _, pid in pairs(pids) do
        local app = hs.application.applicationForPID(pid)
        if app then
            for _, win in pairs(app:allWindows()) do
                self.choices[#self.choices + 1] = {
                    text = win:title(),
                    subText = app:name(),
                    image = hs.image.imageFromAppBundle(app:bundleID()),
                    win = win,
                    id = win:id(),
                    appName = utils.split(string.lower(app:name()), " "),
                    winTitle = string.lower(win:title())
                }
            end
        end
    end
    return self
end

function Chooser:onInput(str)
    str = str or ""
    local query, actions = self:parseQuery(str)

    self.currentActions = actions
    local focusedWindow = self.focusedWindow
    local chooser = self.chooser

    local items = {}

    local actionsOnly = str:sub(1, 1) == "/"

    if query == nil and actionsOnly then
        for _, choice in pairs(self.choices) do
            if focusedWindow:id() == choice.win:id() then
                items[#items + 1] = choice
                break
            end
        end

        chooser:choices(items)
        chooser:refreshChoicesCallback(true)
    end

    if #actions > 0 and actions[#actions] == "." then
        self:runActions(
                utils.ternary(query == nil, focusedWindow, chooser:selectedRowContents().win),
                actions
        )
        chooser:query(nil)
        chooser:choices(self.choices)
        chooser:refreshChoicesCallback(true)
        return
    end

    if not actionsOnly then
        if query == nil then
            items = self.choices
        else
            local found = {}
            self:matchAppName(query, items, found)
                :matchAppNameLike(query, items, found)
                :matchWinTitle(query, items, found)
                :matchWinTitleLike(query, items, found)
        end
        chooser:choices(items)
        chooser:refreshChoicesCallback(true)
    end
end

function Chooser:matchAppName(str, items, found)
    for _, choice in pairs(self.choices) do
        if found[choice.id] == nil then
            for _, part in pairs(choice.appName) do
                if utils.startsWith(part, str) then
                    found[choice.id] = true
                    items[#items + 1] = choice
                end
            end
        end
    end
    return self
end

function Chooser:matchAppNameLike(str, items, found)
    for _, choice in pairs(self.choices) do
        if found[choice.id] == nil then
            for _, part in pairs(choice.appName) do
                if part:find(str) then
                    found[choice.id] = true
                    items[#items + 1] = choice
                end
            end
        end
    end
    return self
end

function Chooser:matchWinTitle(str, items, found)
    for _, choice in pairs(self.choices) do
        if found[choice.id] == nil then
            if utils.startsWith(choice.winTitle, str) then
                found[choice.id] = true
                items[#items + 1] = choice
            end
        end
    end
    return self
end

function Chooser:matchWinTitleLike(str, items, found)
    for _, choice in pairs(self.choices) do
        if found[choice.id] == nil then
            if choice.winTitle:find(str) then
                found[choice.id] = true
                items[#items + 1] = choice
            end
        end
    end
    return self
end

function Chooser:parseQuery(str)
    str = string.lower(str or "")

    local onlyQuery = not str:find("/")
    local onlyActions = str:sub(1, 1) == "/"
    local parts = utils.split(str, "/")
    local query = utils.ternary(onlyActions, nil, parts[1])
    local actions = utils.ternary(
            onlyQuery,
            {},
            utils.split(
                    parts[utils.ternary(onlyActions, 1, 2)],
                    ","
            )
    )
    local newActions = {}
    local stop = false

    for _, action in pairs(actions) do
        local len = string.len(action)
        local execute = action:sub(len, len) == "."

        if execute then
            action = action:sub(1, len - 1)
        end

        if self.actions[action] then
            if action == "c" then
                stop = true
            end

            if not stop then
                newActions[#newActions + 1] = action
            end

            if execute then
                newActions[#newActions + 1] = "."
                break
            end
        end
    end
    return query, newActions
end

function Chooser:resetChoices()
    self.chooser:choices(self.choices)
end

function Chooser:runActions(win, actions)
    for _, action in pairs(actions) do
        if action ~= "." then
            self.actions[action](win)
        end
    end
end

function Chooser:show()
    self.focusedWindow = hs.window.focusedWindow()
    local chooser = self.chooser
    -- Clear last search query.
    chooser:query(nil)
    -- Make sure current choices are set.
    chooser:choices(self.choices)
    -- Show chooser always on primary screen.
    local frame = hs.screen.primaryScreen():frame()
    chooser:show(hs.geometry.new((frame.w / 2) - (chooser:width() / 2), 200))
    return self
end

return Chooser:new()