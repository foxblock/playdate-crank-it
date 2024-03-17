if settings then return end  -- avoid loading twice the same module
settings = {}  -- create a table to represent the module

import "CoreLibs/graphics"
import "CoreLibs/animator"
import "CoreLibs/easing"

import "savegame"

local gfx <const> = playdate.graphics
local easings <const> = playdate.easingFunctions


local background = gfx.image.new("images/settings/bg")
local imgPlaydate = gfx.image.new("images/settings/playdate")
local imgCrane = gfx.image.new("images/settings/crane")
local imgCrank = gfx.image.new("images/settings/crank")
local imgButtons = gfx.image.new("images/settings/buttons")

local CRANK_START_Y <const> = 25
local CRANK_END_Y <const> = 82

local selectedIndex = 1
local craneAnimator = gfx.animator.new(500, CRANK_START_Y, CRANK_START_Y)


local function settings_cleanup()
    playdate.inputHandlers.pop()
end

local function start_crane()
    local currVal = craneAnimator:currentValue()
    local craneProgress = (selectedIndex - 1) / (#settings.config - 1)
    craneAnimator = gfx.animator.new(500, 
        currVal, 
        CRANK_START_Y + (CRANK_END_Y - CRANK_START_Y) * craneProgress,
        easings.inOutQuad)
end

local settings_buttonHandler = {
    upButtonDown = function()
        if selectedIndex > 1 then
            selectedIndex = selectedIndex - 1
            start_crane()
            settings.render()
        end
    end,

    downButtonDown = function()
        if selectedIndex < #settings.config then
            selectedIndex = selectedIndex + 1
            start_crane()
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

local function render_crane(clear)
    if clear then
        gfx.setColor(gfx.kColorWhite)
        gfx.fillRect(341, 11, 387, 122)
    end

    imgCrane:drawCentered(347,14)
    imgPlaydate:drawCentered(319,98)

    gfx.setLineWidth(4)
    gfx.setColor(gfx.kColorBlack)
    gfx.drawLine(366, 18, 366, craneAnimator:currentValue())
    imgCrank:drawCentered(366, 13 + craneAnimator:currentValue())
end

local function settings_update()
    if not craneAnimator:ended() then
        render_crane(true)
    end
end

function settings.render()
    background:draw(0,0)
    imgButtons:drawCentered(330,204)

    render_crane()

    local yPos = 40
    local spacing <const> = 24
    for i,cfg in ipairs(settings.config) do
        local v = settings.data[cfg.k]

        gfx.drawTextAligned(cfg.s, 15, yPos, kTextAlignment.left)

        local str
        if type(v) == "boolean" then
            str = v and "ON" or "OFF"
        elseif cfg.optionsStr ~= nil then
            str = cfg.optionsStr[cfg.optionIndex]
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