local Scene = {}
Scene.__index = Scene

local ball = {x = 0, y = 0, vx = 300, vy = 200, radius = 20, speedMultiplier = 1.0, waiting = 2.0 }
local becomingPaddles = {}
local scores = {left = 0, right = 0}
local gameOver = false
local winningTeam = nil
local starBlinkTimer = 0
local maxWins = 10
local bounceCount = 0

local addToSide = "left"
local bonusPoints = {
    --[[
    {
        x = x,
        y = y,
    },
    ]]--
}

local paddles = {
    --[[
    {
        player = player,
        x = x,
        y = y,
        size = size,
        team = "left" | "right",
    },
    ]]--
}

function Scene.new(game)
    local self = setmetatable({}, Scene)

    self.game = game

    return self
end

function Scene:update(dt)
    -- Update star blink timer for game over state
    if gameOver then
        starBlinkTimer = starBlinkTimer + dt
        return -- Don't update game logic if game is over
    end

    if ball.waiting > 0 then
        ball.waiting = ball.waiting - dt
    else
        ball.x = ball.x + ball.vx * ball.speedMultiplier * dt
        ball.y = ball.y + ball.vy * ball.speedMultiplier * dt
        
        if ball.y - ball.radius <= 0 or ball.y + ball.radius >= love.graphics.getHeight() then
            ball.vy = -ball.vy
            ball.speedMultiplier = math.min(ball.speedMultiplier * 1.1, 3.0)
            bounceCount = bounceCount + 1
            if bounceCount % 4 == 0 then
                self:addBonusPoint()
            end
        end
        
        if ball.x - ball.radius <= 0 then
            scores.right = scores.right + 1
            bounceCount = bounceCount + 1
            if bounceCount % 4 == 0 then
                self:addBonusPoint()
            end
            self:checkForGameOver("right")
            if not gameOver then
                self:resetBall()
            end
        elseif ball.x + ball.radius >= love.graphics.getWidth() then
            scores.left = scores.left + 1
            bounceCount = bounceCount + 1
            if bounceCount % 4 == 0 then
                self:addBonusPoint()
            end
            self:checkForGameOver("left")
            if not gameOver then
                self:resetBall()
            end
        end
        
        for _, paddle in ipairs(paddles) do
            if paddle.player.mode ~= "paddle" then
                goto continue
            end
            
            local paddleTop = paddle.y - paddle.size / 2
            local paddleBottom = paddle.y + paddle.size / 2
            local collided = false
            
            if paddle.team == "left" and ball.vx < 0 then
                local paddleRight = paddle.x + 10
                if ball.x - ball.radius <= paddleRight and ball.x > paddle.x and
                   ball.y + ball.radius >= paddleTop and ball.y - ball.radius <= paddleBottom then
                    collided = true
                end
            elseif paddle.team == "right" and ball.vx > 0 then
                local paddleLeft = paddle.x - 10
                if ball.x + ball.radius >= paddleLeft and ball.x < paddle.x and
                   ball.y + ball.radius >= paddleTop and ball.y - ball.radius <= paddleBottom then
                    collided = true
                end
            end
            
            if collided then
                ball.vx = -ball.vx
                ball.speedMultiplier = math.min(ball.speedMultiplier * 1.1, 3.0)
                bounceCount = bounceCount + 1
                if bounceCount % 4 == 0 then
                    self:addBonusPoint()
                end
                
                local hitPos = (ball.y - paddle.y) / (paddle.size / 2)
                ball.vy = ball.vy + hitPos * 100
            end
            ::continue::
        end
    end

    for _, player in ipairs(self.game.players) do
        local joystick = self.game:getJoystickByID(player.joystickID)
        if player.mode == "face" then
            if joystick:isConnected() then
                local leftX = joystick:getGamepadAxis("leftx")
                local leftY = joystick:getGamepadAxis("lefty")

                if math.abs(leftX) < self.game.constants.JOYSTICK_DEADZONE then
                    leftX = 0
                end
                if math.abs(leftY) < self.game.constants.JOYSTICK_DEADZONE then
                    leftY = 0
                end

                local speed = 400
                player.position.x = player.position.x + leftX * speed * dt
                player.position.y = player.position.y + leftY * speed * dt
                
                local screenWidth = love.graphics.getWidth()
                local screenHeight = love.graphics.getHeight()
                player.position.x = math.max(self.game.constants.CIRCLE_RADIUS, math.min(screenWidth - self.game.constants.CIRCLE_RADIUS, player.position.x))
                player.position.y = math.max(self.game.constants.CIRCLE_RADIUS, math.min(screenHeight - self.game.constants.CIRCLE_RADIUS, player.position.y))
                
                for i = #bonusPoints, 1, -1 do
                    local bonusPoint = bonusPoints[i]
                    local distance = math.sqrt((player.position.x - bonusPoint.x)^2 + (player.position.y - bonusPoint.y)^2)
                    local collisionDistance = self.game.constants.CIRCLE_RADIUS + 20 -- Circle radius + some bonus point radius
                    
                    if distance < collisionDistance then
                        table.remove(bonusPoints, i)
                        
                        if player.team == "left" then
                            scores.left = scores.left + 1
                            self:checkForGameOver("left")
                        elseif player.team == "right" then
                            scores.right = scores.right + 1
                            self:checkForGameOver("right")
                        end
                        break
                    end
                end
            end
        elseif player.mode == "paddle" then
            local paddle = self:getPaddleForPlayer(player)
            if paddle then
                if becomingPaddles[player] then
                    local lerpSpeed = 10
                    player.position.x = player.position.x + (paddle.x - player.position.x) * lerpSpeed * dt
                    player.position.y = player.position.y + (paddle.y - player.position.y) * lerpSpeed * dt
                    if math.abs(player.position.x - paddle.x) < 5 and math.abs(player.position.y - paddle.y) < 5 then
                        becomingPaddles[player] = nil
                    end
                else
                    if joystick:isConnected() then
                        local leftY = joystick:getGamepadAxis("lefty")

                        if math.abs(leftY) < self.game.constants.JOYSTICK_DEADZONE then
                            leftY = 0
                        end

                        local speed = 400
                        paddle.y = paddle.y + leftY * speed * dt
                        
                        local screenHeight = love.graphics.getHeight()
                        paddle.y = math.max(paddle.size / 2, math.min(screenHeight - paddle.size / 2, paddle.y))
                    end
                end
            end
        end
    end
