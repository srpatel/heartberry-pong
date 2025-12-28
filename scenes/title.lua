local Scene = {}
Scene.__index = Scene

function Scene.new(game)
    local self = setmetatable({}, Scene)

    self.game = game
    self.flashingPlayers = {}
    self.bottomScreenMessage = ""
    self.startGameTimer = nil
    self.lastNoiseAt = 0

    local screenWidth = love.graphics.getWidth()
    self.teamCircleRadius = screenWidth * 0.12
    self.teamCircleY = love.graphics.getHeight() / 2
    self.teamCircleLeftX = screenWidth * 0.27
    self.teamCircleRightX = screenWidth * 0.73

    return self
end

function Scene:load()
    for _, player in ipairs(self.game.players) do
        player.mode = "face"
    end
end

function Scene:update(dt)
    local leftTeam = {}
    local rightTeam = {}

    for _, player in ipairs(self.game.players) do
        if player.mode == "idle" then
            player.mode = "face"
        end

        if player.mode == "face" then
            local joystick = self.game:getJoystickByID(player.joystickID)
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
            end
        end

        if self.flashingPlayers[player] then
            self.flashingPlayers[player] = self.flashingPlayers[player] - dt * 1000
            if self.flashingPlayers[player] <= 0 then
                self.flashingPlayers[player] = nil
            end
        end

        local distanceToLeftCircle = math.sqrt((player.position.x - self.teamCircleLeftX)^2 + (player.position.y - self.teamCircleY)^2)
        local distanceToRightCircle = math.sqrt((player.position.x - self.teamCircleRightX)^2 + (player.position.y - self.teamCircleY)^2)
        if distanceToLeftCircle <= self.teamCircleRadius then
            player.team = "left"
            table.insert(leftTeam, player)
        elseif distanceToRightCircle <= self.teamCircleRadius then
            player.team = "right"
            table.insert(rightTeam, player)
        else
            player.team = "none"
        end
    end

    if #leftTeam == 0 or #rightTeam == 0 then
        self.bottomScreenMessage = "You need one player on each team to start!"
        self.startGameTimer = nil
        return
    end

    for _, player in ipairs(leftTeam) do
        if player.mode == "face" then
            self.bottomScreenMessage = "All players in a team must lock in to start!"
            self.startGameTimer = nil
            return
        end
    end
    for _, player in ipairs(rightTeam) do
        if player.mode == "face" then
            self.bottomScreenMessage = "All players in a team must lock in to start!"
            self.startGameTimer = nil
            return
        end
    end
    
    if self.startGameTimer and self.startGameTimer > 0 then
        if math.ceil(self.startGameTimer) < self.lastNoiseAt then
            self.game.sounds.countdown:play()
            self.lastNoiseAt = math.ceil(self.startGameTimer)
        end
        self.bottomScreenMessage = "Game starts in " .. math.ceil(self.startGameTimer) .. " seconds!"
        self.startGameTimer = self.startGameTimer - dt
        if self.startGameTimer <= 0 then
            self.game:setScene(self.game.scenes.game)
            self.game.sounds.start:play()
        end
        return
    end
    self.startGameTimer = 5
    self.lastNoiseAt = 5
    self.game.sounds.countdown:play()
end

