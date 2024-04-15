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

-- Sound Credits:
-- voice: https://ttsfree.com/ - English (US), Jenny
-- success.wav: https://freesound.org/people/rhodesmas/sounds/342750/
-- crane_move.wav: https://freesound.org/people/DCSFX/sounds/366123/ (NC!)
-- woosh.wav: https://freesound.org/people/Vilkas_Sound/sounds/460476/
-- tick.wav: https://freesound.org/people/MrOwn1/sounds/110314/
-- reset_score.wav: https://freesound.org/people/steeltowngaming/sounds/537739/
-- menu_game_change.wav: https://freesound.org/people/F.M.Audio/sounds/560330/
-- explode.wav: https://freesound.org/people/DeltaCode/sounds/667660/
-- quirky-dog.mp3: Kevin MacLeod - https://incompetech.com/music/royalty-free/licenses/
-- intrigue-fun-21661.mp3: https://pixabay.com/music/funk-intrigue-fun-21661/
-- hitman: Keving MacLeod - https://incompetech.com/music/royalty-free/licenses/


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
-- [ ] Other sound effects: select game, change game in main menu, change settings, restart?, reset scores
--     Individual select sounds per game (current select might fit simon well, ticktick for bomb), individual lose sounds? (current fits bomb)
-- [X] Reset score (menu item? in settings?)
-- [X] new highscore screen and sound
-- [ ] new highscore music
-- [X] bomb explode sound for lose
-- [X] random stars from outside on the highscore screen
-- [X] highscore screen score dependant? (>30 with animation, >50 with stars -> simon values?)
-- [ ] tear particles on lose screen
-- [X] no "new highscore" stars on high=0? (hide highscore as well)
-- [ ] music for bomb mode
-- [ ] load common music and sound effects only once (in Statemachine maybe)

import "CoreLibs/graphics"

import "transition"
import "menu"
import "savegame"

local gfx <const> = playdate.graphics

-- Global state
local sampleplayer = playdate.sound.sampleplayer.new("sounds/dummy")
Statemachine = {
    cleanup = nil, -- needed for going back to main menu through system menu
    gameShouldFailAfterResume = false,
    font = gfx.font.new("images/font/party"),
    music = sampleplayer,
}

function Statemachine.playWAV(sample)
    if not save.data.settings.musicOn then return end

    Statemachine.music:stop()
    Statemachine.music = Statemachine.sampleplayer
    Statemachine.music:setSample(sample)
    Statemachine.music:play(0)
end

function Statemachine.playMP3(fileplayer)
    if not save.data.settings.musicOn then return end

    Statemachine.music:stop()
    Statemachine.music = fileplayer
    -- NOTE (JS, 15.04.23): Stopping and playing mp3 files without looping
    -- is very unreliable atm. Sometimes the file will not play on the second
    -- round, sometimes it will act as if it was paused instead of stopped.
    -- These bugs do not occur on looping files, so we just loop everything...
    Statemachine.music:play(0)
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
local systemMenu = playdate.getSystemMenu()

local goToMenuItem, _ = systemMenu:addMenuItem("Main Menu", function()
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
transition.setup_second(splash_setup, splash_render)