end

function Scene:checkForGameOver(scoringTeam)
    if scores.left >= maxWins then
        gameOver = true
        winningTeam = "left"
        for _, player in ipairs(self.game.players) do
            if player.team == "left" then
                player.wins = player.wins + 1
            end
        end
    elseif scores.right >= maxWins then
        gameOver = true
        winningTeam = "right"
        for _, player in ipairs(self.game.players) do
            if player.team == "right" then
                player.wins = player.wins + 1
            end
        end
    end
end

function Scene:resetBall()
    ball.x = love.graphics.getWidth() / 2
    ball.y = love.graphics.getHeight() / 2
    ball.speedMultiplier = math.max(ball.speedMultiplier * 0.5, 1.0)
    -- Random direction with larger horizontal component than vertical
    local angle = (math.random() - 0.5) * math.pi / 3
    if math.random() > 0.5 then
        angle = angle + math.pi
    end
    local speed = 300
    ball.vx = math.cos(angle) * speed
    ball.vy = math.sin(angle) * speed
    ball.waiting = 2.0
end

function Scene:draw()
    if not gameOver then
        love.graphics.setColor(0, 0, 0, 1)
        love.graphics.circle("fill", ball.x, ball.y, ball.radius)
        love.graphics.setColor(1, 1, 1, 1)
    end
    
    for _, player in ipairs(self.game.players) do
        if player.mode == "face" or becomingPaddles[player] then
            self.game:drawPlayer(player)
        end
        if player.mode == "paddle" and not becomingPaddles[player] then
            local paddle = self:getPaddleForPlayer(player)
            if paddle then
                love.graphics.setColor(player.colour)
                love.graphics.rectangle("fill", paddle.x - 10, paddle.y - paddle.size / 2, 20, paddle.size)
                love.graphics.setColor(1, 1, 1, 1)
            end
        end
    end
    
    self:drawBonusPoints()
    
    self:drawScore()
end

function Scene:drawScore()
    local starImg = self.game.images["star"]
    if not starImg then
        return
    end
    
    local screenWidth = love.graphics.getWidth()
    local screenHeight = love.graphics.getHeight()
    
    local starWidth = screenWidth * 0.029
    local starHeight = starWidth * (225 / 236)
    local margin = 10
    
    local scoredColor = {1, 0.72, 0, 1}
    local unscoredColor = {0.86, 0.81, 0.72, 1}
    
    local blinkingColor = scoredColor
    if gameOver and winningTeam then
        local blinkAlpha = (math.sin(starBlinkTimer * 8) + 1) / 2
        blinkingColor = {1, 0.72, 0, blinkAlpha}
    end
    
    for i = 1, maxWins do
        local x = margin + (i - 1) * (starWidth + 5)
        local y = margin
        
        if i <= scores.left then
            if gameOver and winningTeam == "left" then
                love.graphics.setColor(blinkingColor)
            else
                love.graphics.setColor(scoredColor)
            end
        else
            love.graphics.setColor(unscoredColor)
        end
        
        love.graphics.draw(starImg, x, y, 0, starWidth / starImg:getWidth(), starHeight / starImg:getHeight())
    end
    
    for i = 1, maxWins do
        local x = screenWidth - margin - i * (starWidth + 5) + 5
        local y = margin
        
        if i <= scores.right then
            if gameOver and winningTeam == "right" then
                love.graphics.setColor(blinkingColor)
            else
                love.graphics.setColor(scoredColor)
            end
        else
            love.graphics.setColor(unscoredColor)
        end
        
        love.graphics.draw(starImg, x, y, 0, starWidth / starImg:getWidth(), starHeight / starImg:getHeight())
    end
    
    love.graphics.setColor(1, 1, 1, 1)
