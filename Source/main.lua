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
-- [ ] sound convert script: add option to convert single file if passed path is a file


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

local ACTION_CODES <const> = {
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
    [ACTION_CODES.LOSE] = {
        msg = "You lose! (Press A to restart)",
        time = timeNormal,
        snd = snd.new("sounds/lose"),
        img = gfx.image.new("images/actions/lose"),
        ani = nil
    },
    [ACTION_CODES.DIRECTION] = {
        msg = "Move it!",
        time = timeFast,
        snd = snd.new("sounds/move"),
        img = nil,
        ani = gfx.imagetable.new("images/actions/move"),
        staticFrame = 2
    },
    [ACTION_CODES.BUTTON] = {
        msg = "Press it!",
        time = timeFast,
        snd = snd.new("sounds/press"),
        img = nil,
        ani = gfx.imagetable.new("images/actions/press"),
        staticFrame = 3,
    },
    [ACTION_CODES.MICROPHONE] = {
        msg = "Shout it!",
        time = timeFast,
        snd = snd.new("sounds/shout"),
        img = gfx.image.new("images/actions/shout"),
        ani = nil
    },
    [ACTION_CODES.TILT] = {
        msg = "Tilt it!",
        time = timeNormal,
        snd = snd.new("sounds/tilt"),
        img = nil,
        ani = gfx.imagetable.new("images/actions/tilt"),
        staticFrame = 2
    },
    [ACTION_CODES.PASS_PLAYER] = {
        msg = "Pass it!",
        time = { 3000, 3000, 2500, 2500, 2000 },
        snd = snd.new("sounds/pass"),
        img = nil,
        ani = gfx.imagetable.new("images/actions/pass"),
        staticFrame = 2
    },
    [ACTION_CODES.CRANK_UNDOCK] = {
        msg = "Undock it!",
        time = timeNormal,
        snd = snd.new("sounds/undock"),
        img = gfx.image.new("images/actions/undock"),
        ani = nil
    },
    [ACTION_CODES.CRANK_DOCK] = {
        msg = "Dock it!",
        time = timeSlow,
        snd = snd.new("sounds/dock"),
        img = gfx.image.new("images/actions/dock"),
        ani = nil
    },
    [ACTION_CODES.CRANKED] = {
        msg = "Crank it!",
        time = timeSlow,
        snd = snd.new("sounds/crank"),
        img = nil,
        ani = gfx.imagetable.new("images/actions/crank"),
        staticFrame = 1
    },
    [ACTION_CODES.SPEED_UP] = {
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

local GAME_MODE <const> = {
    CRANKIT = 1,
    SIMON = 2,
    EOL = 3,
    VERSUS = 99,--not implemented
    BOMB = 100--not implemented
}
local GAME_MODE_STR <const> = {
    "Crank-it!",
    "Simon cranks",
    "Crank-it VERSUS",
    "Crank the bomb"
}

local saveData = {
    SAVE_VERSION = 1,
    highscore = {0,0,0,0},
    musicOn = true,
    debugOn = false
}

local font = gfx.font.new("images/font/whiteglove-stroked")
gfx.setFont(font)
local soundSuccess = snd.new("sounds/success")
local soundLose = snd.new("sounds/lose")

local currAction
local lastAnimationFrame = 1
local crankValue = 0
local crankDeadzone = CRANK_DEADZONE_NORMAL
local startVec = nil
local reactToGlobalEvents = false
local updateFnc = nil

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

    -- convert from old save file
    if (loadData.SAVE_VERSION == nil) then
        saveData.debugOn = loadData.debugOn
        saveData.musicOn = loadData.musicOn
        saveData.highscore[GAME_MODE.CRANKIT] = loadData.highscore
        playdate.datastore.write(saveData)
    else
        saveData = loadData
    end

    if (saveData.musicOn) then
        currMusic:setVolume(1.0)
    else
        currMusic:setVolume(0)
    end
end

local function getValidActionCode(allowPassAction, excludeOption, crankDocked)
    local result = 0
    if (crankDocked == nil) then
        crankDocked = playdate.isCrankDocked()
    end
    repeat
        if (crankDocked) then
            result = math.random(1, ACTION_CODES.CRANK_UNDOCK)
        else
            result = math.random(1, ACTION_CODES.EOL - 1)
        end
    -- exclude UNDOCK action when crank is undocked
    -- exclude MICROPHONE action on simulator with microphone input
    until ((crankDocked or result ~= ACTION_CODES.CRANK_UNDOCK)
            and (not playdate.isSimulator or result ~= ACTION_CODES.MICROPHONE)
            and (excludeOption == nil or result ~= excludeOption)
            and (allowPassAction or result ~= ACTION_CODES.PASS_PLAYER))

    return result
end

local function setupActionGameplay(last, curr)
    -- increase deadzone after CRANKED action, so turning the crank
    -- a bit too far does not immediately fail the player
    if (last == ACTION_CODES.CRANKED) then
        crankDeadzone = CRANK_DEADZONE_AFTER_CRANKED
    else
        crankDeadzone = CRANK_DEADZONE_NORMAL
    end
    -- always reset crank value, because it is checked for succeed and fail
    crankValue = 0

    if (curr == ACTION_CODES.MICROPHONE) then
        mic.startListening()
    else
        mic.stopListening()
    end

    if (curr == ACTION_CODES.TILT) then
        startVec = { vec3D_norm(playdate.readAccelerometer()) }
        -- print("TILT START")
        -- print(string.format("Angles: %.2f %.2f %.2f", playdate.readAccelerometer()))
        -- print(string.format("Norm: %.2f %.2f %.2f", startVec[1], startVec[2], startVec[3]))
    end
end

local function setupActionGfxAndSound(curr, static)
    if (actions[curr].ani ~= nil) then
        actions[curr].img.frame = static and actions[curr].staticFrame or 1
        lastAnimationFrame = 1
    end
    playdate.graphics.sprite.redrawBackground()
    actions[curr].snd:play(1)
end

local function update_none()
    --
end

------ GAME (MAIN)

local actionDone
local actionTransitionState -- -1 not started, 0 running, 1 done
local actionTimer
local actionTransitionTimer
local speedLevel
local score

local update_main

local function startGame()
    score = 0
    speedLevel = 1

    currAction = getValidActionCode(true)
    setupActionGameplay(0, currAction)
    setupActionGfxAndSound(currAction)
    actionDone = false
    actionTransitionState = -1
    actionTransitionTimer:pause()
    actionTimer.duration = actions[currAction].time[speedLevel]
    actionTimer:reset()
    actionTimer:start()

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
    if (currAction == ACTION_CODES.LOSE) then return end

    if (score > saveData.highscore[GAME_MODE.CRANKIT]) then
        saveData.highscore[GAME_MODE.CRANKIT] = score
        playdate.datastore.write(saveData)
    end
    currAction = ACTION_CODES.LOSE
    actionTimer:pause()
    playdate.graphics.sprite.redrawBackground()
    gfx.sprite.update()
    gfx.drawText('score: '..score, 170, 224)
    soundLose:play(1)
    currMusic:stop()
    currMusic:setSample(loseMusic)
    currMusic:play(0)
    playdate.inputHandlers.push(buttonHandlers_mainLose)
    updateFnc = update_none
end

local function actionTimerEnd()
    if (currAction == ACTION_CODES.PASS_PLAYER) then
        actionDone = true
        return
    elseif (currAction == ACTION_CODES.SPEED_UP) then
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
        if (currAction == ACTION_CODES.DIRECTION) then
            actionSuccesFnc()
        else
            actionFailFnc()
        end
    end,

    rightButtonDown = function()
        if (currAction == ACTION_CODES.DIRECTION) then
            actionSuccesFnc()
        else
            actionFailFnc()
        end
    end,

    downButtonDown = function()
        if (currAction == ACTION_CODES.DIRECTION) then
            actionSuccesFnc()
        else
            actionFailFnc()
        end
    end,

    leftButtonDown = function()
        if (currAction == ACTION_CODES.DIRECTION) then
            actionSuccesFnc()
        else
            actionFailFnc()
        end
    end,

    AButtonDown = function()
        if (currAction == ACTION_CODES.BUTTON) then
            actionSuccesFnc()
        else
            actionFailFnc()
        end
    end,

    BButtonDown = function()
        if (currAction == ACTION_CODES.BUTTON) then
            actionSuccesFnc()
        else
            actionFailFnc()
        end
    end,

    crankDocked = function()
        if (currAction == ACTION_CODES.CRANK_DOCK) then
            actionSuccesFnc()
        else
            actionFailFnc()
        end
    end,

    crankUndocked = function()
        if (currAction == ACTION_CODES.CRANK_UNDOCK) then
            actionSuccesFnc()
        else
            actionFailFnc()
        end
    end,

    cranked = function(change, acceleratedChange)
        -- Ignore when docking, since crank may need to be moved to do so
        if (currAction == ACTION_CODES.CRANK_DOCK) then return end

        crankValue += math.abs(change)
        if (currAction == ACTION_CODES.CRANKED and crankValue >= CRANK_TARGET) then
            crankValue = 0
            actionSuccesFnc()
        elseif (currAction ~= ACTION_CODES.CRANKED and crankValue >= crankDeadzone) then
            crankValue = 0
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

    gfx.drawText('score: '..score, 80, 224)
    gfx.drawText("HIGH: "..saveData.highscore[GAME_MODE.CRANKIT], 240, 224)

    if (saveData.debugOn) then
        local yPos = 2
        if (currAction == ACTION_CODES.MICROPHONE) then
            gfx.drawText(string.format("level: %.0f", mic.getLevel() * 100), 2, yPos)
            yPos += 25
        elseif (currAction == ACTION_CODES.TILT) then
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

    if (currAction == ACTION_CODES.MICROPHONE and mic.getLevel() >= MIC_LEVEL_TARGET) then
        actionSuccess_main()
    end

    if (currAction == ACTION_CODES.TILT) then
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
    elseif (actionDone and actionTransitionState == 1) then
        local lastAction = currAction
        if (speedLevel < MAX_SPEED_LEVEL and score == SPEED_UP_INTERVAL * speedLevel) then
            currAction = ACTION_CODES.SPEED_UP
            speedLevel += 1

            currMusic:stop()
            currMusic:setSample(bgMusic[speedLevel])
            currMusic:play(0)
        else
            currAction = getValidActionCode(true, lastAction)
        end

        setupActionGameplay(lastAction, currAction)
        setupActionGfxAndSound(currAction)

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
    gfx.setColor(gfx.kColorBlack)

    playdate.startAccelerometer()
    playdate.inputHandlers.push(buttonHandlers_main)

    actionTimer = playdate.timer.new(100, actionTimerEnd) -- dummy duration, proper value set in startGame
    actionTimer.discardOnCompletion = false
    actionTransitionTimer = playdate.timer.new(TRANSITION_TIME_MS, actionTransitionEnd)
    actionTransitionTimer.discardOnCompletion = false
    actionTransitionTimer:pause()

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
    actionTransitionTimer:remove()
    currMusic:stop()
    playdate.inputHandlers.pop()
end

------ GAME (Simon says)

local SIMON_START_COUNT <const> = 1

local actionChain = {}
local score_simon = 0
local currIndex = 1
local simonsTurn = true
local simonWaitForUndock = false
local simonYourTurnImg = gfx.image.new("images/simon")
local simonDockImg = gfx.image.new("images/simon_dock")

local update_simon_show
local update_simon_action

local buttonHandlers_simonDockContinue = {
    crankUndocked = function()
        playdate.inputHandlers.pop()
        simonWaitForUndock = false
        setupActionGfxAndSound(currAction, true)
    end
}

local function startGame_simon()
    score_simon = 0
    currIndex = 1
    simonsTurn = true

    actionChain = {}
    -- do not allow dock action in this set, so we don't have to track dock state
    for i=1, SIMON_START_COUNT do
        table.insert(actionChain, getValidActionCode(false, ACTION_CODES.CRANK_DOCK, false))
    end
    currAction = actionChain[1]
    if (playdate.isCrankDocked()) then
        simonWaitForUndock = true
        playdate.inputHandlers.push(buttonHandlers_simonDockContinue)
        playdate.graphics.sprite.redrawBackground()
    else
        setupActionGfxAndSound(currAction, true)
    end

    currMusic:stop()
end

local buttonHandlers_simonLose = {
    AButtonDown = function()
        playdate.inputHandlers.pop()
        updateFnc = update_simon_show
        startGame_simon()
    end
}

local function actionSuccess_simon()
    if (simonsTurn) then return end

    soundSuccess:play(1)

    if (currIndex < #actionChain) then
        currIndex += 1
        currAction = actionChain[currIndex]
        setupActionGameplay(actionChain[currIndex-1], currAction)
    else
        score_simon += 1
        table.insert(actionChain, getValidActionCode(false))
        simonsTurn = true
        updateFnc = update_simon_show
        currIndex = 1
        currAction = actionChain[1]
        if (playdate.isCrankDocked()) then
            simonWaitForUndock = true
            playdate.inputHandlers.push(buttonHandlers_simonDockContinue)
            playdate.graphics.sprite.redrawBackground()
        else
            setupActionGfxAndSound(currAction, true)
        end
    end
end

local function actionFail_simon()
    if (currAction == ACTION_CODES.LOSE) then return end

    if (score_simon > saveData.highscore[GAME_MODE.SIMON]) then
        saveData.highscore[GAME_MODE.SIMON] = score_simon
        playdate.datastore.write(saveData)
    end
    currAction = ACTION_CODES.LOSE
    playdate.graphics.sprite.redrawBackground()
    gfx.sprite.update()
    gfx.drawText('score: '..score_simon, 170, 224)
    soundLose:play(1)
    currMusic:stop()
    currMusic:setSample(loseMusic)
    currMusic:play(0)
    playdate.inputHandlers.push(buttonHandlers_simonLose)
    updateFnc = update_none
end

local function render_simon()
    gfx.sprite.update()

    gfx.drawText('score: '..score_simon, 170, 224)

    if (saveData.debugOn and not simonsTurn) then
        local yPos = 2
        if (currAction == ACTION_CODES.MICROPHONE) then
            gfx.drawText(string.format("level: %.0f", mic.getLevel() * 100), 2, yPos)
            yPos += 25
        elseif (currAction == ACTION_CODES.TILT) then
            gfx.drawText(string.format("val: %.2f %.2f %.2f", playdate.readAccelerometer()), 2, yPos);
            gfx.drawText(string.format("a3d: %.2f", math.acos(vec3D_dot(startVec, playdate.readAccelerometer())) * RAD_TO_DEG), 2, yPos + 15)
            gfx.drawText(string.format("cos: %.4f", vec3D_dot(startVec, playdate.readAccelerometer())), 2, yPos + 30)
            gfx.drawText(string.format("target: %.4f", TILT_TARGET), 2, yPos + 45)
            yPos += 70
        end
    end
end

update_simon_show = function ()
    if (simonWaitForUndock) then goto render end

    if (actions[currAction].snd:isPlaying()) then goto render end

    if (currIndex < #actionChain) then
        currIndex += 1
        currAction = actionChain[currIndex]
        setupActionGfxAndSound(currAction, true)
    else
        simonsTurn = false
        updateFnc = update_simon_action
        currIndex = 1
        currAction = actionChain[1]
        setupActionGameplay(0, currAction)
        playdate.graphics.sprite.redrawBackground()
    end

    ::render::
    render_simon()
end

update_simon_action = function ()
    if (currAction == ACTION_CODES.MICROPHONE and mic.getLevel() >= MIC_LEVEL_TARGET) then
        actionSuccess_simon()
    end

    if (currAction == ACTION_CODES.TILT) then
        local cos_ang = vec3D_dot(startVec, playdate.readAccelerometer())
        if (cos_ang <= TILT_TARGET) then
            actionSuccess_simon()
        end
    end

    render_simon()
end

local function setup_simon()
    gfx.sprite.setBackgroundDrawingCallback(
        function( x, y, width, height )
            if (simonWaitForUndock) then
                simonDockImg:draw(0,0)
            elseif (simonsTurn or currAction == ACTION_CODES.LOSE) then
                actions[currAction].img:draw(0,0)
            else
                simonYourTurnImg:draw(0,0)
            end
        end
    )

    playdate.startAccelerometer()
    playdate.inputHandlers.push(buttonHandlers_main)
    updateFnc = update_simon_show
    actionSuccesFnc = actionSuccess_simon
    actionFailFnc = actionFail_simon
    reactToGlobalEvents = true

    startGame_simon()
end

------ TITLE SCREEN

local currTitleCard = 1
local selectedGame = 1

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
        for i=1, #saveData.highscore do
            saveData.highscore[i] = 0
        end
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
    leftButtonDown = function ()
        if (selectedGame == 1) then
            selectedGame = GAME_MODE.EOL - 1
        else
            selectedGame -= 1
        end
        gfx.fillRect(78, 190, 170, 40)
        gfx.drawText("MODE: < "..GAME_MODE_STR[selectedGame].." >", 78, 190)
        gfx.drawText("HIGHSCORE: "..saveData.highscore[selectedGame], 78, 210)
    end,

    rightButtonDown = function ()
        if (selectedGame == GAME_MODE.EOL - 1) then
            selectedGame = 1
        else
            selectedGame += 1
        end
        gfx.fillRect(78, 190, 170, 40)
        gfx.drawText("MODE: < "..GAME_MODE_STR[selectedGame].." >", 78, 190)
        gfx.drawText("HIGHSCORE: "..saveData.highscore[selectedGame], 78, 210)
    end,

    AButtonDown = function()
        if currTitleCard == 1 then
            currTitleCard += 1
            drawTitleCard(currTitleCard)

            gfx.drawText("MODE: < "..GAME_MODE_STR[selectedGame].." >", 78, 190)
            gfx.drawText("HIGHSCORE: "..saveData.highscore[selectedGame], 78, 210)
        else
            cleanup_title()
            if (selectedGame == GAME_MODE.CRANKIT) then
                setup_main()
            elseif (selectedGame == GAME_MODE.SIMON) then
                setup_simon()
            end 
        end
    end
}

local function setup_title()
    loadSettings()
    setupMenuItems()
    playdate.inputHandlers.push(buttonHandlers_title)
    gfx.setColor(gfx.kColorWhite)
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