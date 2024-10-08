if bomb then return end  -- avoid loading twice the same module
bomb = {}  -- create a table to represent the module

import "CoreLibs/graphics"
import "CoreLibs/sprites"
import "CoreLibs/timer"
import "CoreLibs/animator"
import "CoreLibs/animation"
import "game_actions"
import "savegame"

local gfx <const> = playdate.graphics
local snd <const> = playdate.sound.sampleplayer
local sample <const> = playdate.sound.sample
local mp3 <const> = playdate.sound.fileplayer
local mic <const> = playdate.sound.micinput
local easings <const> = playdate.easingFunctions
local ACTION_CODES <const> = actions.codes

local bgMusic <const> = {
    sample.new("sounds/tick1"),
    sample.new("sounds/tick2"),
    sample.new("sounds/tick3"),
}
local loseMusic <const> = mp3.new("music/lose_bomb")
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

local explodeImg = gfx.imagetable.new("images/bomb/explode")
local explodeAni = gfx.animator.new(300, 1.1, 2.9)
explodeAni.repeatCount = 4
local lastExplodeFrame = 1

local actionDone = false
local actionTimer
local bombTimer
local bombHalfTime
local bombFinalTime
local lastAnimationFrame = 1
local actionPassCounter = 0
local fuseState = 1
local shownFuseState = 1
local failReasonText = ""

local update_main


local function update_none()
    --
end

local function update_bomb_fail()
    if explodeAni:ended() then
        gfx.sprite.update()
        save.renderModifierIcons()
        playdate.update = update_none
        return
    end

    local curFrame = math.floor(explodeAni:currentValue())
    if curFrame ~= lastExplodeFrame then
        gfx.sprite.update()
        save.renderModifierIcons()
        explodeImg:drawImage(curFrame, 1, 7)
        lastExplodeFrame = curFrame
    end
end

local function clamp(val, min, max)
    if val < min then
        return min
    elseif val > max then
        return max
    end
    return val
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
        actions.current = actions.getValidActionCode()
    end
    actions.setupActionGameplay(0, actions.current)
    actions.setupActionGfxAndSound(actions.current)
    actionDone = false
    actionPassCounter = 0
    if save.data.settings.bombSeconds < 0 then
        bombTimer.duration = math.random(30000, 60000)
    elseif save.data.settings.bombSeconds == 0 then
        bombTimer.duration = math.random(15000, 30000)
    else
        -- time plus/minus 20%
        bombTimer.duration = save.data.settings.bombSeconds * math.random(8, 12) * 100
    end
    bombHalfTime = clamp(bombTimer.duration * 0.5, 6000, 15000)
    bombFinalTime = clamp(bombTimer.duration * 0.1, 3000, 7500)
    bombTimer:start()
    bombTimer:reset()
    setFuseState(1)
    shownFuseState = 1
    if not actionTimer.paused then actionTimer:pause() end

    Statemachine.playWAV(bgMusic[shownFuseState])
end

local main_buttonsLose = {
    AButtonDown = function()
        playdate.inputHandlers.pop()
        playdate.update = update_main
        main_startGame()
    end,
    BButtonDown = function()
        gfx.setColor(gfx.kColorWhite)
        gfx.fillRect(171, 38, 209, 90)
        gfx.drawTextAligned(failReasonText, 275, 50, kTextAlignment.center)
    end,
}

local function main_actionSuccess()
    if (actionDone) then return end

    actionDone = true
    actionPassCounter = actionPassCounter + 1
    soundSuccess:play(1)
end

local function main_actionFail(failReason)
    if (actions.current == ACTION_CODES.LOSE_BOMB) then return end

    actions.current = ACTION_CODES.LOSE_BOMB
    if not actionTimer.paused then actionTimer:pause() end
    if not bombTimer.paused then bombTimer:pause() end
    actions.setupActionGfxAndSound(actions.current)
    gfx.sprite.update()
    Statemachine.playMP3(loseMusic)
    playdate.inputHandlers.push(main_buttonsLose)
    playdate.update = update_bomb_fail
    explodeAni:reset()
    lastExplodeFrame = 0
    mic.stopListening()
    if failReason ~= nil then
        failReasonText = failReason
    else
        failReasonText = "BUTTERFLIES,\nQUANTUM EFFECTS,\nOR SOMETHING"
    end
