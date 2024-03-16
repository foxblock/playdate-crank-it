if simon then return end  -- avoid loading twice the same module
simon = {}  -- create a table to represent the module

import "CoreLibs/graphics"
import "CoreLibs/sprites"
import "CoreLibs/timer"
import "game_actions"

local gfx <const> = playdate.graphics
local snd <const> = playdate.sound.sampleplayer
local sample <const> = playdate.sound.sample
local mic <const> = playdate.sound.micinput
local ACTION_CODES <const> = actions.codes

local SCREEN_WIDTH <const> = playdate.display.getWidth()
local SCREEN_HEIGHT <const> = playdate.display.getHeight()

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

local loseMusic <const> = sample.new("music/lose")
local soundSuccess = snd.new("sounds/success")
local soundLose = snd.new("sounds/lose")
local simonTickSlow = sample.new("sounds/tick1")
local simonTickMid = sample.new("sounds/tick2")
local simonTickFast = sample.new("sounds/tick3")
local simonSampleplayer = snd.new(simonTickSlow)
local simonTickState = 1
local bgSprite = nil

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

local function update_none()
    --
end

local function startGame_simon()
    score_simon = 0
    currIndex = 1
    Statemachine.gameShouldFailAfterResume = false

    actionChain = {}
    -- do not allow dock action in this set, so we don't have to track dock state
    for i=1, SIMON_START_COUNT do
        table.insert(actionChain, actions.getValidActionCode(false, ACTION_CODES.CRANK_DOCK, false))
    end
    actions.current = actionChain[1]
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
    Statemachine.music:stop()
end

local buttonHandlers_simonLose = {
    AButtonDown = function()
        playdate.inputHandlers.pop()
        playdate.update = update_simon_show 
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
        actions.current = actionChain[currIndex]
        actions.setupActionGameplay(actionChain[currIndex-1], actions.current)
    else
        score_simon = score_simon + 1
        simonTimer:pause()
        table.insert(actionChain, actions.getValidActionCode(false))
        playdate.update = update_simon_show 
        currIndex = 1
        actions.current = actionChain[1]
        simonState = SIMON_STATE.SCORE_UP
        simonStateChangeTimer:reset()
        simonStateChangeTimer:start()
        gfx.sprite.redrawBackground()
        -- stop microphone now, otherwise it is only reset after all actions have been shown
        mic.stopListening()
    end
end

local function actionFail_simon()
    if (actions.current == ACTION_CODES.LOSE) then return end

    if (score_simon > save.data.highscore[GAME_MODE.SIMON]) then
        save.data.highscore[GAME_MODE.SIMON] = score_simon
        save.write()
    end
    actions.current = ACTION_CODES.LOSE
    gfx.sprite.redrawBackground()
    gfx.sprite.update()
    gfx.drawTextAligned('SCORE: '..score_simon, 200, 220, kTextAlignment.center)
    simonSampleplayer:stop()
    soundLose:play(1)
    Statemachine.music:stop()
    Statemachine.music:setSample(loseMusic)
    Statemachine.music:play(0)
    simonTimer:pause()
    playdate.inputHandlers.push(buttonHandlers_simonLose, true)
    playdate.update = update_none
end

local function actionTimerEnd()
    actionFail_simon()
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
        actions.setupActionGfxAndSound(actions.current, true)
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
        actions.renderDebugInfo()
        gfx.setFont(Statemachine.font)
    end

    gfx.setImageDrawMode(gfx.kDrawModeCopy)
end

local function simon_showNextAction()
    if (currIndex < #actionChain) then
        currIndex = currIndex + 1
        actions.current = actionChain[currIndex]
        actions.setupActionGfxAndSound(actions.current, true)
    else
        simonState = SIMON_STATE.ACTION
        playdate.update = update_simon_action 
        currIndex = 1
        actions.current = actionChain[1]
        actions.setupActionGameplay(0, actions.current)
        gfx.sprite.redrawBackground()
        simonTimer:reset()
        simonTimer:start()
        simonTickState = 1
    end
end

update_simon_show = function ()
    if (Statemachine.gameShouldFailAfterResume) then
        actionFail_simon()
        Statemachine.gameShouldFailAfterResume = false
        return
    end

    playdate.timer.updateTimers()

    if (simonState ~= SIMON_STATE.SHOW) then goto render end

    if (actions.data[actions.current].snd:isPlaying()) then goto render end

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
        actionFail_simon()
        Statemachine.gameShouldFailAfterResume = false
        return
    end

    playdate.timer.updateTimers()

    local micResult = actions.checkMic()
    if (micResult == 1) then
        actionSuccess_simon()
    elseif (micResult == -1) then
        actionFail_simon()
    end

    local tiltResult = actions.checkTilt()
    if (tiltResult == 1) then
        actionSuccess_simon()
    elseif (tiltResult == -1) then
        actionFail_simon()
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
    Statemachine.music:stop()
    -- pop twice to remove temp handler from game over or undock request
    playdate.inputHandlers.pop()
    playdate.inputHandlers.pop()
end

function simon.setup()
    bgSprite = gfx.sprite.setBackgroundDrawingCallback(
        function( x, y, width, height )
            if (simonState == SIMON_STATE.SHOW or actions.current == ACTION_CODES.LOSE) then
                actions.data[actions.current].img:draw(0,0)
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
    playdate.inputHandlers.push(actions.buttonHandler)
    playdate.update = update_simon_show 
    Statemachine.cleanup = cleanup_simon
    actions.succesFnc = actionSuccess_simon
    actions.failFnc = actionFail_simon
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

function simon.render_for_transition()
    if (playdate.isCrankDocked()) then
        simonDockImg:draw(0,0)
    else
        simonSimonsTurnImg:draw(0,0)
    end
end
