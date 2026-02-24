-- server.lua
local enet = require "enet"

local host = enet.host_create("localhost:1989", 32) -- max 32 clients
local players = {} -- player data indexed by peer id

while true do
    local event = host:service(0)
    if event then
        if event.type == "connect" then
            print("Player connected:", event.peer)
            players[event.peer] = {
                pos = {x = 400, y = 300},
                vel = {x = 0, y = 0},
                rad = 20
            }
        elseif event.type == "receive" then
            -- parse input message from client
            local input = assert(load("return " .. event.data))()
            players[event.peer].vel = input.vel
        elseif event.type == "disconnect" then
            print("Player disconnected:", event.peer)
            players[event.peer] = nil
        end
    end

    -- Simulation step
    local dt = 1/60
    for _, p in pairs(players) do
        p.pos.x = p.pos.x + p.vel.x * dt
        p.pos.y = p.pos.y + p.vel.y * dt
    end

    -- Broadcast positions to all clients
    local state = {}
    for _, p in pairs(players) do
        table.insert(state, {pos = p.pos, rad = p.rad})
    end
    local serialized = "return " .. require("serpent").line(state)
    for _, peer in pairs(host:peers()) do
        peer:send(serialized)
    end
end