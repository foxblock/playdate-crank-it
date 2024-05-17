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
        -- img = gfx.image.new("images/menu/btn_start"),
        -- x = 200,
        -- y = 180,
        -- rot = newAnimator(2500, -3, 3, easings.inOutSine),
        img = gfx.animation.loop.new(33, gfx.imagetable.new("images/menu/press_start")),
        x = 20,
        y = 148,
        cached = true,
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
            -- img = gfx.image.new("images/menu/crank_mascot"),
            -- x = 322,
            -- y = 75,
            -- rot = newAnimator(500, -10, 10, easings.inOutCubic),
            -- scale = newAnimator(1500, 0.95, 1.05, easings.inOutBack),
            img = gfx.animation.loop.new(33, gfx.imagetable.new("images/menu/crank_mascot")),
            x = 250,
            y = 3,
            cached = true,
        },
        tagline = {
            img = gfx.image.new("images/menu/crank_tagline_pixel"),
            x = 1,
            y = 1,
        },
        bg = gfx.image.new("images/menu/crank_bg"),
        music = mp3.new("music/quirky-dog"),
    },
    [GAME_MODE.SIMON] = {
        mascot = {
            -- img = gfx.image.new("images/menu/simon_mascot"),
            -- x = 321,
            -- y = 74,
            -- rot = newAnimator(3000, -15, 5, easings.inOutSine),
            img = gfx.animation.loop.new(33, gfx.imagetable.new("images/menu/simon_mascot")),
            x = 266,
            y = 10,
            cached = true,
        },
        tagline = {
            -- img = gfx.image.new("images/menu/simon_tagline"),
            -- x = 208,
            -- y = 37,
            -- rot = newAnimator(2000, -5, 5, easings.inOutSine),
            -- scale = newAnimator(2000, 0.95, 1.05, easings.inOutSine),
            img = gfx.animation.loop.new(33, gfx.imagetable.new("images/menu/simon_tagline")),
            x = 149,
            y = 8,
            cached = true,
        },
        bg = gfx.image.new("images/menu/simon_bg"),
        music = mp3.new("music/intrigue-fun"),
    },
    [GAME_MODE.BOMB] = {
        mascot = {
            -- img = gfx.image.new("images/menu/bomb_mascot"),
            -- x = 325,
            -- y = 72,
            -- rot = newAnimator(1000, -8, 8, easings.inOutElastic),
            img = gfx.animation.loop.new(33, gfx.imagetable.new("images/menu/bomb_mascot")),
            x = 254,
            y = 6,
            cached = true,
        },
        tagline = {
            img = gfx.image.new("images/menu/bomb_tagline"),
            x = 133,
            y = 130,
            scale = newBlinkerAnimator(500, 500, 0, 1.09)
        },
        bg = gfx.image.new("images/menu/bomb_bg"),
        music = mp3.new("music/hitman"),
    },
}


local selectedGame = 1
local CRANK_RESET_TRIGGER <const> = 720
local crankToReset = 0
local showReset = false
local menu_update

local function initBlinker(item)
    item.lastScale = item.scale.startValue
    local width, height = item.img:getSize()
    local fullScale = item.scale.endValue
    item.rect = playdate.geometry.rect.new(item.x - width * fullScale / 2 - 1, item.y - height * fullScale / 2 - 1,
            width * fullScale + 1, height * fullScale + 1)
end

initBlinker(elements.btnArrowLeft)
initBlinker(elements.btnArrowRight)
initBlinker(elements[GAME_MODE.BOMB].tagline)

local function drawBlinker(item, fullRedraw)
    if fullRedraw == nil and item.lastScale ~= nil and item.lastScale == item.scale:value() then return end

    if item.lastScale > item.scale:value() then
        gfx.setColor(gfx.kColorWhite)
        gfx.fillRect(item.rect)
    end
    item.lastScale = item.scale:value()
    item.img:drawRotated(item.x, item.y, 0, item.lastScale)
end

local function drawMenuItem(item, fullRedraw)
    if item.rot ~= nil and item.scale ~= nil then
        item.img:drawRotated(item.x, item.y, item.rot:currentValue(), item.scale:currentValue())
    elseif item.rot ~= nil then
        item.img:drawRotated(item.x, item.y, item.rot:currentValue())
    elseif item.scale ~= nil then
        drawBlinker(item, fullRedraw)
    elseif item.cached ~= nil then
        item.img:draw(item.x, item.y)
    else
        item.img:drawCentered(item.x, item.y)
    end
end

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
    transition.setup(menu.setup, menu.fullRedraw)
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
        menu.fullRedraw()
        crankToReset = 0
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
        menu.fullRedraw()
        crankToReset = 0
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

        crankToReset = crankToReset + change

        if crankToReset >= CRANK_RESET_TRIGGER then
            save.data.highscore[selectedGame] = 0
            save.write()
            scoreResetSound:play(1)
            crankToReset = 0
        elseif crankToReset >= CRANK_RESET_TRIGGER * 0.05 then
            showReset = true
        end
    end,
}

function menu.fullRedraw()
    elements[selectedGame].bg:draw(0,0)
    drawMenuItem(elements.btnArrowLeft, true)
    drawMenuItem(elements.btnArrowRight, true)
    if selectedGame == GAME_MODE.BOMB then
        drawMenuItem(elements[GAME_MODE.BOMB].tagline, true)
    else
        gfx.drawTextAligned("HIGHSCORE: "..save.data.highscore[selectedGame], 139, 118, kTextAlignment.center)
    end
    menu_update()
end

menu_update = function()
    drawMenuItem(elements[selectedGame].mascot)
    drawMenuItem(elements[selectedGame].tagline)

    if selectedGame ~= GAME_MODE.BOMB and showReset then
        -- floor to keep "integer" value
        crankToReset = math.floor(crankToReset - 2)
        if crankToReset <= 0 then
            showReset = false
            gfx.setColor(gfx.kColorWhite)
            gfx.fillRect(52, 116, 174, 22)
            gfx.drawTextAligned("HIGHSCORE: "..save.data.highscore[selectedGame], 139, 118, kTextAlignment.center)
        else
            gfx.setColor(gfx.kColorWhite)
            gfx.fillRect(52, 116, 174, 22)
            gfx.setColor(gfx.kColorBlack)
            gfx.fillRect(52, 116, 174 * crankToReset / CRANK_RESET_TRIGGER, 22)

            gfx.setImageDrawMode(gfx.kDrawModeNXOR)
            gfx.drawTextAligned("RESETTING...", 139, 118, kTextAlignment.center)
            gfx.setImageDrawMode(gfx.kDrawModeCopy)
        end
    end

    drawMenuItem(elements.btnArrowLeft)
    drawMenuItem(elements.btnArrowRight, true)

    drawMenuItem(elements.btnStart)
end

function menu.setup()
    playdate.inputHandlers.push(buttonHandlers_title)
    playdate.update = menu_update
    Statemachine.cleanup = menu_cleanup
    if not Statemachine.music:isPlaying() then
        elements[selectedGame].music:play(0)
    end
    elements[selectedGame].bg:draw(0,0)
    crankToReset = 0
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