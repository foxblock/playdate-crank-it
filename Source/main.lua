-- https://www.youtube.com/watch?v=ayBmsWKqdnc
-- https://www.amazon.de/Bop-Elektronisches-Spiel-Kinder-Jahren/dp/B07T41GXYC

-- Accelerometer
-- Values of readAccelerometer() = normal vector pointing from screen with device upright
--                                 in the following coordinate space
--      ^ z = 1
--      |
--      |
--      .-----> x = 1 (device needs to be tilted by 90° around x-axis)
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
-- [ ] game mode: simon cranks (solo, you get a sequence and have to do it afterwards)
-- [ ] game mode: crank the bomb (party, you do an action as fast as possible then pass, bomb explodes after random time)
-- [X] background animations for actions
-- [X] sound for actions
-- [X] background music
-- [X] save highscore values
-- [X] title card (350 x 155), card animation and icon (32 x 32)
-- [X] Other neccessary pdxinfo data: https://sdk.play.date/2.0.3/Inside%20Playdate.html#pdxinfo
-- [ ] options to disable accelerometer and mic based actions
-- [ ] Better score and highscore display
-- [X] main menu - do not start the game immediately
-- [X] add title card recommending to play without the cover (https://devforum.play.date/t/crank-docking-not-registered/10439)


import "CoreLibs/object"
import "CoreLibs/graphics"
import "CoreLibs/sprites"
import "CoreLibs/timer"
import "CoreLibs/animation"

local gfx <const> = playdate.graphics
local mic <const> = playdate.sound.micinput
local v2d <const> = playdate.geometry.vector2D
local screen <const> = playdate.display
local snd <const> = playdate.sound.sampleplayer

local RAD_TO_DEG <const> = 180 / math.pi
local DEG_TO_RAD <const> = math.pi / 180

local actionCodes <const> = {
    LOSE = 0,
    DIRECTION = 1,
    BUTTON = 2,
    MICROPHONE = 3,
    TILT = 4,
    PASS_PLAYER = 5,
    CRANK_UNDOCK = 6,
    CRANK_DOCK = 7,
    CRANKED = 8,
    EOL = 9, ----
    SPEED_UP = 10,
}

local timeFast <const> = { 4000, 3000, 2000, 1300, 700 }
local timeNormal <const> = { 4000, 3000, 2200, 1600, 1200 }
local timeSlow <const> = { 4000, 3200, 2500, 2000, 1750 }

-- TODO: Change snd entries from sampleplayer to sample and use one global player for all action sounds
local actions <const> = {
    [actionCodes.LOSE] = {
        msg = "You lose! (Press A to restart)",
        time = timeNormal,
        snd = snd.new("sounds/lose"),
        img = gfx.image.new("images/actions/lose"),
        ani = nil
    },
    [actionCodes.DIRECTION] = {
        msg = "Move it!",
        time = timeFast,
        snd = snd.new("sounds/move"),
        img = nil,
        ani = gfx.imagetable.new("images/actions/move")
    },
    [actionCodes.BUTTON] = {
        msg = "Press it!",
        time = timeFast,
        snd = snd.new("sounds/press"),
        img = nil,
        ani = gfx.imagetable.new("images/actions/press")
    },
    [actionCodes.MICROPHONE] = {
        msg = "Shout it!",
        time = timeFast,
        snd = snd.new("sounds/shout"),
        img = gfx.image.new("images/actions/shout"),
        ani = nil
    },
    [actionCodes.TILT] = {
        msg = "Tilt it!",
        time = timeNormal,
        snd = snd.new("sounds/tilt"),
        img = nil,
        ani = gfx.imagetable.new("images/actions/tilt")
    },
    [actionCodes.PASS_PLAYER] = {
        msg = "Pass it!",
        time = { 3000, 3000, 2500, 2500, 2000 },
        snd = snd.new("sounds/pass"),
        img = nil,
        ani = gfx.imagetable.new("images/actions/pass")
    },
    [actionCodes.CRANK_UNDOCK] = {
        msg = "Undock it!",
        time = timeNormal,
        snd = snd.new("sounds/undock"),
        img = gfx.image.new("images/actions/undock"),
        ani = nil
    },
    [actionCodes.CRANK_DOCK] = {
        msg = "Dock it!",
        time = timeSlow,
        snd = snd.new("sounds/dock"),
        img = gfx.image.new("images/actions/dock"),
        ani = nil
    },
    [actionCodes.CRANKED] = {
        msg = "Crank it!",
        time = timeSlow,
        snd = snd.new("sounds/crank"),
        img = nil,
        ani = gfx.imagetable.new("images/actions/crank")
    },
    [actionCodes.SPEED_UP] = {
        msg = "SPEED UP",
        time = { 2000, 2000, 2000, 2000, 2000 },
        snd = snd.new("sounds/speed"),
        img = gfx.image.new("images/actions/speed"),
        ani = nil
    }
}

-- set up animations
-- actions with img set, keep that as a static background
-- actions with ani set (we assume it is a tilemap), will load it into img as an animation
-- actions with neither set will get an ERROR
local ACTION_ANIMATION_FRAME_TIME_MS <const> = 500
for k,v in pairs(actions) do
    if (v.img ~= nil) then
        goto continue
    elseif (v.ani ~= nil) then
        v.img = gfx.animation.loop.new(ACTION_ANIMATION_FRAME_TIME_MS, v.ani, true)
    else
        error("No image or animation defined for action: " .. k)
    end
    ::continue::
end

local bgMusic <const> = {
    playdate.sound.sample.new("music/bg1"),
    playdate.sound.sample.new("music/bg2"),
    playdate.sound.sample.new("music/bg3"),
    playdate.sound.sample.new("music/bg4"),
    playdate.sound.sample.new("music/bg5")
}
local loseMusic <const> = playdate.sound.sample.new("music/lose")
local currMusic = snd.new(loseMusic)

local MIC_LEVEL_TARGET <const> = 0.25 -- 0..1
local CRANK_TARGET <const> = 2*360
local CRANK_DEADZONE_NORMAL <const> = 45
local CRANK_DEADZONE_AFTER_CRANKED <const> = 360
local TILT_TARGET <const> = math.cos(75 * DEG_TO_RAD)
local SPEED_UP_INTERVAL <const> = 10
local MAX_SPEED_LEVEL <const> = 5
local TRANSITION_TIME_MS <const> = 500

local saveData = {
    highscore = 0,
    musicOn = true,
    debugOn = false
}

local font = gfx.font.new("images/font/whiteglove-stroked")
local soundSuccess = snd.new("sounds/success")
local soundLose = snd.new("sounds/lose")

local updateFnc = nil
local reactToGlobalEvents = false

------ UTILITY

local function vec3D_len(x, y, z)
    return math.sqrt(x*x + y*y + z*z)
end

local function vec3D_norm(x, y, z)
    local len = vec3D_len(x, y, z)
    return x/len, y/len, z/len
end

-- assumes v1 is a normalized 3D-vector stored as a table with 3 entries: {[1] = x, [2] = y, [3] = z}
local function vec3D_dot(v1, x2, y2, z2)
    return ((v1[1] * x2 + v1[2] * y2 + v1[3] * z2) / vec3D_len(x2, y2, z2))
end

local function loadSettings()
    local loadData = playdate.datastore.read()

    if (loadData == nil) then return end

    saveData = loadData
    if (saveData.musicOn) then
        currMusic:setVolume(1.0)
    else
        currMusic:setVolume(0)
    end
end

local function getValidActionCode()
    local result = 0
    repeat
        if (playdate.isCrankDocked()) then
            result = math.random(1, actionCodes.CRANK_UNDOCK)
        else
            result = math.random(1, actionCodes.EOL - 1)
        end
    -- exclude UNDOCK action when crank is undocked
    -- exclude MICROPHONE action on simulator
    until ((playdate.isCrankDocked() or result ~= actionCodes.CRANK_UNDOCK) 
            and (not playdate.isSimulator or result ~= actionCodes.MICROPHONE))

    return result
end

local function update_none()
    --
end

------ GAME (MAIN)

local currAction = actionCodes.LOSE
local actionDone = (currAction == nil)
local actionTransitionState = -1 -- -1 not started, 0 running, 1 done
local actionTimer = nil
local actionTransitionTimer = nil
local speedLevel = 1
local score = 0

local crankValue = 0
local crankDeadzone = CRANK_DEADZONE_NORMAL
local startVec = nil

local lastAnimationFrame = 1

local update_main

local function startGame()
    score = 0
    speedLevel = 1
    actionDone = (currAction == actionCodes.LOSE)
    actionTransitionState = (currAction == actionCodes.LOSE) and 1 or -1
    currMusic:stop()
    currMusic:setSample(bgMusic[1])
    currMusic:play(0)
end

local buttonHandlers_mainLose = {
    AButtonDown = function()
        playdate.inputHandlers.pop()
        updateFnc = update_main
        startGame()
    end
}

local function actionSuccess_main()
    if (actionDone) then return end

    actionDone = true
    score += 1
    soundSuccess:play(1)
end

local function actionFail_main()
    if (currAction == actionCodes.LOSE) then return end

    if (score > saveData.highscore) then
        saveData.highscore = score
        playdate.datastore.write(saveData)
    end
    currAction = actionCodes.LOSE
    actionTimer:pause()
    playdate.graphics.sprite.redrawBackground()
    gfx.sprite.update()
    soundLose:play(1)
    currMusic:stop()
    currMusic:setSample(loseMusic)
    currMusic:play(0)
    playdate.inputHandlers.push(buttonHandlers_mainLose)
    updateFnc = update_none
end

local function actionTimerEnd()
    if (currAction == actionCodes.PASS_PLAYER) then
        actionDone = true
        return
    elseif (currAction == actionCodes.SPEED_UP) then
        actionDone = true
        return
    end

    actionFail_main()
end

local function actionTransitionEnd()
    actionTransitionState = 1
end

local actionSuccesFnc = nil
local actionFailFnc = nil
local buttonHandlers_main = {
    upButtonDown = function()
        if (currAction == actionCodes.DIRECTION) then
            actionSuccesFnc()
        else
            actionFailFnc()
        end
    end,

    rightButtonDown = function()
        if (currAction == actionCodes.DIRECTION) then
            actionSuccesFnc()
        else
            actionFailFnc()
        end
    end,

    downButtonDown = function()
        if (currAction == actionCodes.DIRECTION) then
            actionSuccesFnc()
        else
            actionFailFnc()
        end
    end,

    leftButtonDown = function()
        if (currAction == actionCodes.DIRECTION) then
            actionSuccesFnc()
        else
            actionFailFnc()
        end
    end,

    AButtonDown = function()
        if (currAction == actionCodes.BUTTON) then
            actionSuccesFnc()
        else
            actionFailFnc()
        end
    end,

    BButtonDown = function()
        if (currAction == actionCodes.BUTTON) then
            actionSuccesFnc()
        else
            actionFailFnc()
        end
    end,

    crankDocked = function()
        if (currAction == actionCodes.CRANK_DOCK) then
            actionSuccesFnc()
        else
            actionFailFnc()
        end
    end,

    crankUndocked = function()
        if (currAction == actionCodes.CRANK_UNDOCK) then
            actionSuccesFnc()
        else
            actionFailFnc()
        end
    end,

    cranked = function(change, acceleratedChange)
        -- Ignore when docking, since crank may need to be moved to do so
        if (currAction == actionCodes.CRANK_DOCK) then return end

        crankValue += math.abs(change)
        if (currAction == actionCodes.CRANKED and crankValue >= CRANK_TARGET) then
            actionSuccesFnc()
        elseif (currAction ~= actionCodes.CRANKED and crankValue >= crankDeadzone) then
            actionFailFnc()
        end
    end
}

local function render_main()
    if (actions[currAction].ani ~= nil and lastAnimationFrame ~= actions[currAction].img.frame) then
        lastAnimationFrame = actions[currAction].img.frame
        playdate.graphics.sprite.redrawBackground()
    end

    gfx.sprite.update()

    if (not actionDone) then
        gfx.fillRect(0, screen.getHeight() - 20, screen.getWidth() * actionTimer.timeLeft / actionTimer.duration, 20)
    elseif (actionTransitionState >= 0) then
        local w = screen.getWidth() * actionTimer.timeLeft / actionTimer.duration
        w = w + (screen.getWidth() - w) * (1 - actionTransitionTimer.timeLeft / actionTransitionTimer.duration)
        gfx.fillRect(0, screen.getHeight() - 20, w, 20)
    end

    gfx.setFont(font)

    gfx.drawText('score: '..score, 80, 224)
    gfx.drawText("HIGH: "..saveData.highscore, 240, 224)

    if (saveData.debugOn) then
        local yPos = 2
        if (currAction == actionCodes.MICROPHONE) then
            gfx.drawText(string.format("level: %.0f", mic.getLevel() * 100), 2, yPos)
            yPos += 25
        elseif (currAction == actionCodes.TILT) then
            gfx.drawText(string.format("val: %.2f %.2f %.2f", playdate.readAccelerometer()), 2, yPos);
            gfx.drawText(string.format("a3d: %.2f", math.acos(vec3D_dot(startVec, playdate.readAccelerometer())) * RAD_TO_DEG), 2, yPos + 15)
            gfx.drawText(string.format("cos: %.4f", vec3D_dot(startVec, playdate.readAccelerometer())), 2, yPos + 30)
            gfx.drawText(string.format("target: %.4f", TILT_TARGET), 2, yPos + 45)
            yPos += 70
        end
        gfx.drawText(string.format("timer: %d", actionTimer.timeLeft), 2, yPos);
    end
end

update_main = function ()
    playdate.timer.updateTimers()

    if (currAction == actionCodes.MICROPHONE and mic.getLevel() >= MIC_LEVEL_TARGET) then
        actionSuccess_main()
    end

    if (currAction == actionCodes.TILT) then
        local cos_ang = vec3D_dot(startVec, playdate.readAccelerometer())
        if (cos_ang <= TILT_TARGET) then
            actionSuccess_main()
        end
    end
    -- other actions are handled in callbacks

    if (actionDone and actionTransitionState == -1) then
        actionTransitionTimer:reset()
        actionTransitionTimer:start()
        actionTimer:pause()
        actionTransitionState = 0
    end
    if (actionDone and actionTransitionState == 1) then
        local lastAction = currAction
        if (speedLevel < MAX_SPEED_LEVEL and score == SPEED_UP_INTERVAL * speedLevel) then
            currAction = actionCodes.SPEED_UP
            speedLevel += 1

            currMusic:stop()
            currMusic:setSample(bgMusic[speedLevel])
            currMusic:play(0)
        else
            while (currAction == lastAction) do
                currAction = getValidActionCode()
            end
        end

        -- increase deadzone after CRANKED action, so turning the crank
        -- a bit too far does not immediately fail the player
        if (lastAction == actionCodes.CRANKED) then
            crankDeadzone = CRANK_DEADZONE_AFTER_CRANKED
        else
            crankDeadzone = CRANK_DEADZONE_NORMAL
        end

        if (currAction == actionCodes.MICROPHONE) then
            mic.startListening()
        else
            mic.stopListening()
        end

        if (currAction == actionCodes.TILT) then
            startVec = { vec3D_norm(playdate.readAccelerometer()) }
            -- print("TILT START")
            -- print(string.format("Angles: %.2f %.2f %.2f", playdate.readAccelerometer()))
            -- print(string.format("Norm: %.2f %.2f %.2f", startVec[1], startVec[2], startVec[3]))
        end

        lastAnimationFrame = 1
        if (actions[currAction].ani ~= nil) then
            actions[currAction].img.frame = 1
        end
        playdate.graphics.sprite.redrawBackground()
        actions[currAction].snd:play(1)

        -- always reset crank value, because it is checked for succeed and fail
        crankValue = 0

        actionDone = false
        actionTransitionState = -1
        actionTimer.duration = actions[currAction].time[speedLevel]
        actionTimer:reset()
        actionTimer:start()
    end

    render_main()
end

local function setup_main()
    gfx.sprite.setBackgroundDrawingCallback(
        function( x, y, width, height )
            -- x,y,width,height is the updated area in sprite-local coordinates
            -- The clip rect is already set to this area, so we don't need to set it ourselves
            actions[currAction].img:draw(0,0)
        end
    )

    playdate.startAccelerometer()

    actionTimer = playdate.timer.new(actions[currAction].time[speedLevel], actionTimerEnd)
    actionTimer.discardOnCompletion = false
    actionTransitionTimer = playdate.timer.new(TRANSITION_TIME_MS, actionTransitionEnd)
    actionTransitionTimer.discardOnCompletion = false
    actionTransitionTimer:pause()

    playdate.inputHandlers.push(buttonHandlers_main)

    updateFnc = update_main
    actionSuccesFnc = actionSuccess_main
    actionFailFnc = actionFail_main
    reactToGlobalEvents = true

    startGame()
end

local function cleanup_main()
    gfx.sprite.setBackgroundDrawingCallback(nil)
    playdate.stopAccelerometer()
    playdate.stopListening()
    actionTimer:remove()
    currMusic:stop()
    playdate.inputHandlers.pop()
end

------ TITLE SCREEN

local currTitleCard = 1

local function drawTitleCard(index)
    local backgroundImage = nil
    if index == 1 then
        backgroundImage = gfx.image.new("images/remove_cover")
    else
        backgroundImage = gfx.image.new("images/title")
    end
    assert(backgroundImage)

    backgroundImage:draw(0,0)
end

local function setupMenuItems()
    local menu = playdate.getSystemMenu()

    local musicMenuItem, _ = menu:addCheckmarkMenuItem("Music", saveData.musicOn, function(value)
        saveData.musicOn = value
        playdate.datastore.write(saveData)
        if (saveData.musicOn) then
            currMusic:setVolume(1.0)
        else
            currMusic:setVolume(0)
        end
    end)

    local resetScoreMenuItem, _ = menu:addMenuItem("Reset Score", function()
        saveData.highscore = 0
        playdate.datastore.write(saveData)
    end)

    local debugMenuItem, _ = menu:addCheckmarkMenuItem("Debug Text", saveData.debugOn, function(value)
        saveData.debugOn = value
        playdate.datastore.write(saveData)
    end)
end

local function cleanup_title()
    playdate.inputHandlers.pop()
end

local buttonHandlers_title = {
    AButtonDown = function()
        if currTitleCard == 1 then
            currTitleCard += 1
            drawTitleCard(currTitleCard)

            gfx.setFont(font)
            gfx.drawText("HIGHSCORE: "..saveData.highscore, 78, 200)
        else
            cleanup_title()
            setup_main()
        end
    end
}

local function setup_title()
    loadSettings()
    setupMenuItems()
    playdate.inputHandlers.push(buttonHandlers_title)
    drawTitleCard(currTitleCard)
    updateFnc = update_none
    reactToGlobalEvents = false
end

------ CALLBACKS

function playdate.update()
    updateFnc()
end

function playdate.deviceWillLock()
    if (not reactToGlobalEvents) then return end

    actionFailFnc()
end

function playdate.gameWillResume()
    if (not reactToGlobalEvents) then return end

    actionFailFnc()
end

------ MAIN

math.randomseed(playdate.getSecondsSinceEpoch())
playdate.setCrankSoundsDisabled(true)
setup_title()
updateFnc = update_none