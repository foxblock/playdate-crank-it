if credits then return end  -- avoid loading twice the same module
credits = {}  -- create a table to represent the module

import "CoreLibs/graphics"

import "transition"
import "menu"

local gfx <const> = playdate.graphics

local splashImages <const> = {
    gfx.image.new("images/credits"),
    gfx.image.new("images/music_credits"),
    gfx.image.new("images/sound_credits"),
    gfx.image.new("images/thanks_for_playing"),
}
local currentSplash = 1
local splash_next

local buttonHandlers_credits <const> = {
    AButtonDown = function()
        splash_next()
    end,
    BButtonDown = function()
        splash_next()
    end,
}

local function update_none()
    --
end


splash_next = function()
    currentSplash = currentSplash + 1
    if currentSplash > #splashImages then
        credits.cleanup()
        transition.setup(menu.setup, menu.fullRedraw)
    else
        transition.setup(nil, credits.render)
    end
end

function credits.cleanup()
    playdate.inputHandlers.pop()
    currentSplash = 1
end

function credits.setup()
    playdate.inputHandlers.push(buttonHandlers_credits)
    playdate.update = update_none
end

function credits.render()
    splashImages[currentSplash]:draw(0,0)
end