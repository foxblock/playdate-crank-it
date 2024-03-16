if crankit then return end  -- avoid loading twice the same module
crankit = {}  -- create a table to represent the module

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

local SPEED_UP_INTERVAL <const> = 10
local MAX_SPEED_LEVEL <const> = 5
local TRANSITION_TIME_MS <const> = 500

local bgMusic <const> = {
    sample.new("music/bg1"),
    sample.new("music/bg2"),
    sample.new("music/bg3"),
    sample.new("music/bg4"),
    sample.new("music/bg5")
}
local loseMusic <const> = sample.new("music/lose")
local soundSuccess = snd.new("sounds/success")
local soundLose = snd.new("sounds/lose")
local bgSprite = nil


local actionDone = false
local actionTransitionState = -1 -- -1 not started, 0 running, 1 done
local actionTimer
local actionTransitionTimer
local speedLevel = 1
local score = 0
local lastAnimationFrame = 1

local update_main


local function update_none()
    --
end

local function main_startGame(skipGenNewAction)
    score = 0
    speedLevel = 1
    Statemachine.gameShouldFailAfterResume = false

    if not skipGenNewAction then
        actions.current = actions.getValidActionCode(true)
    end
    actions.setupActionGameplay(0, actions.current)
    actions.setupActionGfxAndSound(actions.current)
    actionDone = false
    actionTransitionState = -1
    actionTransitionTimer:pause()
    actionTimer.duration = actions.data[actions.current].time[speedLevel]
    actionTimer:reset()
    actionTimer:start()

    Statemachine.music:stop()
    Statemachine.music:setSample(bgMusic[1])
    Statemachine.music:play(0)
end

local main_buttonsLose = {
    AButtonDown = function()
        playdate.inputHandlers.pop()
        playdate.update = update_main
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
    if (actions.current == ACTION_CODES.LOSE) then return end

    if (score > save.data.highscore[GAME_MODE.CRANKIT]) then
        save.data.highscore[GAME_MODE.CRANKIT] = score
        save.write()
    end
    actions.current = ACTION_CODES.LOSE
    actionTimer:pause()
    gfx.sprite.redrawBackground()
    gfx.sprite.update()
    gfx.drawTextAligned('SCORE: '..score, 200, 220, kTextAlignment.center)
    soundLose:play(1)
    Statemachine.music:stop()
    Statemachine.music:setSample(loseMusic)
    Statemachine.music:play(0)
    playdate.inputHandlers.push(main_buttonsLose)
    playdate.update = update_none
end

local function actionTimerEnd()
    if (actions.current == ACTION_CODES.PASS_PLAYER) then
        actionDone = true
        return
    elseif (actions.current == ACTION_CODES.SPEED_UP) then
        actionDone = true
        return
    end

    main_actionFail()
end

local function actionTransitionEnd()
    actionTransitionState = 1
end

local function render_main()
    if (actions.data[actions.current].ani ~= nil and lastAnimationFrame ~= actions.data[actions.current].img.frame) then
        lastAnimationFrame = actions.data[actions.current].img.frame
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

    if (save.data.settings.debugOn) then
        gfx.setFont(gfx.getSystemFont())
        local yPos = actions.renderDebugInfo()
        gfx.drawText(string.format("timer: %d", actionTimer.timeLeft), 2, yPos);
        gfx.setFont(Statemachine.font)
    end

    gfx.setImageDrawMode(gfx.kDrawModeCopy)
end

update_main = function ()
    if (Statemachine.gameShouldFailAfterResume) then
        main_actionFail()
        Statemachine.gameShouldFailAfterResume = false
        return
    end

    playdate.timer.updateTimers()

    local micResult = actions.checkMic()
    if (micResult == 1) then
        main_actionSuccess()
    elseif (micResult == -1) then
        main_actionFail()
    end

    local tiltResult = actions.checkTilt()
    if (tiltResult == 1) then
        main_actionSuccess()
    elseif (tiltResult == -1) then
        main_actionFail()
    end

    -- other actions are handled in callbacks

    if (actionDone and actionTransitionState == -1) then
        actionTransitionTimer:reset()
        actionTransitionTimer:start()
        actionTimer:pause()
        actionTransitionState = 0
    elseif (actionDone and actionTransitionState == 1) then
        local lastAction = actions.current
        if (speedLevel < MAX_SPEED_LEVEL and score == SPEED_UP_INTERVAL * speedLevel) then
            actions.current = ACTION_CODES.SPEED_UP
            speedLevel = speedLevel + 1

            Statemachine.music:stop()
            Statemachine.music:setSample(bgMusic[speedLevel])
            Statemachine.music:play(0)
        else
            actions.current = actions.getValidActionCode(true, lastAction)
        end

        actions.setupActionGameplay(lastAction, actions.current)
        actions.setupActionGfxAndSound(actions.current)
        lastAnimationFrame = 1

        actionDone = false
        actionTransitionState = -1
        actionTimer.duration = actions.data[actions.current].time[speedLevel]
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
    Statemachine.music:stop()
    -- pop twice to remove temp input handler from game over screen
    playdate.inputHandlers.pop()
    playdate.inputHandlers.pop()
end

function crankit.setup()
    bgSprite = gfx.sprite.setBackgroundDrawingCallback(
        function( x, y, width, height )
            -- x,y,width,height is the updated area in sprite-local coordinates
            -- The clip rect is already set to this area, so we don't need to set it ourselves
            actions.data[actions.current].img:draw(0,0)
        end
    )

    -- Accelerometer only returns values on next update cycle after startAccelerometer is called
    -- This is inconvenient for us, since we need to set startVec once tilt action comes up
    -- So we just enable the accelerometer during the whole game
    playdate.startAccelerometer()
    playdate.inputHandlers.push(actions.buttonHandler)

    actionTimer = playdate.timer.new(100, actionTimerEnd) -- dummy duration, proper value set in main_startGame
    actionTimer.discardOnCompletion = false
    actionTransitionTimer = playdate.timer.new(TRANSITION_TIME_MS, actionTransitionEnd)
    actionTransitionTimer.discardOnCompletion = false
    actionTransitionTimer:pause()

    playdate.update = update_main
    Statemachine.cleanup = cleanup_main
    actions.succesFnc = main_actionSuccess
    actions.failFnc = main_actionFail
    Statemachine.reactToGlobalEvents = true

    -- NOTE: This assumes pre_setup_main_for_transition was called before
    main_startGame(true)
end

function crankit.render_for_transition()
    if actions.data[actions.current].ani ~= nil then
        actions.data[actions.current].img.frame = 1
    end
    actions.data[actions.current].img:draw(0,0)

    gfx.setColor(gfx.kColorBlack)
    gfx.fillRect(0, SCREEN_HEIGHT - 22, SCREEN_WIDTH, 22)

    gfx.setImageDrawMode(gfx.kDrawModeNXOR)
    gfx.drawTextAligned('SCORE: 0', 110, 220, kTextAlignment.center)
    gfx.drawTextAligned("HIGH: "..save.data.highscore[GAME_MODE.CRANKIT], 290, 220, kTextAlignment.center)
    gfx.setImageDrawMode(gfx.kDrawModeCopy)
end

function crankit.pre_setup_for_transition()
    actions.current = actions.getValidActionCode(true)
end