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

local MAX_SETTINGS <const> = 5

local settings_buttonHandler = {
    upButtonDown = function()
        if selectedIndex > 1 then
            selectedIndex = selectedIndex - 1
            settings.render()
        end
    end,
    
    downButtonDown = function()
        if selectedIndex < MAX_SETTINGS then
            selectedIndex = selectedIndex + 1
            settings.render()
        end
    end,

    rightButtonDown = function()

    end,

    leftButtonDown = function()

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

    local crankProgress = (selectedIndex - 1) / (MAX_SETTINGS - 1)
    gfx.setLineWidth(4)
    gfx.setColor(gfx.kColorBlack)
    gfx.drawLine(366, 18, 366, 25 + (82 - 25) * crankProgress)
    imgCrank:drawCentered(366,38 + (96 - 38) * crankProgress)

    local yPos = 40
    local spacing <const> = 24
    local drawIndex = 1
    for k,v in pairs(settings.data) do
        gfx.drawTextAligned(settings.strings[k], 12, yPos, kTextAlignment.left)
        local str
        if type(v) == "boolean" then
            str = v and "ON" or "OFF"
        else
            str = ""..v
        end
        gfx.drawTextAligned(str, 230, yPos, kTextAlignment.right)

        if drawIndex == selectedIndex then
            -- drawTextAligned sadly does not return width,height like drawText does
            local width = Statemachine.font:getTextWidth(str)
            gfx.drawText("<", 230 - width - 21, yPos)
            gfx.drawText(">", 230 + 6, yPos)
        end

        yPos = yPos + spacing
        drawIndex = drawIndex + 1
    end
end

function settings.setup()
    playdate.inputHandlers.push(settings_buttonHandler)
    playdate.update = settings_update
    Statemachine.cleanup = settings_cleanup
    Statemachine.reactToGlobalEvents = false
end

settings.data = {}
settings.strings = nil
settings.callback = nil