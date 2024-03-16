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
-- [X] game mode: simon cranks (solo, you get a sequence and have to do it afterwards)
-- [ ] game mode: crank the bomb (party, you do an action as fast as possible then pass, bomb explodes after random time)
-- [X] background animations for actions
-- [X] sound for actions
-- [X] background music
-- [X] save highscore values
-- [X] title card (350 x 155), card animation and icon (32 x 32)
-- [X] Other neccessary pdxinfo data: https://sdk.play.date/2.0.3/Inside%20Playdate.html#pdxinfo
-- [ ] options to disable accelerometer and mic based actions
-- [x] Better score and highscore display
-- [X] main menu - do not start the game immediately
-- [X] add title card recommending to play without the cover (https://devforum.play.date/t/crank-docking-not-registered/10439)
-- [ ] sound convert script: add option to convert single file if passed path is a file
-- [X] go to main menu option in menu
-- [ ] short transition/swipe/... between actions in simon mode -> helps split same actions when playing without sound
-- [ ] Check color table: needs inverted (compared to b/w), need raw b/w version?, correct colors compared to screenshot/video?
-- [ ] Add credits to splash screen
-- [ ] Add transition sound effects


import "CoreLibs/object"
import "CoreLibs/graphics"
import "CoreLibs/sprites"
import "CoreLibs/timer"
import "CoreLibs/animation"

import "game_constants"
import "transition"
import "savegame"
import "menu"

local gfx <const> = playdate.graphics
local mic <const> = playdate.sound.micinput
local snd <const> = playdate.sound.sampleplayer
local sample <const> = playdate.sound.sample

local RAD_TO_DEG <const> = 180 / math.pi
local DEG_TO_RAD <const> = math.pi / 180
local SCREEN_WIDTH <const> = playdate.display.getWidth()
local SCREEN_HEIGHT <const> = playdate.display.getHeight()

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
    sample.new("music/bg1"),
    sample.new("music/bg2"),
    sample.new("music/bg3"),
    sample.new("music/bg4"),
    sample.new("music/bg5")
}
local loseMusic <const> = sample.new("music/lose")
local currMusic = snd.new(loseMusic)
local bgSprite = nil

local MIC_LEVEL_TARGET <const> = 0.25 -- 0..1
local CRANK_TARGET <const> = 2*360
local CRANK_DEADZONE_NORMAL <const> = 45
local CRANK_DEADZONE_AFTER_CRANKED <const> = 360
local TILT_TARGET <const> = math.cos(75 * DEG_TO_RAD)
local SPEED_UP_INTERVAL <const> = 10
local MAX_SPEED_LEVEL <const> = 5
local TRANSITION_TIME_MS <const> = 500


local font = gfx.font.new("images/font/party")
gfx.setFont(font)
local soundSuccess = snd.new("sounds/success")
local soundLose = snd.new("sounds/lose")

-- "Gloabal" state
local currAction
local lastAnimationFrame = 1
local crankValue = 0
local crankDeadzone = CRANK_DEADZONE_NORMAL
local startVec = nil
Statemachine = {
    update = nil,
    cleanup = nil, -- needed for going back to main menu through system menu
    gameShouldFailAfterResume = false
}

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

local function renderDebugInfo(yPosStart)
    local yPos = yPosStart or 2
    if (currAction == ACTION_CODES.MICROPHONE) then
        gfx.drawText(string.format("level: %.0f", mic.getLevel() * 100), 2, yPos)
        yPos = yPos + 25
    elseif (currAction == ACTION_CODES.TILT) then
        gfx.drawText(string.format("val: %.2f %.2f %.2f", playdate.readAccelerometer()), 2, yPos);
        gfx.drawText(string.format("a3d: %.2f", math.acos(vec3D_dot(startVec, playdate.readAccelerometer())) * RAD_TO_DEG), 2, yPos + 15)
        gfx.drawText(string.format("cos: %.4f", vec3D_dot(startVec, playdate.readAccelerometer())), 2, yPos + 30)
        gfx.drawText(string.format("target: %.4f", TILT_TARGET), 2, yPos + 45)
        yPos = yPos + 70
    end
    return yPos
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
    -- exclude MICROPHONE action on simulator without microphone input
    until ((crankDocked or result ~= ACTION_CODES.CRANK_UNDOCK)
            and (not playdate.isSimulator or result ~= ACTION_CODES.MICROPHONE)
            and (excludeOption == nil or result ~= excludeOption)
            and (allowPassAction or result ~= ACTION_CODES.PASS_PLAYER))

    return result