end

function Scene:drawBonusPoints()
    local starImg = self.game.images["star"]
    if not starImg then
        return
    end
    
    local screenWidth = love.graphics.getWidth()
    local starWidth = screenWidth * 0.029
    local starHeight = starWidth * (225 / 236)
    
    love.graphics.setColor(1, 0.72, 0, 1)
    for _, bonusPoint in ipairs(bonusPoints) do
        love.graphics.draw(starImg, 
            bonusPoint.x - starWidth / 2,
            bonusPoint.y - starHeight / 2, 
            0, 
            starWidth / starImg:getWidth(), 
            starHeight / starImg:getHeight())
    end
    
    love.graphics.setColor(1, 1, 1, 1)
end

function Scene:addBonusPoint()
    if #bonusPoints >= 6 then
        return
    end
    
    local screenWidth = love.graphics.getWidth()
    local screenHeight = love.graphics.getHeight()
    local minDistance = 80
    local maxAttempts = 50

    if addToSide == "left" then
        addToSide = "right"
    else
        addToSide = "left"
    end
    
    local x, y
    local validPosition = false
    local attempts = 0
    
    repeat
        attempts = attempts + 1
        
        if addToSide == "left" then
            x = math.random(50, screenWidth / 2 - 50)
        else
            x = math.random(screenWidth / 2 + 50, screenWidth - 50)
        end
        y = math.random(100, screenHeight - 100)
        
        validPosition = true
        for _, bonusPoint in ipairs(bonusPoints) do
            local distance = math.sqrt((x - bonusPoint.x)^2 + (y - bonusPoint.y)^2)
            if distance < minDistance then
                validPosition = false
                break
            end
        end
        
    until validPosition or attempts >= maxAttempts
    
    table.insert(bonusPoints, {x = x, y = y})
end


function Scene:load()
    local sizeOfLeftTeam = 0
    local sizeOfRightTeam = 0
    
    scores.left = 0
    scores.right = 0
    gameOver = false
    winningTeam = nil
    starBlinkTimer = 0
    bounceCount = 0

    addToSide = "left"
    if math.random() > 0.5 then
        addToSide = "right"
    end
    bonusPoints = {}
    self:addBonusPoint()

    ball.x = love.graphics.getWidth() / 2
    ball.y = love.graphics.getHeight() / 2
    ball.speedMultiplier = 1.0
    ball.waiting = 2.0
    
    local angle = (math.random() - 0.5) * math.pi / 3
    if math.random() > 0.5 then
        angle = angle + math.pi
    end
    local speed = 300
    ball.vx = math.cos(angle) * speed
    ball.vy = math.sin(angle) * speed

    for _, player in ipairs(self.game.players) do
        if player.team == "left" then
            sizeOfLeftTeam = sizeOfLeftTeam + 1
        elseif player.team == "right" then
            sizeOfRightTeam = sizeOfRightTeam + 1
        end
    end

    local leftI = 0
    local rightI = 0
    paddles = {}
    becomingPaddles = {}
    for _, player in ipairs(self.game.players) do
        if player.team == "none" then
            player.mode = "idle"
        else
            player.mode = "paddle"
            becomingPaddles[player] = true
            local x = 0
            local size = 200
            if player.team == "left" then
                leftI = leftI + 1
                x = 50 * leftI
                size = 200 / sizeOfLeftTeam
            else
                rightI = rightI + 1
                x = love.graphics.getWidth() - 50 * rightI
                size = 200 / sizeOfRightTeam
            end
            table.insert(paddles, {
                player = player,
                x = x,
                y = love.graphics.getHeight() / 2,
                size = size,
                team = player.team,
            })
        end
    end
end

function Scene:getPaddleForPlayer(player)
    for _, paddle in ipairs(paddles) do
        if paddle.player == player then
            return paddle
        end
    end
    return nil
end

function Scene:gamepadpressed(joystick, button, player)
    if button == "b" and gameOver then
        self.game:setScene(self.game.scenes.title)
        return
    end
    
    if button == "a" and not gameOver then
        if player.mode == "face" then
            player.mode = "paddle"
            becomingPaddles[player] = true
        elseif player.mode == "paddle" then
            player.mode = "face"
            local paddle = self:getPaddleForPlayer(player)
            if paddle then
                player.position.x = paddle.x
                player.position.y = paddle.y
            end
        end
    end
end

return Scene