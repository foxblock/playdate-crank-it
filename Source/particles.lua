if particles then return end  -- avoid loading twice the same module
particles = {}  -- create a table to represent the module

import "CoreLibs/graphics"
import "CoreLibs/sprites"

local gfx <const> = playdate.graphics
local SCREEN_WIDTH <const> = playdate.display.getWidth()
local SCREEN_HEIGHT <const> = playdate.display.getHeight()

local entities = {}
local physics = {}

function particles.add(imgPath, x, y, velx, vely, velrot)
    local p = {
        img = gfx.sprite.new(gfx.image.new(imgPath)),
        vx = velx,
        vy = vely,
        rot = velrot
    }
    p.hw, p.hh = p.img:getSize()
    p.hw, p.hh = p.hw / 2, p.hh / 2

    p.img:add()
    p.img:moveTo(x, y)

    table.insert(entities, p)
end

function particles.update()
    for k, p in pairs(entities) do
        p.img:moveBy(p.vx, p.vy)

        if p.img.x < -p.hw
            or p.img.x > SCREEN_WIDTH + p.hw
            or p.img.y < -p.hh
            or p.img.y > SCREEN_HEIGHT + p.hh
        then
            p.img:remove()
            entities[k] = nil
        end

        p.vx = p.vx + physics.gravityX
        p.vy = p.vy + physics.gravityY
        p.vx = p.vx * physics.frictionX
        p.vy = p.vy * physics.frictionY
        if p.rot ~= 0 then
            p.img:setRotation(p.img:getRotation() + p.rot)
        end
    end
end

function particles.clear()
    for k, p in pairs(entities) do
        p.img:remove()
        entities[k] = nil
    end
end

function particles.setDefaultPhysics()
    physics.gravityX = 0
    physics.gravityY = 1
    physics.frictionX = 0.92
    physics.frictionY = 1
end

function particles.setPhysics(addX, addY, multX, multY)
    physics.gravityX = addX
    physics.gravityY = addY
    physics.frictionX = multX
    physics.frictionY = multY
end

particles.setDefaultPhysics()