-- outOFbounds - main.lua

-- setting the initial window size to 80% the window size
local screenWidth, screenHeight = love.window.getDesktopDimensions()
local windowWidth, windowHeight = screenWidth * 0.8, screenHeight * 0.8
love.window.setMode(windowWidth, windowHeight, {
    vsync = false,
    resizable = true
})

-- global state variables
local bounceSound -- to be generated later as shown:  = generateBounceSound(440, 0.3) -- frequency (Hz), duration (s)
local ringSize = windowWidth > windowHeight and (windowHeight / 2) - 20 or (windowWidth / 2) - 20
local players = {}
local gameState = "mainMenu"
local winner = ""
local simTimer = 0
local simPlayers = {}
local playerSpeed = 200
local simWinner = ""
local possibleGameStates = {
    playing = "playing",
    mainMenu = "mainMenu",
    gameOver = "gameOver"
}

-- function to get the updated ring size with the current window size
function getRingSize()
    return windowWidth > windowHeight and (windowHeight / 2) - 20 or (windowWidth / 2) - 20
end

-- callback for when the window is sized by the user
function love.resize(x, y)
    windowWidth = x
    windowHeight = y
    ringSize = getRingSize()
    for i, p in ipairs(players) do
        p.rad = ringSize * 0.05
    end
end

-- function to create a singular player, next in the list
local function createPlayer(position, velocity, radius, colour)
    local posInList = #players + 1
    local player = {
        num = posInList,
        pos = position,
        vel = velocity,
        rad = radius,
        rgb = colour
    }
    table.insert(players, posInList, player)
end

-- initial menu items are just "start new game"
local menuItems = {
    [1] = {
        label = "Start New Game",
        funct = function()
            players = {}
            local center = {
                x = windowWidth / 2,
                y = windowHeight / 2
            }
            local offset = ringSize * 0.3

            local pos = {
                x = center.x - offset,
                y = center.y
            }
            local vel = {
                x = 0,
                y = 0
            }
            local rad = ringSize * 0.05
            local rgb = {
                r = 1,
                g = 0,
                b = 0
            }
            createPlayer(pos, vel, rad, rgb)
            local pos2 = {
                x = center.x + offset,
                y = center.y
            }
            local vel2 = {
                x = 0,
                y = 0
            }
            local rad2 = ringSize * 0.05
            local rgb2 = {
                r = 0,
                g = 0,
                b = 1
            }
            createPlayer(pos2, vel2, rad2, rgb2)
            gameState = "playing"
        end
    }
}

