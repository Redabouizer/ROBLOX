local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local remoteFolder = ReplicatedStorage:WaitForChild("FLD_SystemsRemotes")
local dropRemote = remoteFolder:WaitForChild("REM_DropCash")

local COOLDOWN = 60
local RESPONSE_TIMEOUT = 3

local lastDropTime = -math.huge
local requestPending = false

local function requestDropCash(amount)
    amount = tonumber(amount)

    if not amount or amount <= 0 then
        return false, "Enter a valid amount"
    end

    local leaderstats = player:FindFirstChild("leaderstats")
    local coins = leaderstats and leaderstats:FindFirstChild("Coins")

    if not coins then
        return false, "Coins value not found"
    end

    if amount > coins.Value then
        return false, "Insufficient coins"
    end

    if requestPending then
        return false, "A request is already pending"
    end

    local remaining = COOLDOWN - (os.clock() - lastDropTime)

    if remaining > 0 then
        return false, string.format("Wait %d seconds", math.ceil(remaining))
    end

    requestPending = true
    lastDropTime = os.clock()

    local success, err = pcall(function()
        dropRemote:FireServer(amount)
    end)

    if not success then
        requestPending = false
        warn("[DropCash] Request failed:", err)
        return false, "Request failed"
    end

    task.delay(RESPONSE_TIMEOUT, function()
        requestPending = false
    end)

    return true, "Drop request sent"
end

-- Example:
local success, message = requestDropCash(100)
print(message)