end

local function actionTimerEnd()
    if (actions.current == ACTION_CODES.PASS_BOMB) then
        actionDone = true
        bombTimer:start()
        return
    end
    -- should never end down here
    main_actionFail("WHAT HAPPENED?\nI WAS NOT\nPAYING ATTENTION")
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

    if fuseState < 2 and bombTimer.timeLeft < bombHalfTime then
        setFuseState(2)
    elseif fuseState < 3 and bombTimer.timeLeft < bombFinalTime then
        setFuseState(3)
    end

    local micResult = actions.checkMic()
    if (micResult == 1) then
        main_actionSuccess()
    elseif (micResult == -1) then
        main_actionFail("YOU WERE\nNOT QUIET\nENOUGH")
    end

    local tiltResult = actions.checkTilt()
    if (tiltResult == 1) then
        main_actionSuccess()
    elseif (tiltResult == -1) then
        main_actionFail("YOU SHOOK\nTHE PLAYDATE\nTOO MUCH")
    end

    -- other actions are handled in callbacks

    if actionDone then
        local lastAction = actions.current
        if actionPassCounter == save.data.settings.bombActionsPerPass then
            actions.current = ACTION_CODES.PASS_BOMB
            actionPassCounter = 0
            if fuseState ~= shownFuseState then
                shownFuseState = fuseState
                Statemachine.playWAV(bgMusic[shownFuseState])
            end
        else
            actions.current = actions.getValidActionCode(lastAction)
        end

        actions.setupActionGameplay(lastAction, actions.current)
        actions.setupActionGfxAndSound(actions.current)
        lastAnimationFrame = 1

        actionDone = false
        if actions.current == ACTION_CODES.PASS_BOMB then
            actionTimer.duration = actions.data[ACTION_CODES.PASS_BOMB].time[1]
            actionTimer:start()
            actionTimer:reset()
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
    bombTimer:remove()
    Statemachine.music:stop()
    -- pop twice to remove temp input handler from game over screen
    playdate.inputHandlers.pop()
    playdate.inputHandlers.pop()
end

local preSetupCalled = false
function bomb.setup()
    bgSprite = gfx.sprite.setBackgroundDrawingCallback(
        function( x, y, width, height )
            actions.data[actions.current].img:draw(0,0)
        end
    )

    -- Accelerometer only returns values on next update cycle after startAccelerometer is called
    -- This is inconvenient for us, since we need to set startVec once tilt action comes up
    -- So we just enable the accelerometer during the whole game
    if save.data.settings.allowTilt then
        playdate.startAccelerometer()
    end
    playdate.inputHandlers.push(actions.buttonHandler)

    actionTimer = playdate.timer.new(100, actionTimerEnd) -- dummy duration, proper value set in main_startGame
    actionTimer.discardOnCompletion = false
    bombTimer = playdate.timer.new(100, main_actionFail, "THE BOMB'S\nTIMER\nRAN OUT")
    bombTimer.discardOnCompletion = false

    playdate.update = update_main
    Statemachine.cleanup = cleanup_main
    actions.succesFnc = main_actionSuccess
    actions.failFnc = main_actionFail

    assert(preSetupCalled, "pre_setup_for_transition needs to be called prior, to init actions.current");
    main_startGame(true)
    preSetupCalled = false
end

function bomb.render_for_transition()
    if actions.data[actions.current].ani ~= nil then
        actions.data[actions.current].img.frame = 1
    end
    actions.data[actions.current].img:draw(0,0)
end

function bomb.pre_setup_for_transition()
    actions.current = actions.getValidActionCode()
    preSetupCalled = true
end