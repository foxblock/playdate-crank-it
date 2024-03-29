if settings then return end  -- avoid loading twice the same module
settings = {}  -- create a table to represent the module

import "CoreLibs/graphics"
import "CoreLibs/animator"
import "CoreLibs/easing"

import "savegame"

local gfx <const> = playdate.graphics
local easings <const> = playdate.easingFunctions
local snd <const> = playdate.sound.sampleplayer


local background = gfx.image.new("images/settings/bg")
local imgPlaydate = gfx.image.new("images/settings/playdate")
local imgCrane = gfx.image.new("images/settings/crane")
local imgCrank = gfx.image.new("images/settings/crank")
local imgButtons = gfx.image.new("images/settings/buttons")
local zzz = {
    { x = 315, y = 62, img = gfx.image.new("images/settings/z"), scale = gfx.animator.new(2500, 0.5, 1, easings.inOutCubic) },
    { x = 322, y = 50, img = gfx.image.new("images/settings/zz"), scale = gfx.animator.new(2500, 0.5, 1, easings.inOutCubic, 500) },
    { x = 331, y = 39, img = gfx.image.new("images/settings/zzz"), scale = gfx.animator.new(2500, 0.5, 1, easings.inOutCubic, 1000) },
}
for _,v in ipairs(zzz) do
    v.scale.repeatCount = -1
    v.scale.reverses = true
end

local CRANK_START_Y <const> = 25
local CRANK_END_Y <const> = 82

local craneAnimator = gfx.animator.new(750, CRANK_START_Y, CRANK_START_Y)
local craneSound = snd.new("sounds/crane_move")
local sndTick = snd.new("sounds/menu_tick")

local selectedIndex = 1



local function settings_cleanup()
    playdate.inputHandlers.pop()
end

local function start_crane()
    local currVal = craneAnimator:currentValue()
    local craneProgress = (selectedIndex - 1) / (#settings.config - 1)
    craneAnimator = gfx.animator.new(750, 
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
            craneSound:stop()
            craneSound:play(1)
        end
    end,

    downButtonDown = function()
        if selectedIndex < #settings.config then
            selectedIndex = selectedIndex + 1
            start_crane()
            settings.render()
            craneSound:stop()
            craneSound:play(1)
        end
    end,

    rightButtonDown = function()
        local cfg = settings.config[selectedIndex]
        local k = cfg.k
        local v = settings.data[k]
        if type(v) == "boolean" then
            settings.data[k] = not v
        elseif cfg.options ~= nil then
            if cfg.optionIndex >= #cfg.options then return end
            
            cfg.optionIndex = cfg.optionIndex + 1
            settings.data[k] = cfg.options[cfg.optionIndex]
        else
            settings.data[k] = settings.data[k] + 1
        end
        sndTick:play(1)
        settings.render()
    end,
    
    leftButtonDown = function()
        local cfg = settings.config[selectedIndex]
        local k = cfg.k
        local v = settings.data[k]
        if type(v) == "boolean" then
            settings.data[k] = not v
        elseif cfg.options ~= nil then
            if cfg.optionIndex <= 1 then return end
            
            cfg.optionIndex = cfg.optionIndex - 1
            settings.data[k] = cfg.options[cfg.optionIndex]
        else
            settings.data[k] = settings.data[k] - 1
        end
        sndTick:play(1)
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
    imgPlaydate:drawCentered(319,116)

    gfx.setLineWidth(4)
    gfx.setColor(gfx.kColorBlack)
    gfx.drawLine(366, 18, 366, craneAnimator:currentValue())
    imgCrank:drawCentered(366, 13 + craneAnimator:currentValue())
end

local function render_zzz(clear)
    if clear then
        gfx.setColor(gfx.kColorWhite)
        gfx.fillRect(309, 31, 29, 38)
    end
    for _,v in ipairs(zzz) do
        -- Round 0.99x up to 1 (easing functions might not reach 1 exactly, which looks off)
        v.img:drawRotated(v.x, v.y, 0, math.floor(100 * v.scale:currentValue() + 1) / 100)
    end
end

local function settings_update()
    if not craneAnimator:ended() then
        render_crane(true)
    end
    render_zzz(true)
end

function settings.render()
    background:draw(0,0)
    imgButtons:drawCentered(330,204)

    render_crane()
    render_zzz()

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
end

-- actual data and structure of settings defined in savegame.lua
settings.data = {}
settings.config = nil
settings.callback = nil