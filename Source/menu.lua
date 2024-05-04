if menu then return end  -- avoid loading twice the same module
menu = {}  -- create a table to represent the module

import "CoreLibs/graphics"
import "CoreLibs/animator"
import "CoreLibs/easing"

import "game_constants"
import "mode_crankit"
import "mode_simon"
import "mode_bomb"
import "settings"
import "savegame"
import "transition"

local gfx <const> = playdate.graphics
local easings <const> = playdate.easingFunctions
local snd <const> = playdate.sound.sampleplayer
local mp3 <const> = playdate.sound.fileplayer

local introMusic = playdate.sound.fileplayer.new("music/quirky-dog-intro")

local gameChangeSound = snd.new("sounds/menu_game_change")
local gameSelectSound = snd.new("sounds/menu_game_select")
local scoreResetSound = snd.new("sounds/score_reset")

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
        music = mp3.new("music/quirky-dog"),
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
        music = mp3.new("music/intrigue-fun"),
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
        music = mp3.new("music/hitman"),
    },
}


local selectedGame = 1
local CRANK_RESET_TRIGGER <const> = 360
local crankToReset = 0


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

-- bgSprite = gfx.sprite.setBackgroundDrawingCallback(
--     function( x, y, width, height )
--         -- x,y,width,height is the updated area in sprite-local coordinates
--         -- The clip rect is already set to this area, so we don't need to set it ourselves
--         actions[currAction].img:draw(0,0)
--     end
-- )

local function menu_cleanup()
    if settings.active then
        settings.cleanup()
        elements[selectedGame].music:setVolume(1, 1, 0.5)
    end
    if Statemachine.music:isPlaying() then
        Statemachine.music:pause()
    end
    playdate.inputHandlers.pop()
    elements[selectedGame].music:pause()
    menu.active = false
end

local function menu_toSettings()
    playdate.inputHandlers.pop()
    elements[selectedGame].music:setVolume(0.16, 0.16, 0.5)
end

local function settings_result(data)
    if (data ~= nil) then
        save.data.settings = data
        save.write()
    end

    elements[selectedGame].music:setVolume(1, 1, 0.5)
    transition.setup(menu.setup, menu.update)
end

local buttonHandlers_title = {
    leftButtonDown = function()
        elements[selectedGame].music:pause()
        if (selectedGame == 1) then
            selectedGame = GAME_MODE._EOL - 1
        else
            selectedGame = selectedGame - 1
        end
        gameChangeSound:play(1)
        if not Statemachine.music:isPlaying() then
            elements[selectedGame].music:play(0)
        end
    end,

    rightButtonDown = function()
        elements[selectedGame].music:pause()
        if (selectedGame == GAME_MODE._EOL - 1) then
            selectedGame = 1
        else
            selectedGame = selectedGame + 1
        end
        gameChangeSound:play(1)
        if not Statemachine.music:isPlaying() then
            elements[selectedGame].music:play(0)
        end
    end,

    AButtonDown = function()
        gameSelectSound:play(1)
        menu_cleanup()

        if (selectedGame == GAME_MODE.CRANKIT) then
            crankit.pre_setup_for_transition()
            transition.setup(crankit.setup, crankit.render_for_transition)
        elseif (selectedGame == GAME_MODE.SIMON) then
            transition.setup(simon.setup, simon.render_for_transition)
        elseif (selectedGame == GAME_MODE.BOMB) then
            bomb.pre_setup_for_transition()
            transition.setup(bomb.setup, bomb.render_for_transition)
        end
    end,

    BButtonDown = function()
        menu_toSettings()

        settings.setup(save.data.settings, save.settingsMetadata, settings_result)
        transition.setup(settings.show, settings.render)
    end,

    cranked = function(change, acceleratedChange)
        if save.data.highscore[selectedGame] == 0 then
            return
        end

        if crankToReset <= 0 and change > 0 then
            crankToReset = CRANK_RESET_TRIGGER * 0.1 -- to avoid flickering on start
        else
            crankToReset = crankToReset + change
        end

        if crankToReset >= CRANK_RESET_TRIGGER then
            save.data.highscore[selectedGame] = 0
            save.write()
            scoreResetSound:play(1)
            crankToReset = 0
        elseif crankToReset < 0 then
            crankToReset = 0
        end
    end,
}

function menu.update()
    gfx.setColor(gfx.kColorWhite)
    gfx.clear()

    drawMenuItem(elements[selectedGame].logo)
    drawMenuItem(elements[selectedGame].tagline)
    drawMenuItem(elements[selectedGame].mascot)

    if selectedGame ~= GAME_MODE.BOMB then
        if crankToReset <= 0 then
            gfx.drawTextAligned("HIGHSCORE: "..save.data.highscore[selectedGame], 139, 118, kTextAlignment.center)
        else
            gfx.setColor(gfx.kColorBlack)
            gfx.fillRect(139 - 76, 116, 152 * crankToReset / CRANK_RESET_TRIGGER, 22)

            gfx.setImageDrawMode(gfx.kDrawModeNXOR)
            gfx.drawTextAligned("RESETTING...", 139, 118, kTextAlignment.center)
            gfx.setImageDrawMode(gfx.kDrawModeCopy)

            -- floor to keep "integer" value
            crankToReset = math.floor(crankToReset - 4)
        end
    end

    drawMenuItem(elements.btnArrowLeft)
    drawMenuItem(elements.btnArrowRight)

    drawMenuItem(elements.btnStart)
    drawMenuItem(elements.btnSelect)
    drawMenuItem(elements.btnSettings)
end

function menu.setup()
    playdate.inputHandlers.push(buttonHandlers_title)
    playdate.update = menu.update
    Statemachine.cleanup = menu_cleanup
    if not Statemachine.music:isPlaying() then
        elements[selectedGame].music:play(0)
    end
    menu.active = true
end

menu.active = false

local function introMusicEnd()
    elements[selectedGame].music:play(0)
end

function menu.startIntroMusic()
    introMusic:setFinishCallback(introMusicEnd)
    Statemachine.playMP3(introMusic, 1)
end