-- love2d callback for graphical updates on the gpu?
function love.draw()
    if gameState == "gameOver" then
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.printf("Game Over\n\n" .. winner .. " wins!\n\nPress Spacebar to play again", 0,
                             windowHeight / 2 - 60, windowWidth, "center")
    end
    if gameState == "mainMenu" then
        local currentItem
        for i = 1, #menuItems, 1 do
            currentItem = menuItems[i]
            love.graphics.setColor(0.5, 0.5, 0.5, 1)
            love.graphics.rectangle("fill", windowWidth / 2 - 50, windowHeight / 2 - (#menuItems * 30) + (i * 30),
                                    string.len(currentItem.label) * 8, 30)
            love.graphics.setColor(1, 1, 1, 1)
            love.graphics.printf(currentItem.label, windowWidth / 2 - 45,
                                 windowHeight / 2 - (#menuItems * 30) + (i * 37), 100, "center")
        end
        for _, p in ipairs(simPlayers) do
            love.graphics.setColor(p.rgb.r, p.rgb.g, p.rgb.b, 0.3)
            love.graphics.circle("fill", p.pos.x, p.pos.y, p.rad)
        end
        love.graphics.setColor(1, 1, 1, 0.5)
        love.graphics.printf("Demo Match\nLast Winner: " .. simWinner, 0, 20, windowWidth, "center")
    end
    if gameState == "playing" then
        for pi, p in ipairs(players) do
            love.graphics.setColor(p.rgb.r, p.rgb.g, p.rgb.b, 1)
            love.graphics.circle("fill", p.pos.x, p.pos.y, p.rad)
        end
    end
    love.graphics.setColor(0, 1, 0, 1)
    love.graphics.circle("line", windowWidth / 2, windowHeight / 2, ringSize)
end

-- creates a sim match for the background
local function createSimMatch()
    simPlayers = {}
    local center = {
        x = windowWidth / 2,
        y = windowHeight / 2
    }
    local offset = ringSize * 0.3
    local rad = ringSize * 0.05

    local function randVel()
        return {
            x = math.random(-100, 100),
            y = math.random(-100, 100)
        }
    end

    table.insert(simPlayers, {
        pos = {
            x = center.x - offset,
            y = center.y
        },
        vel = randVel(),
        rad = rad,
        rgb = {
            r = 0.8,
            g = 0.0,
            b = 0.0
        }
    })

    table.insert(simPlayers, {
        pos = {
            x = center.x + offset,
            y = center.y
        },
        vel = randVel(),
        rad = rad,
        rgb = {
            r = 0.0,
            g = 0.0,
            b = 0.8
        }
    })

end

-- hit sound
local function generateBounceSound(frequency, duration)
    local sampleRate = 44100
    local samples = {}
    local totalSamples = math.floor(duration * sampleRate)

    for i = 0, totalSamples - 1 do
        local t = i / sampleRate
        -- Decaying sine wave for bounce-like timbre
        local amplitude = math.exp(-5 * t) * 0.8 -- exponential decay
        local sample = amplitude * math.sin(2 * math.pi * frequency * t)
        samples[i + 1] = sample
    end

    -- Convert to 16-bit signed integer format
    local soundData = love.sound.newSoundData(totalSamples, sampleRate, 16, 1)
    for i = 0, totalSamples - 1 do
        soundData:setSample(i, samples[i + 1])
    end

    return love.audio.newSource(soundData)
end


-- returns whter or not the player is 50% out of bounds (lost)
local function isOut(player)
    local centerX = windowWidth / 2
    local centerY = windowHeight / 2
    local dx = player.pos.x - centerX
    local dy = player.pos.y - centerY
    local dist = math.sqrt(dx * dx + dy * dy)
    return (dist + (0.5 * player.rad)) > ringSize
end

-- checks if two circles are touching/intersecting
local function checkCollision(playerOne, playerTwo)
    local dx = playerOne.pos.x - playerTwo.pos.x
    local dy = playerOne.pos.y - playerTwo.pos.y
    local ds = dx * dx + dy * dy
    local rs = playerOne.rad + playerTwo.rad
    return ds <= rs * rs
end

-- predicts if a collision will happen in the next frame, based of DT
local function predictCollision(playerOne, playerTwo, dt)
    if dt == 0 then
        return false
    end
    local playerOneNew = {
        pos = {
            x = playerOne.pos.x + playerOne.vel.x * dt,
            y = playerOne.pos.y + playerOne.vel.y * dt
        },
        rad = playerOne.rad
    }
    local playerTwoNew = {
        pos = {
            x = playerTwo.pos.x + playerTwo.vel.x * dt,
            y = playerTwo.pos.y + playerTwo.vel.y * dt
        },
        rad = playerTwo.rad
    }
    return checkCollision(playerOneNew, playerTwoNew)
end

-- predicts the amount of time until two circles/players will make contact
local function predictCollisionTime(p1, p2)
    local dx = p2.pos.x - p1.pos.x
    local dy = p2.pos.y - p1.pos.y
    local dvx = p2.vel.x - p1.vel.x
    local dvy = p2.vel.y - p1.vel.y
    local r = p1.rad + p2.rad

    local A = dvx * dvx + dvy * dvy
    local B = 2 * (dx * dvx + dy * dvy)
    local C = dx * dx + dy * dy - r * r

    local discriminant = B * B - 4 * A * C
    if discriminant < 0 or A == 0 then
        return nil
    end

    local sqrtDisc = math.sqrt(discriminant)
    local t1 = (-B - sqrtDisc) / (2 * A)
    local t2 = (-B + sqrtDisc) / (2 * A)

    if t1 >= 0 then
        return t1
    elseif t2 >= 0 then
        return t2
    else
        return nil
    end
end


local dtt = 1
-- translates contact into bounce
local function resolveElasticCollision(p1, p2)
    local dx = p2.pos.x - p1.pos.x
    local dy = p2.pos.y - p1.pos.y
    local distSq = dx * dx + dy * dy
    if distSq == 0 then
        return
    end -- Prevent divide by zero

    local dvx = p1.vel.x - p2.vel.x
    local dvy = p1.vel.y - p2.vel.y

    local dot = dx * dvx + dy * dvy
    local scale = dot / distSq

    local fx = dx * scale
    local fy = dy * scale

    p1.vel.x = p1.vel.x - fx
    p1.vel.y = p1.vel.y - fy
    p2.vel.x = p2.vel.x + fx
    p2.vel.y = p2.vel.y + fy
    
    bounceSound = generateBounceSound(-(fx * fx + fy * fy) * 0.5, dtt / 2)
    bounceSound:play()
end

-- just for restarting, it gets called on keyDown once
function love.keypressed(key)
    if key == "space" and gameState == "gameOver" then
        for i, item in ipairs(menuItems) do
            if item.label == "Start New Game" then
                item.funct()
            end
        end
    end
end

-- simulation loop for the background game AI
function simulateGameInBackground(dt)
    simTimer = simTimer + dt
    -- AI: players steer toward each other + avoid edge
    local centerX, centerY = windowWidth / 2, windowHeight / 2

    for i, self in ipairs(simPlayers) do
        local other = simPlayers[3 - i] -- switch between 1 and 2

        local dx = other.pos.x - self.pos.x
        local dy = other.pos.y - self.pos.y
        local dist = math.sqrt(dx * dx + dy * dy)
        local moveTowardEnemyX = dx / dist
        local moveTowardEnemyY = dy / dist

        -- Edge avoidance
        local toCenterX = centerX - self.pos.x
        local toCenterY = centerY - self.pos.y
        local distToCenter = math.sqrt(toCenterX * toCenterX + toCenterY * toCenterY)
        local towardCenterX = toCenterX / distToCenter
        local towardCenterY = toCenterY / distToCenter

        -- Blend pursuit and ring-preservation
        local ringAvoidWeight = (distToCenter > ringSize * 0.85) and 1 or 0.2
        local enemyChaseWeight = 1.0 - ringAvoidWeight

        local goalX = moveTowardEnemyX * enemyChaseWeight + towardCenterX * ringAvoidWeight
        local goalY = moveTowardEnemyY * enemyChaseWeight + towardCenterY * ringAvoidWeight

        -- Normalize blended vector
        local goalLength = math.sqrt(goalX * goalX + goalY * goalY)
        goalX = goalX / goalLength
        goalY = goalY / goalLength

        -- Accelerate in the goal direction
        local accel = 120
        self.vel.x = self.vel.x + goalX * accel * dt
        self.vel.y = self.vel.y + goalY * accel * dt

    end
    for i = 1, #simPlayers - 1 do
        for j = i + 1, #simPlayers do
            local a = simPlayers[i]
            local b = simPlayers[j]

            local timeToCollide = predictCollisionTime(a, b)
            if timeToCollide and timeToCollide <= dt then
                resolveElasticCollision(a, b)
            else
                a.pos.x = a.pos.x + a.vel.x * dt
                a.pos.y = a.pos.y + a.vel.y * dt
                b.pos.x = b.pos.x + b.vel.x * dt
                b.pos.y = b.pos.y + b.vel.y * dt
            end
        end
    end
    for i, p in ipairs(simPlayers) do
        if isOut(p) then
            simWinner = (i == 1) and "Blue" or "Red"
            createSimMatch()
            simTimer = 0
            return
        end

    end
end

friction = 0.9989
-- love2d main update callback, gets called before each draw call
function love.update(dt)
    dtt = dt
    if gameState == "gameOver" then
        return
    end
    if gameState == "mainMenu" and #simPlayers > 0 then
        simulateGameInBackground(dt)
    elseif gameState == "mainMenu" and #simPlayers == 0 then
        createSimMatch()
    elseif gameState == "playing" then
        -- player one input
        local player1Moving = false
        if love.keyboard.isDown("w") then
            players[1].vel.y = players[1].vel.y - playerSpeed * dt
            player1Moving = true
        end
        if love.keyboard.isDown("s") then
            players[1].vel.y = players[1].vel.y + playerSpeed * dt
            player1Moving = true
        end
        if love.keyboard.isDown("a") then
            players[1].vel.x = players[1].vel.x - playerSpeed * dt
            player1Moving = true
        end
        if love.keyboard.isDown("d") then
            players[1].vel.x = players[1].vel.x + playerSpeed * dt
            player1Moving = true
        end

        -- player two input
        local player2Moving = false
        if love.keyboard.isDown("up") then
            players[2].vel.y = players[2].vel.y - playerSpeed * dt
            player2Moving = true
        end
        if love.keyboard.isDown("down") then
            players[2].vel.y = players[2].vel.y + playerSpeed * dt
            player2Moving = true
        end
        if love.keyboard.isDown("left") then
            players[2].vel.x = players[2].vel.x - playerSpeed * dt
            player2Moving = true
        end
        if love.keyboard.isDown("right") then
            players[2].vel.x = players[2].vel.x + playerSpeed * dt
            player2Moving = true
        end

        for i = 1, #players - 1 do
            for j = i + 1, #players do
                local a = players[i]
                local b = players[j]

                -- friction to slow when not inputting movement - setup this way to avoid reducing the max speed by limiting the speed to MaxSpeed * friction
                if not player1Moving then
                a.vel.x = a.vel.x > 0 and a.vel.x * friction or a.vel.x < 0 and a.vel.x * friction or 0
                a.vel.y = a.vel.y > 0 and a.vel.y * friction or a.vel.y < 0 and a.vel.y * friction or 0
                end
                if not player2Moving then
                b.vel.x = b.vel.x > 0 and b.vel.x * friction or b.vel.x < 0 and b.vel.x * friction or 0
                b.vel.y = b.vel.y > 0 and b.vel.y * friction or b.vel.y < 0 and b.vel.y * friction or 0
                end

                local timeToCollide = predictCollisionTime(a, b)
                if timeToCollide and timeToCollide <= dt then
                    resolveElasticCollision(a, b)
                else
                    a.pos.x = a.pos.x + a.vel.x * dt
                    a.pos.y = a.pos.y + a.vel.y * dt
                    b.pos.x = b.pos.x + b.vel.x * dt
                    b.pos.y = b.pos.y + b.vel.y * dt
                end
                if isOut(a) then
                    winner = "Blue"
                    gameState = "gameOver"
                    break
                elseif isOut(b) then
                    winner = "Red"
                    gameState = "gameOver"
                    break
                end
            end
        end
    end
end

-- for pressing the menu button to start a new game
function love.mousepressed(x, y, button)
    if button == 1 and gameState == "mainMenu" then
        local currentItem
        for i = 1, #menuItems, 1 do
            currentItem = menuItems[i]
            local mx = windowWidth / 2 - 50
            local my = windowHeight / 2 - (#menuItems * 30) + (i * 30)
            local mw = string.len(currentItem.label) * 9
            local mh = 30

            if x > mx and x < mx + mw and y > my and y < my + mh then
                currentItem.funct()
            end

        end
    end
end