end

local function setupActionGameplay(last, curr)
    -- increase deadzone after CRANKED action, so turning the crank
    -- a bit too far does not immediately fail the player
    if (curr == ACTION_CODES.CRANKED or last == ACTION_CODES.CRANKED) then
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
    gfx.sprite.redrawBackground()
    actions[curr].snd:play(1)
end

local function update_none()
    --
end

------ GAME (MAIN)

local actionDone = false
local actionTransitionState = -1 -- -1 not started, 0 running, 1 done
local actionTimer
local actionTransitionTimer
local speedLevel = 1
local score = 0

local update_main

local function main_startGame(skipGenNewAction)
    score = 0
    speedLevel = 1
    Statemachine.gameShouldFailAfterResume = false

    if not skipGenNewAction then
        currAction = getValidActionCode(true)
    end
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

local main_buttonsLose = {
    AButtonDown = function()
        playdate.inputHandlers.pop()
        Statemachine.update = update_main
        main_startGame()
    end
}

local function main_actionSuccess()
    if (actionDone) then return end

    actionDone = true
    score = score + 1
    soundSuccess:play(1)
end

local function main_actionFail()
    if (currAction == ACTION_CODES.LOSE) then return end

    if (score > save.data.highscore[GAME_MODE.CRANKIT]) then
        save.data.highscore[GAME_MODE.CRANKIT] = score
        save.write()
    end
    currAction = ACTION_CODES.LOSE
    actionTimer:pause()
    gfx.sprite.redrawBackground()
    gfx.sprite.update()
    gfx.drawTextAligned('SCORE: '..score, 200, 220, kTextAlignment.center)
    soundLose:play(1)
    currMusic:stop()
    currMusic:setSample(loseMusic)
    currMusic:play(0)
    playdate.inputHandlers.push(main_buttonsLose)
    Statemachine.update = update_none 
end

local actionSuccesFnc = nil
local actionFailFnc = nil
local function actionTimerEnd()
    if (currAction == ACTION_CODES.PASS_PLAYER) then
        actionDone = true
        return
    elseif (currAction == ACTION_CODES.SPEED_UP) then
        actionDone = true
        return
    end

    actionFailFnc()
end

local function actionTransitionEnd()
    actionTransitionState = 1
end

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

        crankValue = crankValue + math.abs(change)
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
        gfx.sprite.redrawBackground()
    end

    gfx.sprite.update()

    gfx.setColor(gfx.kColorBlack)
    if (not actionDone) then
        gfx.fillRect(0, SCREEN_HEIGHT - 22, SCREEN_WIDTH * actionTimer.timeLeft / actionTimer.duration, 22)
    elseif (actionTransitionState >= 0) then
        local w = SCREEN_WIDTH * actionTimer.timeLeft / actionTimer.duration
        w = w + (SCREEN_WIDTH - w) * (1 - actionTransitionTimer.timeLeft / actionTransitionTimer.duration)
        gfx.fillRect(0, SCREEN_HEIGHT - 22, w, 22)
    end

    gfx.setImageDrawMode(gfx.kDrawModeNXOR)

    gfx.drawTextAligned('SCORE: '..score, 110, 220, kTextAlignment.center)
    gfx.drawTextAligned("HIGH: "..save.data.highscore[GAME_MODE.CRANKIT], 290, 220, kTextAlignment.center)

    if (save.data.debugOn) then
        gfx.setFont(gfx.getSystemFont())
        local yPos = renderDebugInfo()
        gfx.drawText(string.format("timer: %d", actionTimer.timeLeft), 2, yPos);
        gfx.setFont(font)
    end

    gfx.setImageDrawMode(gfx.kDrawModeCopy)
