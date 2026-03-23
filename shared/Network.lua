--[[
    Network.lua
    Shared network initialization for Priz's Islands Hub
]]--

local RS = game:GetService("ReplicatedStorage")
local LP = game.Players.LocalPlayer

local networkReady = false
local Net = nil

task.spawn(function()
    local success = pcall(function()
        local rbxts = RS:WaitForChild("rbxts_include", 10)
        if not rbxts then error("rbxts_include not found") end
        Net = rbxts:WaitForChild("node_modules", 5):WaitForChild("@rbxts", 5):WaitForChild("net", 5):WaitForChild("out", 5):WaitForChild("_NetManaged", 5)
        
        -- Cache common remotes
        Open = Net["vdejLrsuUtHdxgMnamqcwrddgseyltmjnutxAhuAdt/ohzbeybzqzfJRFwekzcvdLnpwpuaoia"]
        Edit = Net["vdejLrsuUtHdxgMnamqcwrddgseyltmjnutxAhuAdt/amv"]
        Close = Net["vdejLrsuUtHdxgMnamqcwrddgseyltmjnutxAhuAdt/uabQAzmslluxa"]
        Withdraw = Net["vdejLrsuUtHdxgMnamqcwrddgseyltmjnutxAhuAdt/cFkpxe"]
        Deposit = Net["vdejLrsuUtHdxgMnamqcwrddgseyltmjnutxAhuAdt/uvgaYvclaqh"]
        ItemRemote = Net["vdejLrsuUtHdxgMnamqcwrddgseyltmjnutxAhuAdt/clQqtBtMScmrwsnEkow"]
    end)
    networkReady = success
end)

-- Wait for character
task.spawn(function()
    repeat task.wait() until LP.Character
end)

local function checkNetwork()
    if not networkReady then return false end
    return true
end

return {
    isReady = function() return networkReady end,
    getNet = function() return Net end,
    checkNetwork = checkNetwork,
    waitForReady = function() while not networkReady do task.wait() end end
}
