if settings then return end  -- avoid loading twice the same module
settings = {}  -- create a table to represent the module

import "savegame"

local gfx <const> = playdate.graphics


local background = gfx.image.new("images/settings/bg")
local imgPlaydate = gfx.image.new("images/settings/playdate")
local imgCrane = gfx.image.new("images/settings/crane")
local imgCrank = gfx.image.new("images/settings/crank")
local imgButtons = gfx.image.new("images/settings/buttons")

local selectedIndex = 1


local function settings_cleanup()
    playdate.inputHandlers.pop()
end

local settings_buttonHandler = {
    upButtonDown = function()
        if selectedIndex > 1 then
            selectedIndex = selectedIndex - 1
            settings.render()
        end
    end,

    downButtonDown = function()
        if selectedIndex < #settings.config then
            selectedIndex = selectedIndex + 1
            settings.render()
        end
    end,

    rightButtonDown = function()
        local cfg = settings.config[selectedIndex]
        local k = cfg.k
        local v = settings.data[k]
        if type(v) == "boolean" then
            settings.data[k] = not v
        elseif cfg.options ~= nil then
            if cfg.optionIndex < #cfg.options then
                cfg.optionIndex = cfg.optionIndex + 1
                settings.data[k] = cfg.options[cfg.optionIndex]
            end
        else
            settings.data[k] = settings.data[k] + 1
        end
        settings.render()
    end,

    leftButtonDown = function()
        local cfg = settings.config[selectedIndex]
        local k = cfg.k
        local v = settings.data[k]
        if type(v) == "boolean" then
            settings.data[k] = not v
        elseif cfg.options ~= nil then
            if cfg.optionIndex > 1 then
                cfg.optionIndex = cfg.optionIndex - 1
                settings.data[k] = cfg.options[cfg.optionIndex]
            end
        else
            settings.data[k] = settings.data[k] - 1
        end
        settings.render()
    end,

    AButtonDown = function()
        settings_cleanup()
        settings.callback(settings.data)
    end,

    BButtonDown = function()
        settings_cleanup()
        settings.callback(nil)
    end,
}

local function settings_update()

end


function settings.render()
    background:draw(0,0)
    imgPlaydate:drawCentered(319,116)
    imgButtons:drawCentered(330,204)
    imgCrane:drawCentered(347,14)

    local crankProgress = (selectedIndex - 1) / (#settings.config - 1)
    gfx.setLineWidth(4)
    gfx.setColor(gfx.kColorBlack)
    gfx.drawLine(366, 18, 366, 25 + (82 - 25) * crankProgress)
    imgCrank:drawCentered(366, 38 + (96 - 38) * crankProgress)

    local yPos = 40
    local spacing <const> = 24
    for i = 1, #settings.config do
        local k = settings.config[i].k
        local v = settings.data[k]
        local label = settings.config[i].s
        gfx.drawTextAligned(label, 15, yPos, kTextAlignment.left)
        local str
        if type(v) == "boolean" then
            str = v and "ON" or "OFF"
        elseif settings.config[i].optionsStr ~= nil then
            str = settings.config[i].optionsStr[settings.config[i].optionIndex]
        else
            str = ""..v
        end
        gfx.drawTextAligned(str, 244, yPos, kTextAlignment.right)

        if i == selectedIndex then
            -- drawTextAligned sadly does not return width,height like drawText does
            local width = Statemachine.font:getTextWidth(str)
            gfx.drawText("<", 244 - width - 21, yPos)
            gfx.drawText(">", 244 + 6, yPos)
        end

        yPos = yPos + spacing
        i = i + 1
    end
end

function settings.setup()
    playdate.inputHandlers.push(settings_buttonHandler)
    playdate.update = settings_update
    Statemachine.cleanup = settings_cleanup
    Statemachine.reactToGlobalEvents = false
end

-- actual data and structure of settings defined in savegame.lua
settings.data = {}
settings.config = nil
settings.callback = nil