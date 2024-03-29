if bomb then return end  -- avoid loading twice the same module
bomb = {}  -- create a table to represent the module

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

local TRANSITION_TIME_MS <const> = 500
local ACTIONS_PER_PASS <const> = 3

local bgMusic <const> = sample.new("music/bg5")
local loseMusic <const> = sample.new("music/lose")
local soundSuccess = snd.new("sounds/success")
local soundLose = snd.new("sounds/lose")
local bgSprite = nil


local actionDone = false
local actionTransitionState = -1 -- -1 not started, 0 running, 1 done
local actionTimer
local bombTimer
local actionTransitionTimer
local lastAnimationFrame = 1
local actionPassCounter = 0

local update_main


local function update_none()
    --
end

local function main_startGame(skipGenNewAction)
    Statemachine.gameShouldFailAfterResume = false

    if not skipGenNewAction then
        actions.current = actions.getValidActionCode(false)
    end
    actions.setupActionGameplay(0, actions.current)
    actions.setupActionGfxAndSound(actions.current)
    actionDone = false
    actionPassCounter = 0
    actionTransitionState = -1
    if not actionTransitionTimer.paused then actionTransitionTimer:pause() end
    bombTimer.duration = save.data.settings.bombSeconds * math.random(8, 12) * 100
    bombTimer:reset()
    bombTimer:start()
    if not actionTimer.paused then actionTimer:pause() end

    Statemachine.music:stop()
    Statemachine.music:setSample(bgMusic)
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
    actionPassCounter = actionPassCounter + 1
    soundSuccess:play(1)
end

local function main_actionFail()
    if (actions.current == ACTION_CODES.LOSE) then return end

    actions.current = ACTION_CODES.LOSE
    if not actionTimer.paused then actionTimer:pause() end
    if not bombTimer.paused then bombTimer:pause() end
    gfx.sprite.redrawBackground()
    gfx.sprite.update()
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
        actionTransitionState = 1
        bombTimer:start()
        return
    end
    -- should never end down here
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

    gfx.setImageDrawMode(gfx.kDrawModeNXOR)

    if (save.data.settings.debugOn) then
        gfx.setFont(gfx.getSystemFont())
        local yPos = actions.renderDebugInfo()
        gfx.drawText(string.format("bomb: %d", bombTimer.timeLeft), 2, yPos);
        gfx.drawText(string.format("cnt: %d", actionPassCounter), 2, yPos + 15);
        gfx.setFont(Statemachine.font)
    end

    gfx.setImageDrawMode(gfx.kDrawModeCopy)
end

update_main = function ()
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
        if actionPassCounter == ACTIONS_PER_PASS then
            actions.current = ACTION_CODES.PASS_PLAYER
            actionPassCounter = 0
        else
            actions.current = actions.getValidActionCode(false, lastAction)
        end

        actions.setupActionGameplay(lastAction, actions.current)
        actions.setupActionGfxAndSound(actions.current)
        lastAnimationFrame = 1

        actionDone = false
        actionTransitionState = -1
        if actions.current == ACTION_CODES.PASS_PLAYER then
            actionTimer.duration = actions.data[ACTION_CODES.PASS_PLAYER].time[3]
            actionTimer:reset()
            actionTimer:start()
            bombTimer:pause()
        end
    end

    render_main()
end

local function cleanup_main()
    if bgSprite then bgSprite:remove() end
    playdate.stopAccelerometer()
    mic.stopListening()
    actionTimer:remove()
    actionTransitionTimer:remove()
    bombTimer:remove()
    Statemachine.music:stop()
    -- pop twice to remove temp input handler from game over screen
    playdate.inputHandlers.pop()
    playdate.inputHandlers.pop()
end

function bomb.setup()
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
    bombTimer = playdate.timer.new(100, main_actionFail)
    bombTimer.discardOnCompletion = false
    actionTransitionTimer = playdate.timer.new(TRANSITION_TIME_MS, actionTransitionEnd)
    actionTransitionTimer.discardOnCompletion = false
    actionTransitionTimer:pause()

    playdate.update = update_main
    Statemachine.cleanup = cleanup_main
    actions.succesFnc = main_actionSuccess
    actions.failFnc = main_actionFail

    -- NOTE: This assumes pre_setup_main_for_transition was called before
    main_startGame(true)
end

function bomb.render_for_transition()
    if actions.data[actions.current].ani ~= nil then
        actions.data[actions.current].img.frame = 1
    end
    actions.data[actions.current].img:draw(0,0)
end

function bomb.pre_setup_for_transition()
    actions.current = actions.getValidActionCode(false)
end