end

update_main = function ()
    if (Statemachine.gameShouldFailAfterResume) then
        actionFailFnc()
        Statemachine.gameShouldFailAfterResume = false
        return
    end

    playdate.timer.updateTimers()

    if (currAction == ACTION_CODES.MICROPHONE and mic.getLevel() >= MIC_LEVEL_TARGET) then
        main_actionSuccess()
    end

    if (currAction == ACTION_CODES.TILT) then
        local cos_ang = vec3D_dot(startVec, playdate.readAccelerometer())
        if (cos_ang <= TILT_TARGET) then
            main_actionSuccess()
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
            speedLevel = speedLevel + 1

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

local function cleanup_main()
    if bgSprite then bgSprite:remove() end
    playdate.stopAccelerometer()
    mic.stopListening()
    actionTimer:remove()
    actionTransitionTimer:remove()
    currMusic:stop()
    -- pop twice to remove temp input handler from game over screen
    playdate.inputHandlers.pop()
    playdate.inputHandlers.pop()
end

local function setup_main()
    bgSprite = gfx.sprite.setBackgroundDrawingCallback(
        function( x, y, width, height )
            -- x,y,width,height is the updated area in sprite-local coordinates
            -- The clip rect is already set to this area, so we don't need to set it ourselves
            actions[currAction].img:draw(0,0)
        end
    )

    playdate.startAccelerometer()
    playdate.inputHandlers.push(buttonHandlers_main)

    actionTimer = playdate.timer.new(100, actionTimerEnd) -- dummy duration, proper value set in main_startGame
    actionTimer.discardOnCompletion = false
    actionTransitionTimer = playdate.timer.new(TRANSITION_TIME_MS, actionTransitionEnd)
    actionTransitionTimer.discardOnCompletion = false
    actionTransitionTimer:pause()

    Statemachine.update = update_main
    Statemachine.cleanup = cleanup_main
    actionSuccesFnc = main_actionSuccess
    actionFailFnc = main_actionFail
    Statemachine.reactToGlobalEvents = true

    -- NOTE: This assumes pre_setup_main_for_transition was called before
    main_startGame(true)
end

local function render_main_for_transition()
    if actions[currAction].ani ~= nil then
        actions[currAction].img.frame = 1
    end
    actions[currAction].img:draw(0,0)

    gfx.setColor(gfx.kColorBlack)
    gfx.fillRect(0, SCREEN_HEIGHT - 22, SCREEN_WIDTH, 22)

    gfx.setImageDrawMode(gfx.kDrawModeNXOR)
    gfx.drawTextAligned('SCORE: 0', 110, 220, kTextAlignment.center)
    gfx.drawTextAligned("HIGH: "..save.data.highscore[GAME_MODE.CRANKIT], 290, 220, kTextAlignment.center)
    gfx.setImageDrawMode(gfx.kDrawModeCopy)
end

local function pre_setup_main_for_transition()
    currAction = getValidActionCode(true)
end

------ GAME (Simon says)

local SIMON_START_COUNT <const> = 1
local SIMON_TIMER_DURATION_MS <const> = 6500
local SIMON_TIMER_SHOW_MS <const> = 4300
local SIMON_TIMER_SOUND2_MS <const> = 2400
local SIMON_TIMER_SOUND3_MS <const> = 960
local SIMON_TRANSITION_FRAME_MS <const> = 1000
local SIMON_ACTION_BLINK_MS <const> = 150

local SIMON_STATE <const> = {
    SCORE_UP = 1,
    WAIT_FOR_UNDOCK = 2,
    INSTRUCTIONS = 3,
    SHOW = 4,
    ACTION = 5
}

local actionChain = {}
local score_simon = 0
local currIndex = 1
local simonTimer

local simonYourTurnImg = gfx.image.new("images/simon_action")
local simonDockImg = gfx.image.new("images/simon_dock")
local simonScoreImg = gfx.image.new("images/simon_score")
local simonSimonsTurnImg = gfx.image.new("images/simon_show")
local simonState
local simonStateChangeTimer
local simonActionBlinkTimer

