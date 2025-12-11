local TitleScene = require("scenes/title")
local GameScene = require("scenes/game")

---------------------------

local game = {
    -- vars
    scenes = {},
    
    -- game state
    currentScene = nil,
    joysticks = {
        -- Joystick objects
    },
    players = {
        --[[
        {
            team = "none" | "left" | "right",
            joystickID = joystickID,
            colour = {r, g, b},
            position = {x, y},
            mode = "idle" | "face" | "locked" | "paddle",
            eyes = 1 | 2 | 3 | 4,
            mouth = 1 | 2 | 3 | 4,
            wins = 0,
        }
        ]]--
    },

    -- assets
    images = {},

    -- constants
    constants = {
        MAX_DT = 1/30,
        CIRCLE_RADIUS = 30,
        JOYSTICK_DEADZONE = 0.2,
    },

    -- functions
    getJoystickByID = function(self, id)
        for _, joystick in ipairs(self.joysticks) do
            if joystick:getID() == id then
                return joystick
            end
        end
        return nil
    end,
    getPlayerByJoystickID = function(self, id)
        for _, player in ipairs(self.players) do
            if player.joystickID == id then
                return player
            end
        end
        return nil
    end,
    setScene = function (self, scene)
        if self.currentScene and self.currentScene.unload then
            self.currentScene:unload()
        end
        self.currentScene = scene
        if self.currentScene and self.currentScene.load then
            self.currentScene:load()
        end
    end,
    drawPlayer = function(self, player)
        love.graphics.setColor(player.colour)
        love.graphics.circle("fill", player.position.x, player.position.y, self.constants.CIRCLE_RADIUS)

        love.graphics.setColor(1, 1, 1, 1)
        
        local minWins = 999
        for i, player in ipairs(self.players) do
            minWins = math.min(minWins, player.wins)
        end
        if player.wins - minWins > 0 then
            local crownLevel = player.wins - minWins
            if crownLevel > 4 then
                crownLevel = 4
            end
            local crownImg = self.images["crown" .. crownLevel]
            local crownOffsetY = self.constants.CIRCLE_RADIUS + crownImg:getHeight() / 4 + 10
            love.graphics.draw(crownImg, player.position.x - crownImg:getWidth() / 4, player.position.y - crownOffsetY, 0, 0.5)
        end
        
        local eyeImg = self.images["eyes" .. player.eyes]

        love.graphics.draw(eyeImg, player.position.x - eyeImg:getWidth() / 4, player.position.y - self.constants.CIRCLE_RADIUS / 4 - eyeImg:getHeight() / 4, 0, 0.5)

        local mouthImg = self.images["mouth" .. player.mouth]
        local mouthOffsetY = self.constants.CIRCLE_RADIUS * 0.2

        love.graphics.draw(mouthImg, player.position.x - mouthImg:getWidth() / 4, player.position.y + mouthOffsetY, 0, 0.5)
    end
}

---------------------------

function love.load()
    love.window.setFullscreen(true)
    love.mouse.setVisible(false)
    
    local screenWidth = love.graphics.getWidth()
    game.constants.CIRCLE_RADIUS = math.max(30, screenWidth * 0.026)

    game.images.eyes1 = love.graphics.newImage("assets/images/eyes1.png")
    game.images.eyes2 = love.graphics.newImage("assets/images/eyes2.png")
    game.images.eyes3 = love.graphics.newImage("assets/images/eyes3.png")
    game.images.eyes4 = love.graphics.newImage("assets/images/eyes4.png")
    game.images.mouth1 = love.graphics.newImage("assets/images/mouth1.png")
    game.images.mouth2 = love.graphics.newImage("assets/images/mouth2.png")
    game.images.mouth3 = love.graphics.newImage("assets/images/mouth3.png")
    game.images.mouth4 = love.graphics.newImage("assets/images/mouth4.png")
    game.images.star = love.graphics.newImage("assets/images/star.png")
    game.images.buttonA = love.graphics.newImage("assets/images/buttons_a.png")
    game.images.buttonY = love.graphics.newImage("assets/images/buttons_y.png")
    game.images.leftStick = love.graphics.newImage("assets/images/left_stick.png")
    game.images.crown1 = love.graphics.newImage("assets/images/crown1.png")
    game.images.crown2 = love.graphics.newImage("assets/images/crown2.png")
    game.images.crown3 = love.graphics.newImage("assets/images/crown3.png")
    game.images.crown4 = love.graphics.newImage("assets/images/crown4.png")

    game.scenes.title = TitleScene.new(game)
    game.scenes.game = GameScene.new(game)

    game:setScene(game.scenes.title)
end

function love.update(dt)
    if dt > game.constants.MAX_DT then
        dt = game.constants.MAX_DT
    end

    if game.currentScene and game.currentScene.update then
        game.currentScene:update(dt)
    end
end

function love.draw()
    love.graphics.setBackgroundColor(1, 0.933, 0.835, 1)
    if game.currentScene and game.currentScene.draw then
        game.currentScene:draw()
    end
end

function love.gamepadpressed(joystick, button)
    if game.currentScene and game.currentScene.gamepadpressed then
        local player = game:getPlayerByJoystickID(joystick:getID())
        if player then
            game.currentScene:gamepadpressed(joystick, button, player)
        end
    end
end

function love.joystickadded(joystick)
    table.insert(game.joysticks, joystick)

    local player = game:getPlayerByJoystickID(joystick:getID())
    if not player then
        table.insert(game.players, {
            joystickID = joystick:getID(),
            team = "none",
            colour = {math.random(), math.random(), math.random()},
            position = {
                x = math.random() * (love.graphics.getWidth() - 100) + 50,
                y = math.random() * (love.graphics.getHeight() - 100) + 50
            },
            mode = "idle",
            eyes = math.random(1, 4),
            mouth = math.random(1, 4),
            wins = 0,
        })
   end
end

function love.joystickremoved(joystick)
    for i, j in ipairs(game.joysticks) do
        if j:getID() == joystick:getID() then
            table.remove(game.joysticks, i)
            break
        end
    end

    -- If we are on the menu screen, we can also remove the player
    -- TODO : When we load the menu scene, we should remove players whose joysticks are gone
    if game.currentScene == game.scenes.title then
        for i, player in ipairs(game.players) do
            if player.joystickID == joystick:getID() then
                table.remove(game.players, i)
                break
            end
        end
    end
end