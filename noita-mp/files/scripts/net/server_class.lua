dofile("mods/noita-mp/files/scripts/util/file_util.lua")
local sock = require "sock"


-- https://www.tutorialspoint.com/lua/lua_object_oriented.htm
-- Meta class
Server = {
    super   = nil,
    address = nil,
    port    = nil
}


-- Derived class method new
function Server:new(o, super, address, port)
    o = o or {}
    setmetatable(o, self)
    self.__index = self
    self.super = super
    self.address = tostring(address) -- or ModSettingGet("noita-mp.server_ip")) print("server_class.lua | self.address = " .. self.address)
    self.port = tonumber(port) -- or ModSettingGet("noita-mp.server_port")) print("server_class.lua | self.port = " .. self.port)

    -- if self.port ~= nil and type(self.port) == "number" and self.address ~= nil and type(self.address) == "string" then
    --     self.super = sock.newServer(self.address, self.port)
    --     print("server_class.lua | Server started on " .. self.super:getAddress() .. ":" .. self.super:getPort())
    -- else
    --     print("server_class.lua | Unable to instantiate server object, because address and port are missing.")
    --     --GamePrintImportant("Unable to instantiate server object, because address and port are missing.")
    -- end

    return o
end


function Server:setSettings()
    self.super:setSchema("worldFiles", { "fileFullpath", "fileContent", "fileIndex", "amountOfFiles" })
    self.super:setSchema("worldFilesFinished", { "progress" })
    self.super:setSchema("seed", { "seed" })
    self.super:setSchema("playerState", { "index", "player" })
end


-- Derived class methods
function Server:createCallbacks()
    print("server_class.lua | Creating servers callback functions.")

    -- Called when someone connects to the server
    self.super:on("connect", function(data, peer)
        print("server_class.lua | on_connect: ")
        print("server_class.lua | on_connect: data = " .. tostring(data))
        print("server_class.lua | on_connect: client = " .. tostring(peer))


        -- Send client the servers world
        --local amount_of_files = GetAmountOfWorldFiles()
        local file_names, amount_of_files = GetSavegameWorldFileNames()
        for index, file_fullpath in ipairs(file_names) do
            print("server_class.lua | Sending world files to client: " .. index .. " " .. file_fullpath)
            local file_content = ReadSavegameWorldFile(file_fullpath)
            peer:send("worldFiles", { file_fullpath, file_content, index, amount_of_files })
        end

        -- Send client the servers seed
        local seed = "" .. StatsGetValue("world_seed")
        print("server_class.lua | Sending seed to client: connection id = " .. peer:getConnectId() .. ", seed = " .. seed)
        self.super:sendToPeer(peer, "seed", {seed})

        -- Send a message back to the connected client
        local msg = "Hello from the server!" .. seed
        peer:send("hello", msg)
    end)

    self.super:on("worldFilesFinished", function(data, peer)
        print("server_class.lua | on_worldFilesFinished: ")
        print("server_class.lua | on_worldFilesFinished: data = " .. tostring(data))
        print("server_class.lua | on_worldFilesFinished: client = " .. tostring(peer))

        -- Send restart command
        peer:send("restart", {"Restart now!"})
    end)

    -- Called when the client disconnects from the server
    self.super:on("disconnect", function(data)
        print("server_class.lua | Server disconnected. data = " .. tostring(data))
    end)

    -- see lua-enet/enet.c
    self.super:on("receive", function(data, channel, client)
        print("server_class.lua | Server received: data = " .. tostring(data) .. ", channel = " .. tostring(channel) .. ", client = " .. tostring(client))
    end)
end


function Server:create()
    print("server_class.lua | Starting server and fetching ip and port..")

    local ip = tostring(ModSettingGet("noita-mp.server_ip"))
    local port = tonumber(ModSettingGet("noita-mp.server_port"))
    print("server_class.lua | Starting server on " .. ip .. ":" .. port)

    self.super = sock.newServer(ip, port)
    print("server_class.lua | Server started on " .. self.super:getAddress() .. ":" .. self.super:getPort())

    self:setSettings()
    self:createCallbacks()

    GamePrintImportant( "Server started", "Your server is running on "
        .. self.super:getAddress() .. ":" .. self.super:getPort() .. ". Tell your friends to join!")
end


function Server:update()
    if not self.super then
        return -- server not established
    end

    self.super:update()
end


-- Create a new global object of the server
if ModSettingGet("noita-mp.server_start_when_world_loaded") then
    local ip = ModSettingGet("noita-mp.server_ip") print("server_class.lua | Server IP = " .. ip)
    local port = tonumber(ModSettingGet("noita-mp.server_port")) print("server_class.lua | Server Port = " .. port)
    _G.Server = Server:new(nil, ip, port)

    GamePrintImportant( "Server started", "Your server is running on "
        .. Server.super:getAddress() .. ":" .. Server.super:getPort() .. ". Tell your friends to join!")
else
    GamePrintImportant( "Server not started", "Your server wasn't started yet. Check ModSettings to change this or Press M to open multiplayer menu.")

    _G.Server = Server:new()
end