local simonTickSlow = sample.new("sounds/tick1")
local simonTickMid = sample.new("sounds/tick2")
local simonTickFast = sample.new("sounds/tick3")
local simonSampleplayer = snd.new(simonTickSlow)
local simonTickState = 1

local update_simon_show
local update_simon_action

local buttonHandlers_simonDockContinue = {
    crankUndocked = function()
        playdate.inputHandlers.pop()
        simonState = SIMON_STATE.INSTRUCTIONS
        simonStateChangeTimer:reset()
        simonStateChangeTimer:start()
        gfx.sprite.redrawBackground()
    end
}

local function startGame_simon()
    score_simon = 0
    currIndex = 1
    Statemachine.gameShouldFailAfterResume = false

    actionChain = {}
    -- do not allow dock action in this set, so we don't have to track dock state
    for i=1, SIMON_START_COUNT do
        table.insert(actionChain, getValidActionCode(false, ACTION_CODES.CRANK_DOCK, false))
    end
    currAction = actionChain[1]
    if (playdate.isCrankDocked()) then
        simonState = SIMON_STATE.WAIT_FOR_UNDOCK
        playdate.inputHandlers.push(buttonHandlers_simonDockContinue, true)
        gfx.sprite.redrawBackground()
    else
        simonState = SIMON_STATE.INSTRUCTIONS
        gfx.sprite.redrawBackground()
        simonStateChangeTimer:reset()
        simonStateChangeTimer:start()
    end
    currMusic:stop()
end

local buttonHandlers_simonLose = {
    AButtonDown = function()
        playdate.inputHandlers.pop()
        Statemachine.update = update_simon_show 
        startGame_simon()
    end
}