function Scene:draw()
    love.graphics.setFont(self.game.fonts.titleFont)
    love.graphics.setColor(0, 0, 0, 1)
    
    local screenWidth = love.graphics.getWidth()
    local screenHeight = love.graphics.getHeight()
    local text = "pong."
    local textWidth = self.game.fonts.titleFont:getWidth(text)
    
    local x = (screenWidth - textWidth) / 2
    local y = 100
    
    love.graphics.print(text, x, y)

    love.graphics.setColor(220/255, 207/255, 185/255, 1)
    love.graphics.circle("fill", self.teamCircleLeftX, self.teamCircleY, self.teamCircleRadius)
    love.graphics.circle("fill", self.teamCircleRightX, self.teamCircleY, self.teamCircleRadius)

    love.graphics.setFont(self.game.fonts.titleFont)
    
    local leftTeamText = "left team"
    local rightTeamText = "right team"
    local leftTeamWidth = self.game.fonts.titleFont:getWidth(leftTeamText)
    local rightTeamWidth = self.game.fonts.titleFont:getWidth(rightTeamText)
    
    local textY = self.teamCircleY + self.teamCircleRadius + 20
    love.graphics.print(leftTeamText, self.teamCircleLeftX - leftTeamWidth / 2, textY)
    love.graphics.print(rightTeamText, self.teamCircleRightX - rightTeamWidth / 2, textY)

    for _, player in ipairs(self.game.players) do
        if player.mode == "face" or player.mode == "locked" then
            if player.mode == "locked" then
                love.graphics.setColor(1, 1, 1)
                love.graphics.circle("fill", player.position.x, player.position.y, self.game.constants.CIRCLE_RADIUS * 1.3)
            end

            self.game:drawPlayer(player)
            if self.flashingPlayers[player] then
                love.graphics.setColor(1, 0, 0, self.flashingPlayers[player] / 800)
                love.graphics.circle("fill", player.position.x, player.position.y, self.game.constants.CIRCLE_RADIUS)
            end
        end
    end

    if self.bottomScreenMessage ~= "" then
        love.graphics.setFont(self.game.fonts.titleFont)
        love.graphics.setColor(220/255, 207/255, 185/255, 1)
        
        local maxWidth = screenWidth * 0.6
        local messageX = screenWidth * 0.2
        local messageY = screenHeight - 140
        
        love.graphics.printf(self.bottomScreenMessage, messageX, messageY, maxWidth, "center")
    end

    love.graphics.setColor(220/255, 207/255, 185/255, 1)
    love.graphics.setFont(self.game.fonts.smallFont)
    
    local textX = screenWidth - 150
    local controlsY = screenHeight - 120
    local lineSpacing = 40
    local iconSize = 32
    
    local buttonAScale = iconSize / self.game.images.buttonA:getHeight()
    local buttonYScale = iconSize / self.game.images.buttonY:getHeight()
    local leftStickScale = iconSize / self.game.images.leftStick:getHeight()
    
    local iconOffset = 20
    
    local iconX = textX - iconOffset - self.game.images.buttonA:getWidth() * buttonAScale
    love.graphics.draw(self.game.images.buttonA, iconX, controlsY, 0, buttonAScale)
    love.graphics.print("Toggle ready", textX, controlsY)
    
    local yOffset = controlsY + lineSpacing
    iconX = textX - iconOffset - self.game.images.buttonY:getWidth() * buttonYScale
    love.graphics.draw(self.game.images.buttonY, iconX, yOffset, 0, buttonYScale)
    love.graphics.print("Change colour", textX, yOffset)
    
    local moveOffset = controlsY + lineSpacing * 2
    iconX = textX - iconOffset - self.game.images.leftStick:getWidth() * leftStickScale
    love.graphics.draw(self.game.images.leftStick, iconX, moveOffset, 0, leftStickScale)
    love.graphics.print("Move", textX, moveOffset)

    love.graphics.setColor(1, 1, 1, 1)
end

function Scene:gamepadpressed(joystick, button, player)
    if button == "a" then
        if player.mode == "locked" then
            player.mode = "face"
        else
            local screenWidth = love.graphics.getWidth()
            local screenHeight = love.graphics.getHeight()
            local circleRadius = screenWidth * 0.12
            local circleY = screenHeight / 2
            local leftCircleX = screenWidth * 0.27
            local rightCircleX = screenWidth * 0.73
            
            local leftDistance = math.sqrt((player.position.x - leftCircleX)^2 + (player.position.y - circleY)^2)
            local rightDistance = math.sqrt((player.position.x - rightCircleX)^2 + (player.position.y - circleY)^2)
            
            if leftDistance <= circleRadius or rightDistance <= circleRadius then
                player.mode = "locked"
            else
                self.flashingPlayers[player] = 800
            end
        end
    elseif button == "b" then
        if player.mode == "locked" then
            player.mode = "face"
        end
    elseif button == "y" then
        player.colour = {math.random(), math.random(), math.random()}
        player.eyes = math.random(1, 4)
        player.mouth = math.random(1, 4)
    end
end

return Scene