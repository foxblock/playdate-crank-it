if bomb then return end  -- avoid loading twice the same module
bomb = {}  -- create a table to represent the module

import "CoreLibs/graphics"
import "CoreLibs/sprites"
import "CoreLibs/timer"
import "CoreLibs/animator"
import "CoreLibs/animation"
import "game_actions"

local gfx <const> = playdate.graphics
local snd <const> = playdate.sound.sampleplayer
local sample <const> = playdate.sound.sample
local mic <const> = playdate.sound.micinput
local easings <const> = playdate.easingFunctions
local ACTION_CODES <const> = actions.codes

local SCREEN_WIDTH <const> = playdate.display.getWidth()
local SCREEN_HEIGHT <const> = playdate.display.getHeight()

local TRANSITION_TIME_MS <const> = 500
local ACTIONS_PER_PASS <const> = 3

local bgMusic <const> = sample.new("music/bg5")
local loseMusic <const> = sample.new("music/lose")
local soundSuccess = snd.new("sounds/success")
local bgSprite = nil

local bombImg = gfx.image.new("images/bomb/bomb")
local thumb = gfx.image.new("images/bomb/thumb")
local fingers = gfx.image.new("images/bomb/fingers")
local fuse = gfx.imagetable.new("images/bomb/fuse")
local sparkAni = gfx.animation.loop.new(100, gfx.imagetable.new("images/bomb/spark"), true)
local pulseAni = nil
local pulseAniParams = {
    [1] = { min = 0.9, max = 1.1, dur = 1000 },
    [2] = { min = 0.85, max = 1.15, dur = 500 },
    [3] = { min = 0.8, max = 1.2, dur = 250 },
}
local offset = {
    [1] = { x = 34, y = 101 },
    [2] = { x = 117, y = 102 },
    [3] = { x = 223, y = 102 },
    [4] = { x = 268, y = 101 },
    [5] = { x = 268, y = 101 },
}
local sparkOffset = {
    [1] = { x = 84, y = -4 },
    [2] = { x = 56, y = 1 },
    [3] = { x = 29, y = 12 },
}
local fingerFlip = {
    [1] = -1,
    [2] = -1,
    [3] = 1,
    [4] = 1,
    [5] = 1,
}


local actionDone = false
local actionTransitionState = -1 -- -1 not started, 0 running, 1 done
local actionTimer
local bombTimer
local actionTransitionTimer
local lastAnimationFrame = 1
local actionPassCounter = 0
local fuseState = 1

local update_main


local function update_none()
    --
end

local function setFuseState(i)
    fuseState = i
    pulseAni = gfx.animator.new(pulseAniParams[i].dur, pulseAniParams[i].min, pulseAniParams[i].max, easings.inOutSine)
    pulseAni.repeatCount = -1
    pulseAni.reverses = true
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
    setFuseState(1)
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
    actions.setupActionGfxAndSound(actions.current)
    gfx.sprite.update()
    Statemachine.music:stop()
    Statemachine.music:setSample(loseMusic)
    Statemachine.music:play(0)
    playdate.inputHandlers.push(main_buttonsLose)
    playdate.update = update_none
end

local function actionTimerEnd()
    if (actions.current == ACTION_CODES.PASS_BOMB) then
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

    if actions.current == ACTION_CODES.PASS_BOMB then
        bombImg:drawRotated(offset[lastAnimationFrame].x + 46, 
            offset[lastAnimationFrame].y + 77, 
            0, 
            2 - pulseAni:currentValue(), 
            pulseAni:currentValue())
        thumb:drawCentered(offset[lastAnimationFrame].x + 46, 
            offset[lastAnimationFrame].y + 77, 
            fingerFlip[lastAnimationFrame] > 0 and gfx.kImageFlippedX or gfx.kImageUnflipped)
        fingers:drawCentered(offset[lastAnimationFrame].x + 46 + 29 * (pulseAni:currentValue() - 1) * fingerFlip[lastAnimationFrame], 
            offset[lastAnimationFrame].y + 77, 
            fingerFlip[lastAnimationFrame] > 0 and gfx.kImageFlippedX or gfx.kImageUnflipped)
        fuse:drawImage(fuseState, offset[lastAnimationFrame].x + 17, 
            offset[lastAnimationFrame].y - 33 * (pulseAni:currentValue() - 1))
        sparkAni:draw(offset[lastAnimationFrame].x + sparkOffset[fuseState].x, 
            offset[lastAnimationFrame].y + sparkOffset[fuseState].y - 33 * (pulseAni:currentValue() - 1))
    end

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

    if fuseState < 2 and bombTimer.timeLeft < bombTimer.duration * 0.5 then
        setFuseState(2)
    elseif fuseState < 3 and bombTimer.timeLeft < bombTimer.duration * 0.1 then
        setFuseState(3)
    end

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
            actions.current = ACTION_CODES.PASS_BOMB
            actionPassCounter = 0
        else
            actions.current = actions.getValidActionCode(false, lastAction)
        end

        actions.setupActionGameplay(lastAction, actions.current)
        actions.setupActionGfxAndSound(actions.current)
        lastAnimationFrame = 1

        actionDone = false
        actionTransitionState = -1
        if actions.current == ACTION_CODES.PASS_BOMB then
            actionTimer.duration = actions.data[ACTION_CODES.PASS_BOMB].time[1]
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