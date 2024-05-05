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

-- Sound credits:
-- voice: https://ttsfree.com/ - English (US), Jenny
-- success.wav: https://freesound.org/people/rhodesmas/sounds/342750/ - CC-BY 3.0
-- woosh.wav: https://freesound.org/people/Vilkas_Sound/sounds/460476/ - CC-BY 4.0
-- menu_game_change.wav: https://freesound.org/people/F.M.Audio/sounds/560330/ - CC-BY 4.0
-- reset_score.wav: https://freesound.org/people/steeltowngaming/sounds/537739/ - CC
-- explode.wav: https://freesound.org/people/DeltaCode/sounds/667660/ - CC
-- Music credits:
-- quirky-dog.mp3: Kevin MacLeod - https://incompetech.com/music/royalty-free/licenses/ - CC-BY 3.0
-- hitman: Keving MacLeod - https://incompetech.com/music/royalty-free/licenses/ - CC-BY 3.0
-- intrigue-fun-21661.mp3: https://pixabay.com/music/funk-intrigue-fun-21661/ - Pixabay

------ TODO
-- [X] action: pass to other player
-- [X] action: speed up
-- [X] default time value for individual actions (i.e. more time for dock/undock)
-- [X] multiply by speed factor
-- [X] lose on lock
-- [ ] game mode: last one cranking (versus, each player gets a few actions in sequence)
-- [X] game mode: simon cranks (solo, you get a sequence and have to do it afterwards)
-- [X] game mode: crank the bomb (party, you do an action as fast as possible then pass, bomb explodes after random time)
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
-- [X] sound convert script: add option to convert single file if passed path is a file
-- [X] go to main menu option in menu
-- [x] short transition/swipe/... between actions in simon mode -> helps split same actions when playing without sound
-- [ ] Check color table: needs inverted (compared to b/w), need raw b/w version?, correct colors compared to screenshot/video?
-- [X] Add credits to splash screen
-- [ ] Add transition sound effects -> still not happy with current swoosh
-- [X] Fix being able to skip transitions in splash -> error
-- [X] Main menu music
-- [X] Crane sound in settings
-- [X] Other sound effects: select game, change game in main menu, change settings, restart?, reset scores
--     Individual select sounds per game (current select might fit simon well, ticktick for bomb), individual lose sounds? (current fits bomb)
-- [X] Reset score (menu item? in settings?)
-- [X] new highscore screen and sound
-- [X] new highscore music
-- [X] bomb explode sound for lose
-- [X] random stars from outside on the highscore screen
-- [X] highscore screen score dependant? (>30 with animation, >50 with stars -> simon values?)
-- [ ] tear particles on lose screen
-- [X] no "new highscore" stars on high=0? (hide highscore as well)
-- [X] Play no sound when normal highscore, play jingle when stars, rave when big
-- [X] music for bomb mode
-- [ ] load common music and sound effects only once (in Statemachine maybe)
-- [X] balance sound volume
-- [X] visual effect in simon mode on correct input
-- [ ] show chain after losing simon game
-- [ ] show lose reason in crankit and bomb
-- [X] Setting to start simon with more than 1 action
-- [X] Credits screens for music and sounds
-- [X] Replace NC sounds
-- [ ] better lvl4 and 5 music
-- [X] move credits to playdate menu item
-- [X] simon: microphone should reset on multiple shout it in a row
-- [X] crank-it: increase chance for pass-it continuously
-- [ ] add deadzone for displaying the reset note in menu
-- [ ] add icons showing modifiers on lose screen

import "CoreLibs/graphics"

import "transition"
import "credits"
import "menu"
import "savegame"

local gfx <const> = playdate.graphics

-- Global state
local sampleplayer <const> = playdate.sound.sampleplayer.new("sounds/dummy")
Statemachine = {
    cleanup = nil, -- needed for going back to main menu through system menu
    gameShouldFailAfterResume = false,
    font = gfx.font.new("images/font/party"),
    music = sampleplayer,
}

function Statemachine.playWAV(sample)
    if not save.data.settings.musicOn then return end

    Statemachine.music:stop()
    Statemachine.music = sampleplayer
    Statemachine.music:setSample(sample)
    Statemachine.music:play(0)
end

function Statemachine.playMP3(fileplayer, repeatCount)
    if not save.data.settings.musicOn then return end

    Statemachine.music:stop()
    Statemachine.music = fileplayer
    -- NOTE (JS, 15.04.23): Stopping and playing mp3 files without looping
    -- is very unreliable atm. Sometimes the file will not play on the second
    -- round, sometimes it will act as if it was paused instead of stopped.
    -- These bugs do not occur on looping files, so we just loop everything...
    -- UPDATE: Okay they also appear on looping files, so we just call 
    -- setOffset(0) to make sure to play from the beginning
    Statemachine.music:setOffset(0)
    if repeatCount == nil then
        Statemachine.music:play(0)
    else
        Statemachine.music:play(repeatCount)
    end
end

------ SPLASH IMAGES

local splashImages <const> = {
    gfx.image.new("images/remove_cover"),
    gfx.image.new("images/credits"),
}

local currentSplash = 1
local splash_next

local buttonHandlers_intro <const> = {
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
        transition.setup(nil, splash_render)
    end
end

------ GLOBAL CALLBACKS

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
local systemMenu = playdate.getSystemMenu()

local creditsItem, _ = systemMenu:addMenuItem("Credits", function()
    if Statemachine.cleanup ~= nil then
        Statemachine.cleanup()
    end
    transition.setup(credits.setup, credits.render)
end)

local goToMenuItem, _ = systemMenu:addMenuItem("Main Menu", function()
    if menu.active then return end

    if (Statemachine.cleanup ~= nil) then
        Statemachine.cleanup()
    end
    transition.setup(menu.setup, menu.update)
end)

-- Start
math.randomseed(playdate.getSecondsSinceEpoch())
playdate.setCrankSoundsDisabled(true)

gfx.setColor(gfx.kColorWhite)
gfx.setFont(Statemachine.font)
transition.setup_second(splash_setup, splash_render)
menu.startIntroMusic()