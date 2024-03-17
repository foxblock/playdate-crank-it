-- https://www.youtube.com/watch?v=ayBmsWKqdnc
-- https://www.amazon.de/Bop-Elektronisches-Spiel-Kinder-Jahren/dp/B07T41GXYC

-- Accelerometer
-- Values of readAccelerometer() = normal vector pointing from screen with device upright
--                                 in the following coordinate space
--      ^ z = 1
--      |
--      |
--      .-----> x = 1 (device also needs to be rotated by 90° around x-axis)
--     /
--    /
--   v  y = 1

------ TODO
-- [X] action: pass to other player
-- [X] action: speed up
-- [X] default time value for individual actions (i.e. more time for dock/undock)
-- [X] multiply by speed factor
-- [X] lose on lock
-- [ ] game mode: last one cranking (versus, each player gets a few actions in sequence)
-- [X] game mode: simon cranks (solo, you get a sequence and have to do it afterwards)
-- [ ] game mode: crank the bomb (party, you do an action as fast as possible then pass, bomb explodes after random time)
-- [X] background animations for actions
-- [X] sound for actions
-- [X] background music
-- [X] save highscore values
-- [X] title card (350 x 155), card animation and icon (32 x 32)
-- [X] Other neccessary pdxinfo data: https://sdk.play.date/2.0.3/Inside%20Playdate.html#pdxinfo
-- [X] options to disable accelerometer and mic based actions
-- [X] Better score and highscore display
-- [X] main menu - do not start the game immediately
-- [X] add title card recommending to play without the cover (https://devforum.play.date/t/crank-docking-not-registered/10439)
-- [ ] sound convert script: add option to convert single file if passed path is a file
-- [X] go to main menu option in menu
-- [x] short transition/swipe/... between actions in simon mode -> helps split same actions when playing without sound
-- [ ] Check color table: needs inverted (compared to b/w), need raw b/w version?, correct colors compared to screenshot/video?
-- [X] Add credits to splash screen
-- [ ] Add transition sound effects
-- [X] Fix being able to skip transitions in splash -> error
-- [ ] Main menu music
-- [ ] Crane sound in settings


import "CoreLibs/graphics"

import "game_constants"
import "game_actions"
import "mode_crankit"
import "mode_simon"
import "settings"
import "transition"
import "savegame"
import "menu"

local gfx <const> = playdate.graphics
local snd <const> = playdate.sound.sampleplayer

-- Global state
Statemachine = {
    cleanup = nil, -- needed for going back to main menu through system menu
    gameShouldFailAfterResume = false,
    music = snd.new("sounds/dummy"),
    font = gfx.font.new("images/font/party")
}

local function copyTable(dst, src)
    for k in pairs(dst) do dst[k] = nil end
    for k, v in pairs(src) do dst[k] = v end
end

------ SPLASH IMAGES

local splashImages = {
    gfx.image.new("images/remove_cover"),
    gfx.image.new("images/credits"),
}

local currentSplash = 1
local splash_next

local buttonHandlers_intro = {
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

local function splash_render()
    splashImages[currentSplash]:draw(0,0)
end

local function splash_cleanup()
    playdate.inputHandlers.pop()
end

local function splash_setup()
    playdate.inputHandlers.push(buttonHandlers_intro)
    playdate.update = update_none
end

splash_next = function()
    currentSplash = currentSplash + 1
    if currentSplash > #splashImages then
        splash_cleanup()
        transition.setup(menu.setup, menu.update)
    else
        splash_cleanup()
        transition.setup(splash_setup, splash_render)
    end
end

------ MENU

local function menu_result(optionIndex)
    if (optionIndex == GAME_MODE.CRANKIT) then
        crankit.pre_setup_for_transition()
        transition.setup(crankit.setup, crankit.render_for_transition)
    elseif (optionIndex == GAME_MODE.SIMON) then
        transition.setup(simon.setup, simon.render_for_transition)
    elseif (optionIndex == GAME_MODE.SETTINGS) then
        copyTable(settings.data, save.data.settings)
        transition.setup(settings.setup, settings.render)
    end
end

menu.callback = menu_result

------ SETTINGS

local function settings_result(data)
    if (data ~= nil) then
        copyTable(save.data.settings, settings.data)
        save.write()
    end

    transition.setup(menu.setup, menu.update)
end

settings.callback = settings_result
settings.config = save.settingsMetadata

------ CALLBACKS

function playdate.deviceWillLock()
    Statemachine.gameShouldFailAfterResume = true
end

-- waiting for the following bug to get fixed:
-- https://devforum.play.date/t/calling-order-after-selecting-menu-item-is-wrong/14493
function playdate.gameWillResume()
    Statemachine.gameShouldFailAfterResume = true
end

------ MAIN
save.load()

-- setup playdate menu
local sytemMenu = playdate.getSystemMenu()

local goToMenuItem, _ = sytemMenu:addMenuItem("Main Menu", function()
    if (Statemachine.cleanup ~= nil) then
        Statemachine.cleanup()
    end
    menu.setup()
end)

-- Start
math.randomseed(playdate.getSecondsSinceEpoch())
playdate.setCrankSoundsDisabled(true)

gfx.setColor(gfx.kColorWhite)
gfx.setFont(Statemachine.font)
gfx.clear()
transition.setup_second(splash_setup, splash_render)