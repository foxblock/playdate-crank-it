if menu then return end  -- avoid loading twice the same module
menu = {}  -- create a table to represent the module

import "CoreLibs/graphics"
import "CoreLibs/animator"
import "CoreLibs/easing"

import "savegame"
import "game_constants"

local gfx <const> = playdate.graphics
local easings <const> = playdate.easingFunctions


local selectedGame = 1


local function newAnimator(durationMS, min, max, easingFunction)
    local animator = gfx.animator.new(durationMS, min, max, easingFunction, -durationMS / 2)
    animator.repeatCount = -1
    animator.reverses = true
    animator.value = function()
        return animator:currentValue()
    end
    return animator
end

local function newBlinkerAnimator(onDurationMS, offDurationMS, offsetMS, scaleOn)
    local animator = gfx.animator.new(onDurationMS + offDurationMS, 1, scaleOn, easings.linear, offsetMS)
    animator.repeatCount = -1
    animator.thresholdValue = animator.startValue + (animator.endValue - animator.startValue) * (offDurationMS / animator.duration)
    animator.value = function()
        -- cannot use animator:progress() here, since it does not work with repeatCount=-1 (returns nil)
        if animator:currentValue() >= animator.thresholdValue then
            return animator.endValue
        end
        return animator.startValue
    end
    return animator
end

local elements <const> = {
    btnStart = {
        img = gfx.image.new("images/menu/btn_start"),
        x = 200,
        y = 180,
        rot = newAnimator(2500, -3, 3, easings.inOutSine),
    },
    btnSelect = {
        img = gfx.image.new("images/menu/btn_select"),
        x = 84,
        y = 220,
    },
    btnSettings = {
        img = gfx.image.new("images/menu/btn_settings"),
        x = 304,
        y = 220,
    },
    btnArrowLeft = {
        img = gfx.image.new("images/menu/btn_arrow_left"),
        x = 11,
        y = 86,
        scale = newBlinkerAnimator(500, 5000, 750, 1.4),
    },
    btnArrowRight = {
        img = gfx.image.new("images/menu/btn_arrow_right"),
        x = 389,
        y = 86,
        scale = newBlinkerAnimator(500, 5000, 0, 1.4),
    },
    [GAME_MODE.CRANKIT] = {
        mascot = {
            img = gfx.image.new("images/menu/crank_mascot"),
            x = 322,
            y = 75,
            rot = newAnimator(500, -10, 10, easings.inOutCubic),
            scale = newAnimator(1500, 0.95, 1.05, easings.inOutBack),
        },
        logo = {
            img = gfx.image.new("images/menu/crank_logo"),
            x = 139,
            y = 53,
        },
        tagline = {
            img = gfx.image.new("images/menu/crank_tagline"),
            x = 139,
            y = 91,
        },
    },
    [GAME_MODE.SIMON] = {
        mascot = {
            img = gfx.image.new("images/menu/simon_mascot"),
            x = 321,
            y = 74,
            rot = newAnimator(3000, -15, 5, easings.inOutSine),
        },
        logo = {
            img = gfx.image.new("images/menu/simon_logo"),
            x = 143,
            y = 65,
        },
        tagline = {
            img = gfx.image.new("images/menu/simon_tagline"),
            x = 208,
            y = 37,
            rot = newAnimator(2000, -5, 5, easings.inOutSine),
            scale = newAnimator(2000, 0.95, 1.05, easings.inOutSine),
        },
    },
    [GAME_MODE.BOMB] = {
        mascot = {
            img = gfx.image.new("images/menu/bomb_mascot"),
            x = 325,
            y = 72,
            rot = newAnimator(1000, -8, 8, easings.inOutElastic),
        },
        logo = {
            img = gfx.image.new("images/menu/bomb_logo"),
            x = 135,
            y = 63,
        },
        tagline = {
            img = gfx.image.new("images/menu/bomb_tagline"),
            x = 136,
            y = 130,
            scale = newBlinkerAnimator(500, 500, 0, 1.1)
        },
    },
}

local function drawMenuItem(item)
    if item.rot ~= nil and item.scale ~= nil then
        item.img:drawRotated(item.x, item.y, item.rot:currentValue(), item.scale:currentValue())
    elseif item.rot ~= nil then
        item.img:drawRotated(item.x, item.y, item.rot:currentValue())
    elseif item.scale ~= nil then
        item.img:drawRotated(item.x, item.y, 0, item.scale:value())
    else
        item.img:drawCentered(item.x, item.y)
    end
end

local function drawGameCard(gameIndex)
    drawMenuItem(elements[gameIndex].logo)
    drawMenuItem(elements[gameIndex].tagline)
    drawMenuItem(elements[gameIndex].mascot)

    if gameIndex ~= GAME_MODE.BOMB then
        gfx.drawTextAligned("HIGHSCORE: "..save.data.highscore[selectedGame], 139, 118, kTextAlignment.center)
    end
end

-- bgSprite = gfx.sprite.setBackgroundDrawingCallback(
--     function( x, y, width, height )
--         -- x,y,width,height is the updated area in sprite-local coordinates
--         -- The clip rect is already set to this area, so we don't need to set it ourselves
--         actions[currAction].img:draw(0,0)
--     end
-- )

local function menu_cleanup()
    playdate.inputHandlers.pop()
end

local buttonHandlers_title = {
    leftButtonDown = function ()
        if (selectedGame == 1) then
            selectedGame = GAME_MODE.EOL - 1
        else
            selectedGame = selectedGame - 1
        end
        gfx.fillRect(18, 0, 364, 149)
        drawGameCard(selectedGame)
    end,

    rightButtonDown = function ()
        if (selectedGame == GAME_MODE.EOL - 1) then
            selectedGame = 1
        else
            selectedGame = selectedGame + 1
        end
        gfx.fillRect(18, 0, 364, 149)
        drawGameCard(selectedGame)
    end,

    AButtonDown = function()
        menu_cleanup()
        menu.callback(selectedGame)
    end
}

function menu.update()
    gfx.setColor(gfx.kColorWhite)
    gfx.clear()
    drawGameCard(selectedGame)
    drawMenuItem(elements.btnArrowLeft)
    drawMenuItem(elements.btnArrowRight)

    drawMenuItem(elements.btnStart)
    drawMenuItem(elements.btnSelect)
    drawMenuItem(elements.btnSettings)
end

function menu.setup()
    playdate.inputHandlers.push(buttonHandlers_title)

    Statemachine.update = menu.update
    Statemachine.cleanup = menu_cleanup
    Statemachine.reactToGlobalEvents = false
end

menu.callback = nil