local function actionSuccess_simon()
    if (simonState ~= SIMON_STATE.ACTION) then return end

    soundSuccess:play(1)
    simonSampleplayer:stop()
    simonTickState = 1
    simonTimer:reset()
    simonTimer:start()

    if (currIndex < #actionChain) then
        currIndex = currIndex + 1
        currAction = actionChain[currIndex]
        setupActionGameplay(actionChain[currIndex-1], currAction)
    else
        score_simon = score_simon + 1
        simonTimer:pause()
        table.insert(actionChain, getValidActionCode(false))
        Statemachine.update = update_simon_show 
        currIndex = 1
        currAction = actionChain[1]
        simonState = SIMON_STATE.SCORE_UP
        simonStateChangeTimer:reset()
        simonStateChangeTimer:start()
        gfx.sprite.redrawBackground()
        -- stop microphone now, otherwise it is only reset after all actions have been shown
        mic.stopListening()
    end
end

local function actionFail_simon()
    if (currAction == ACTION_CODES.LOSE) then return end

    if (score_simon > save.data.highscore[GAME_MODE.SIMON]) then
        save.data.highscore[GAME_MODE.SIMON] = score_simon
        save.write()
    end
    currAction = ACTION_CODES.LOSE
    gfx.sprite.redrawBackground()
    gfx.sprite.update()
    gfx.drawTextAligned('SCORE: '..score_simon, 200, 220, kTextAlignment.center)
    simonSampleplayer:stop()
    soundLose:play(1)
    currMusic:stop()
    currMusic:setSample(loseMusic)
    currMusic:play(0)
    simonTimer:pause()
    playdate.inputHandlers.push(buttonHandlers_simonLose, true)
    Statemachine.update = update_none 
end

local function simon_changeState()
    if (simonState == SIMON_STATE.SCORE_UP) then
        if (playdate.isCrankDocked()) then
            simonState = SIMON_STATE.WAIT_FOR_UNDOCK
            playdate.inputHandlers.push(buttonHandlers_simonDockContinue, true)
            gfx.sprite.redrawBackground()
        else
            simonState = SIMON_STATE.INSTRUCTIONS
            gfx.sprite.redrawBackground()
            simonStateChangeTimer:reset()
            simonStateChangeTimer:start()
        end
    elseif (simonState == SIMON_STATE.INSTRUCTIONS) then
        simonState = SIMON_STATE.SHOW
        setupActionGfxAndSound(currAction, true)
    end
end

local function render_simon()
    gfx.sprite.update()

    if (simonState ~= SIMON_STATE.ACTION) then
        return;
    end

    gfx.setColor(gfx.kColorBlack)
    if (simonTimer.timeLeft <= SIMON_TIMER_SHOW_MS) then
        local w = SCREEN_WIDTH * simonTimer.timeLeft / SIMON_TIMER_SHOW_MS
        gfx.fillRect(0, SCREEN_HEIGHT - 22, w, 22)
    end

    gfx.setImageDrawMode(gfx.kDrawModeNXOR)
    gfx.drawTextAligned('SCORE: '..score_simon, 200, 220, kTextAlignment.center)

    if (save.data.debugOn) then
        gfx.setFont(gfx.getSystemFont())
        renderDebugInfo()
        gfx.setFont(font)
    end

    gfx.setImageDrawMode(gfx.kDrawModeCopy)
end

local function render_simon_for_transition()
    if (playdate.isCrankDocked()) then
        simonDockImg:draw(0,0)
    else
        simonSimonsTurnImg:draw(0,0)
    end
end

local function simon_showNextAction()
    if (currIndex < #actionChain) then
        currIndex = currIndex + 1
        currAction = actionChain[currIndex]
        setupActionGfxAndSound(currAction, true)
    else
        simonState = SIMON_STATE.ACTION
        Statemachine.update = update_simon_action 
        currIndex = 1
        currAction = actionChain[1]
        setupActionGameplay(0, currAction)
        gfx.sprite.redrawBackground()
        simonTimer:reset()
        simonTimer:start()
        simonTickState = 1
    end
end

update_simon_show = function ()
    if (Statemachine.gameShouldFailAfterResume) then
        actionFailFnc()
        Statemachine.gameShouldFailAfterResume = false
        return
    end

    playdate.timer.updateTimers()

    if (simonState ~= SIMON_STATE.SHOW) then goto render end

    if (actions[currAction].snd:isPlaying()) then goto render end

    if (not simonActionBlinkTimer.paused and simonActionBlinkTimer.timeLeft > 0) then return end

    simonActionBlinkTimer:reset()
    simonActionBlinkTimer:start()
    gfx.clear()
    do return end

    ::render::
    render_simon()
end

update_simon_action = function ()
    if (Statemachine.gameShouldFailAfterResume) then
        actionFailFnc()
        Statemachine.gameShouldFailAfterResume = false
        return
    end

    playdate.timer.updateTimers()

    if (currAction == ACTION_CODES.MICROPHONE and mic.getLevel() >= MIC_LEVEL_TARGET) then
        actionSuccess_simon()
    end

    if (currAction == ACTION_CODES.TILT) then
        local cos_ang = vec3D_dot(startVec, playdate.readAccelerometer())
        if (cos_ang <= TILT_TARGET) then
            actionSuccess_simon()
        end
    end

    if (simonTimer.timeLeft <= SIMON_TIMER_SOUND3_MS and simonTickState == 3) then
        simonSampleplayer:setSample(simonTickFast)
        simonSampleplayer:play(0)
        simonTickState = 4
    elseif (simonTimer.timeLeft <= SIMON_TIMER_SOUND2_MS and simonTickState == 2) then
        simonSampleplayer:setSample(simonTickMid)
        simonSampleplayer:play(0)
        simonTickState = 3
    elseif (simonTimer.timeLeft <= SIMON_TIMER_SHOW_MS and simonTickState == 1) then
        simonSampleplayer:setSample(simonTickSlow)
        simonSampleplayer:play(0)
        simonTickState = 2
    end

    render_simon()
end

local function cleanup_simon()
    if bgSprite then bgSprite:remove() end
    playdate.stopAccelerometer()
    mic.stopListening()
    simonTimer:remove()
    simonStateChangeTimer:remove()
    simonSampleplayer:stop()
    currMusic:stop()
    -- pop twice to remove temp handler from game over or undock request
    playdate.inputHandlers.pop()
    playdate.inputHandlers.pop()
end

local function setup_simon()
    bgSprite = gfx.sprite.setBackgroundDrawingCallback(
        function( x, y, width, height )
            if (simonState == SIMON_STATE.SHOW or currAction == ACTION_CODES.LOSE) then
                actions[currAction].img:draw(0,0)
            elseif (simonState == SIMON_STATE.SCORE_UP) then
                simonScoreImg:draw(0,0)
            elseif (simonState == SIMON_STATE.WAIT_FOR_UNDOCK) then
                simonDockImg:draw(0,0)
            elseif (simonState == SIMON_STATE.INSTRUCTIONS) then
                simonSimonsTurnImg:draw(0,0)
            elseif (simonState == SIMON_STATE.ACTION) then
                simonYourTurnImg:draw(0,0)
            end
        end
    )

    gfx.setColor(gfx.kColorBlack)
    playdate.startAccelerometer()
    playdate.inputHandlers.push(buttonHandlers_main)
    Statemachine.update = update_simon_show 
    Statemachine.cleanup = cleanup_simon
    actionSuccesFnc = actionSuccess_simon
    actionFailFnc = actionFail_simon
    Statemachine.reactToGlobalEvents = true
    simonTimer = playdate.timer.new(SIMON_TIMER_DURATION_MS, actionTimerEnd)
    simonTimer.discardOnCompletion = false
    simonTimer:pause()
    simonStateChangeTimer = playdate.timer.new(SIMON_TRANSITION_FRAME_MS, simon_changeState)
    simonStateChangeTimer.discardOnCompletion = false;
    simonStateChangeTimer:pause()
    simonActionBlinkTimer = playdate.timer.new(SIMON_ACTION_BLINK_MS, simon_showNextAction)
    simonActionBlinkTimer.discardOnCompletion = false;
    simonActionBlinkTimer:pause()

    startGame_simon()
end

------ SPLASH IMAGES and MENU

local buttonHandlers_intro = {
    AButtonDown = function()
        playdate.inputHandlers.pop()
        transition.setup(menu.setup, menu.update)
    end,
    BButtonDown = function()
        playdate.inputHandlers.pop()
        transition.setup(menu.setup, menu.update)
    end
}

local function splash_render()
    gfx.image.new("images/remove_cover"):draw(0,0)
end

local function splash_setup()
    playdate.inputHandlers.push(buttonHandlers_intro)
end

local function menu_result(optionIndex)
    if (optionIndex == GAME_MODE.CRANKIT) then
        pre_setup_main_for_transition()
        transition.setup(setup_main, render_main_for_transition)
    elseif (optionIndex == GAME_MODE.SIMON) then
        transition.setup(setup_simon, render_simon_for_transition)
    end
end

------ CALLBACKS

function playdate.update()
    Statemachine.update()
end

function playdate.deviceWillLock()
    Statemachine.gameShouldFailAfterResume = true
end

-- waiting for the following bug to get fixed:
-- https://devforum.play.date/t/calling-order-after-selecting-menu-item-is-wrong/14493
function playdate.gameWillResume()
    Statemachine.gameShouldFailAfterResume = true
end

------ MAIN

math.randomseed(playdate.getSecondsSinceEpoch())
playdate.setCrankSoundsDisabled(true)

save.load()
if (save.data.musicOn) then
    currMusic:setVolume(1.0)
else
    currMusic:setVolume(0)
end

---- setup playdate menu
local sytemMenu = playdate.getSystemMenu()

local musicMenuItem, _ = sytemMenu:addCheckmarkMenuItem("Music", save.data.musicOn, function(value)
    save.data.musicOn = value
    save.write()
    if (save.data.musicOn) then
        currMusic:setVolume(1.0)
    else
        currMusic:setVolume(0)
    end
end)

local goToMenuItem, _ = sytemMenu:addMenuItem("Main Menu", function()
    if (Statemachine.cleanup ~= nil) then
        Statemachine.cleanup()
    end
    menu.setup()
end)

---- setup our menu
menu.callback = menu_result

gfx.setColor(gfx.kColorWhite)
gfx.clear()
transition.setup_second(splash_setup, splash_render)