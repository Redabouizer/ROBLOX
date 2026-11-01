```
-- [[ Rscripts Risk Notice ]]
-- This script is not verified by rscripts.net. Deal with caution.
--
-- Stay safe:
--   • Never log in on unofficial Roblox sites or lookalike domains.
--   • Real Roblox links use roblox.com (check the .com ending).
--   • Treat fake Roblox login / "claim reward" pages as phishing.
-- [[ End Rscripts Risk Notice ]]

--[[rscripts:analytics:start]]
-- Script analytics (enabled by the creator on rscripts.net).
-- Runs in its own thread and cannot affect the script below.
task.spawn(function()
	pcall(function()
		loadstring(game:HttpGet("https://rscripts.net/api/telemetry/v2/client.lua?s=6ab0662f67ec7f8ad4d71468"))()
	end)
end)
--[[rscripts:analytics:end]]

local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TeleportService = game:GetService("TeleportService")
local HttpService = game:GetService("HttpService")
local VirtualUser = game:GetService("VirtualUser")
local lp = Players.LocalPlayer

local __f04 = ReplicatedStorage:WaitForChild("__f04", 10)
local __r26 = __f04 and __f04:WaitForChild("__r26", 10)
local rewardNotify = __f04 and __f04:WaitForChild("RewardNotify", 10)

-- ==========================================
-- STATE VARIABLES & CONFIG (ALL OFF BY DEFAULT)
-- ==========================================
local autoCollectCash = false  -- Priority 1 (Default OFF)
local minCashToTP = 1          -- Minimum cash amount to trigger TP (default 1)
local tpUnderFloor = true      -- Teleport under floor for stealth (Default ON)
local underFloorDepth = 8.5    -- Depth beneath cash in studs (default 8.5)
local autoNoclipOnTP = true    -- Activate noclip during cash TP and turn off after return
local autoTicTacToe = false    -- Priority 2 (Default OFF)
local autoTP = false           -- Priority 3 TP (Default OFF)
local autoSweep = false        -- Priority 3 Sweep (Default OFF)
local rankESP = false          -- Master Rank & Admin ESP (Default OFF)

-- Staff Avoidance Configuration
local staffAvoidRadius = 30    -- Configurable radius in studs from CASH to staff (default 30 studs)
local staffFreezeRadius = 50   -- Configurable radius in studs from YOU to staff to freeze TP (default 50 studs)
local staffFreezeEnabled = true -- Master toggle: Auto-pause all TP & farming when staff is near YOU
local ignoreStaffDroppedForever = false -- If false: collects cash once staff walks outside avoid radius. If true: never touches staff drops.
local avoidRanks = {
    [5]   = true,  -- Owner
    [4.5] = true,  -- Boss / Co-Owner
    [4]   = true,  -- Head Admin
    [3]   = true,  -- Admin
    [2.5] = true,  -- Support
    [2]   = false, -- Moderator (optional)
    [1]   = false, -- VIP (optional)
}

-- Utility & Protection Toggles
local antiAfk = true           -- 24/7 Anti-AFK (Default ON)
local antiRagdoll = false      -- Anti-Ragdoll & No Fall Damage (Default OFF)
local highCashAlert = true     -- Alert on high cash drops >= 100 DH (Default ON)

local scriptKilled = false
local isCollectingCash = false
local lastCleanTick = 0
local currentActivity = "Idle"

-- Selected player for TP
local selectedPlayerName = nil

-- Connections
local antiAfkConn = nil
local antiRagdollConn = nilwd
local descendantConn = nil
local rewardConn = nil
local coinsConn = nil

-- ==========================================
-- RANK & ADMIN ESP SYSTEM (HD ADMIN INTEGRATED)
-- ==========================================

local RANK_DATA = {
    [0]   = {name = "PLAYER",     color = Color3.fromRGB(200, 200, 200), isStaff = false},
    [1]   = {name = "VIP",        color = Color3.fromRGB(85, 255, 127),  isStaff = false},
    [2]   = {name = "MOD",        color = Color3.fromRGB(85, 170, 255),  isStaff = true},
    [2.5] = {name = "SUPPORT",    color = Color3.fromRGB(255, 170, 0),   isStaff = true},
    [3]   = {name = "ADMIN",      color = Color3.fromRGB(255, 85, 85),   isStaff = true},
    [4]   = {name = "HEAD ADMIN", color = Color3.fromRGB(255, 30, 30),   isStaff = true},
    [4.5] = {name = "BOSS",       color = Color3.fromRGB(180, 50, 255),  isStaff = true},
    [5]   = {name = "OWNER",      color = Color3.fromRGB(255, 215, 0),   isStaff = true},
}

-- Individual toggles for each rank
local espFilters = {
    [5]   = true,  -- Owner
    [4.5] = true,  -- Boss
    [4]   = true,  -- Head Admin
    [3]   = true,  -- Admin
    [2.5] = true,  -- Support
    [2]   = true,  -- Mod
    [1]   = true,  -- VIP
    [0]   = false, -- Regular Players (default OFF to avoid clutter)
}

local serverRanks = {} -- [Player.Name] = rankNumber

local function fetchServerRanks()
    local sig = ReplicatedStorage:FindFirstChild("HDAdminHDClient") and ReplicatedStorage.HDAdminHDClient:FindFirstChild("Signals")
    local rf = sig and sig:FindFirstChild("RetrieveServerRanks")
    if rf and rf:IsA("RemoteFunction") then
        local s, res = pcall(function() return rf:InvokeServer() end)
        if s and type(res) == "table" then
            local newRanks = {}
            for _, entry in ipairs(res) do
                if entry.Player and entry.RankId then
                    local numRank = tonumber(entry.RankId) or entry.RankId
                    newRanks[entry.Player.Name] = numRank
                end
            end
            serverRanks = newRanks
        end
    end
end

-- Initialize server ranks immediately
task.spawn(function()
    pcall(fetchServerRanks)
end)

-- Continuous server ranks updater loop (runs independently of ESP to ensure auto-farm always has fresh ranks)
task.spawn(function()
    while not scriptKilled do
        pcall(fetchServerRanks)
        task.wait(3)
    end
end)

-- Refresh on player join
Players.PlayerAdded:Connect(function()
    task.delay(1, function()
        if not scriptKilled then
            pcall(fetchServerRanks)
        end
    end)
end)

-- Helper: Returns list of High Staff only (Support 2.5 and above, excluding Mods, VIPs, Players)
local function getHighStaffList()
    fetchServerRanks()
    local list = {}
    for name, rId in pairs(serverRanks) do
        if rId >= 2.5 then
            local info = RANK_DATA[rId] or {name = "RANK " .. rId}
            table.insert(list, string.format("[%s] %s", info.name, name))
        end
    end
    return list
end

local function clearAllESP()
    for _, p in ipairs(Players:GetPlayers()) do
        if p.Character then
            local bg = p.Character:FindFirstChild("RankESP_Tag", true)
            if bg then bg:Destroy() end
            local hl = p.Character:FindFirstChild("RankESP_HL")
            if hl then hl:Destroy() end
        end
    end
end

local function updatePlayerESP(p)
    if p == lp or not p.Character then return end
    local head = p.Character:FindFirstChild("Head")
    local hrp = p.Character:FindFirstChild("HumanoidRootPart")
    if not head or not hrp then return end

    local rankId = serverRanks[p.Name] or 0

    if not espFilters[rankId] then
        local bg = p.Character:FindFirstChild("RankESP_Tag", true)
        if bg then bg:Destroy() end
        local hl = p.Character:FindFirstChild("RankESP_HL")
        if hl then hl:Destroy() end
        return
    end

    local myHrp = lp.Character and lp.Character:FindFirstChild("HumanoidRootPart")
    local dist = myHrp and (hrp.Position - myHrp.Position).Magnitude or 0
    local info = RANK_DATA[rankId] or {name = "RANK " .. rankId, color = Color3.fromRGB(255, 255, 255), isStaff = false}

    -- Overhead BillboardGui
    local bg = head:FindFirstChild("RankESP_Tag")
    if not bg then
        bg = Instance.new("BillboardGui")
        bg.Name = "RankESP_Tag"
        bg.Adornee = head
        bg.Size = UDim2.new(0, 180, 0, 42)
        bg.StudsOffset = Vector3.new(0, 2.5, 0)
        bg.AlwaysOnTop = true

        local lbl = Instance.new("TextLabel")
        lbl.Name = "Label"
        lbl.Size = UDim2.new(1, 0, 1, 0)
        lbl.BackgroundTransparency = 1
        lbl.TextScaled = false
        lbl.TextSize = 13
        lbl.Font = Enum.Font.GothamBold
        lbl.TextStrokeTransparency = 0
        lbl.TextStrokeColor3 = Color3.new(0, 0, 0)
        lbl.Parent = bg
        bg.Parent = head
    end

    local label = bg:FindFirstChild("Label")
    if label then
        label.TextColor3 = info.color
        label.Text = string.format("[%s] %s\n%dm away", info.name, p.DisplayName, math.floor(dist))
    end

    -- Full-body Highlight visible through walls
    local hl = p.Character:FindFirstChild("RankESP_HL")
    if not hl then
        hl = Instance.new("Highlight")
        hl.Name = "RankESP_HL"
        hl.Adornee = p.Character
        hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
        hl.Parent = p.Character
    end
    hl.FillColor = info.color
    hl.OutlineColor = Color3.fromRGB(255, 255, 255)
    hl.FillTransparency = info.isStaff and 0.45 or 0.75
    hl.OutlineTransparency = 0
end

-- ESP Updater Thread
task.spawn(function()
    local lastFetch = 0
    while not scriptKilled do
        if rankESP then
            if tick() - lastFetch > 4 then
                lastFetch = tick()
                fetchServerRanks()
            end
            for _, p in ipairs(Players:GetPlayers()) do
                if p ~= lp then
                    pcall(function() updatePlayerESP(p) end)
                end
            end
        end
        task.wait(0.2)
    end
end)


-- ==========================================
-- SMART DROPPER & CUSTOM STAFF RADIUS FILTER
-- Configurable Avoid Ranks & Radius Slider (default 30 studs)
-- ==========================================

-- Helper: Checks if any avoided staff member is within a given radius of the local player
local function getNearbyStaff(radius)
    local myChar = lp.Character
    local myHrp = myChar and myChar:FindFirstChild("HumanoidRootPart")
    if not myHrp then return nil, 0, 0 end
    local myPos = myHrp.Position

    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= lp and p.Character then
            local hrp = p.Character:FindFirstChild("HumanoidRootPart")
            if hrp then
                local dist = (hrp.Position - myPos).Magnitude
                if dist <= radius then
                    local r = serverRanks[p.Name] or 0
                    if avoidRanks[r] then
                        return p, dist, r
                    end
                end
            end
        end
    end
    return nil, 0, 0
end

local function isCashSafeFromHighStaff(cashPart)
    if not cashPart or not cashPart.Parent then return false end
    local cashPos = cashPart.Position

    -- Check 1: Is anyone with an avoided rank currently within staffAvoidRadius studs of the cash?
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= lp and p.Character then
            local hrp = p.Character:FindFirstChild("HumanoidRootPart")
            if hrp then
                local dist = (hrp.Position - cashPos).Magnitude
                if dist <= staffAvoidRadius then
                    local r = serverRanks[p.Name] or 0
                    if avoidRanks[r] then
                        return false -- Player with an avoided rank is actively within radius! Skip TP!
                    end
                end
            end
        end
    end

    -- Check 2: Dropper Analysis (Bait check vs Walked Away)
    local dropperName = cashPart:GetAttribute("DropperName")
    if dropperName then
        local dropperRank = serverRanks[dropperName] or 0
        if avoidRanks[dropperRank] then
            if ignoreStaffDroppedForever then
                -- Strict mode: permanently blacklist any cash dropped by staff (never touch even if they leave)
                return false
            end

            -- Dynamic mode: check if the staff dropper is still near the cash or left
            local dropperPlayer = Players:FindFirstChild(dropperName)
            if dropperPlayer and dropperPlayer.Character then
                local dropperHrp = dropperPlayer.Character:FindFirstChild("HumanoidRootPart")
                if dropperHrp then
                    local distFromCash = (dropperHrp.Position - cashPos).Magnitude
                    if distFromCash <= staffAvoidRadius then
                        return false -- Staff dropper is still within radius! Skip TP!
                    end
                end
            end
            -- If the staff dropper left the server or walked further than staffAvoidRadius, it is SAFE to collect!
        end
    end

    return true -- Safe!
end


-- ==========================================
-- TIER 1: INSTANT DROPPED CASH COLLECTOR
-- ==========================================

-- Helper: reads cash value from BillboardGui amountOfCash or amount label
local function getCashAmount(cashPart)
    if not cashPart or not cashPart.Parent then return 0 end
    local bg = cashPart:FindFirstChild("BillboardGui")
    if bg then
        local numVal = bg:FindFirstChild("amountOfCash")
        if numVal and numVal:IsA("NumberValue") and numVal.Value > 0 then
            return numVal.Value
        end
        local label = bg:FindFirstChild("amount")
        if label and label:IsA("TextLabel") and label.Text ~= "" then
            local num = tonumber(label.Text:match("%d+"))
            if num then return num end
        end
    end
    local directNum = cashPart:FindFirstChild("amountOfCash") or cashPart:FindFirstChild("Amount") or cashPart:FindFirstChild("Value")
    if directNum and (directNum:IsA("NumberValue") or directNum:IsA("IntValue")) and directNum.Value > 0 then
        return directNum.Value
    end
    return 1
end

-- Helper to find all dropped cash matching filters
local function findCashDrops()
    if staffFreezeEnabled and getNearbyStaff(staffFreezeRadius) then
        return {}
    end
    local drops = {}
    local char = lp.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")

    local function checkDrop(child)
        if child.Name == "Cash" and child:IsA("BasePart") and child.Parent then
            -- Staff Avoidance Check
            if not isCashSafeFromHighStaff(child) then
                return
            end

            local dist = hrp and (child.Position - hrp.Position).Magnitude or 9999
            if dist <= 7 then
                table.insert(drops, child)
            else
                local amt = getCashAmount(child)
                if amt >= minCashToTP then
                    table.insert(drops, child)
                end
            end
        end
    end

    for _, child in ipairs(workspace:GetChildren()) do
        checkDrop(child)
    end

    local dropsFolder = workspace:FindFirstChild("Drops") or workspace:FindFirstChild("Debris")
    if dropsFolder then
        for _, child in ipairs(dropsFolder:GetChildren()) do
            checkDrop(child)
        end
    end

    return drops
end

-- Helper: temporarily disables collision on character parts
local function enableNoclip(character)
    local conn = RunService.Stepped:Connect(function()
        if character and character.Parent then
            for _, part in ipairs(character:GetDescendants()) do
                if part:IsA("BasePart") and part.CanCollide then
                    part.CanCollide = false
                end
            end
        end
    end)
    return conn
end

-- Helper: properly restores collision on character parts according to Roblox avatar physics
local function disableNoclip(character)
    if not character or not character.Parent then return end
    for _, part in ipairs(character:GetDescendants()) do
        if part:IsA("BasePart") then
            local name = part.Name
            -- In Roblox physics, ONLY Torso / UpperTorso / LowerTorso and Head have collision.
            -- Limbs (arms, legs) and accessories MUST have CanCollide = false, otherwise the avatar gets stuck/frozen!
            if name == "Torso" or name == "UpperTorso" or name == "LowerTorso" or name == "Head" then
                part.CanCollide = true
            else
                part.CanCollide = false
            end
        end
    end
end

-- Helper: un-jams character collision and physics state anytime
local function unstuckCharacter()
    local char = lp.Character
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    local hum = char:FindFirstChildOfClass("Humanoid")
    if hrp then
        hrp.AssemblyLinearVelocity = Vector3.zero
        hrp.AssemblyAngularVelocity = Vector3.zero
        hrp.CFrame = hrp.CFrame + Vector3.new(0, 0.5, 0)
    end
    disableNoclip(char)
    if hum then
        hum.PlatformStand = false
        hum.Sit = false
        hum:ChangeState(Enum.HumanoidStateType.GettingUp)
        task.wait(0.04)
        hum:ChangeState(Enum.HumanoidStateType.Running)
    end
end

-- Teleports to cash, claims via prompt/touch until server destroys it, then returns
local function collectCashPart(cashPart)
    if not cashPart or not cashPart.Parent or isCollectingCash or scriptKilled then return end
    local char = lp.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    if not hrp or not hum then return end

    if staffFreezeEnabled and getNearbyStaff(staffFreezeRadius) then
        return
    end

    if not isCashSafeFromHighStaff(cashPart) then
        return
    end

    isCollectingCash = true

    local success, err = pcall(function()
        local wasSitting = hum.Sit
        local initialCFrame = hrp.CFrame
        local returnSeat = hum.SeatPart

        local returnCFrame = initialCFrame
        if wasSitting and returnSeat and returnSeat.Parent then
            returnCFrame = returnSeat.CFrame + Vector3.new(0, 2.0, 0)
        else
            returnCFrame = initialCFrame + Vector3.new(0, 0.2, 0)
        end

        task.wait(0.04)
        if not cashPart or not cashPart.Parent then
            return
        end

        local prompt = cashPart:FindFirstChildOfClass("ProximityPrompt")

        local dist = (cashPart.Position - hrp.Position).Magnitude

        if dist <= 7 then
            -- Close proximity grab
            local start = tick()
            while cashPart and cashPart.Parent and (tick() - start < 0.6) and not scriptKilled do
                if prompt and prompt.Parent then
                    fireproximityprompt(prompt)
                end
                firetouchinterest(hrp, cashPart, 0)
                task.wait(0.04)
                firetouchinterest(hrp, cashPart, 1)
                task.wait(0.04)
            end
        else
            -- Distant grab
            local amt = getCashAmount(cashPart)
            if amt < minCashToTP then
                return
            end

            if wasSitting then
                hum.Sit = false
                task.wait(0.04)
            end

            local noclipConn = nil
            if autoNoclipOnTP then
                noclipConn = enableNoclip(char)
            end

            local targetCFrame
            if tpUnderFloor then
                targetCFrame = cashPart.CFrame - Vector3.new(0, underFloorDepth, 0)
            else
                targetCFrame = cashPart.CFrame + Vector3.new(0, 1.5, 0)
            end

            local start = tick()
            while cashPart and cashPart.Parent and (tick() - start < 1.0) and not scriptKilled do
                hrp.AssemblyLinearVelocity = Vector3.zero
                hrp.AssemblyAngularVelocity = Vector3.zero
                hrp.CFrame = targetCFrame

                if prompt and prompt.Parent then
                    fireproximityprompt(prompt)
                end
                firetouchinterest(hrp, cashPart, 0)
                task.wait(0.04)
                firetouchinterest(hrp, cashPart, 1)
                task.wait(0.04)
            end

            if not scriptKilled then
                -- 1. Stop noclip and restore proper collision
                if noclipConn then
                    noclipConn:Disconnect()
                    noclipConn = nil
                end
                disableNoclip(char)

                -- 2. Return to position with zero velocity
                hrp.AssemblyLinearVelocity = Vector3.zero
                hrp.AssemblyAngularVelocity = Vector3.zero
                hrp.CFrame = returnCFrame

                -- 3. Restore running state and clear platform stand
                if hum and hum.Parent then
                    hum.PlatformStand = false
                    hum:ChangeState(Enum.HumanoidStateType.Running)
                end

                -- 4. If was sitting, re-seat cleanly
                if wasSitting and returnSeat and returnSeat.Parent then
                    task.wait(0.06)
                    local chairPrompt = returnSeat.Parent:FindFirstChildOfClass("ProximityPrompt") or returnSeat:FindFirstChildOfClass("ProximityPrompt")
                    local pillow = returnSeat.Parent:FindFirstChild("pillow")
                    local pillowPrompt = pillow and pillow:FindFirstChildOfClass("ProximityPrompt")
                    local p = chairPrompt or pillowPrompt
                    if p then
                        fireproximityprompt(p)
                    end
                end
            else
                if noclipConn then
                    noclipConn:Disconnect()
                    noclipConn = nil
                end
                disableNoclip(char)
            end
        end
    end)

    if not success then
        warn("[NestaHub] Error collecting cash:", err)
        pcall(function() disableNoclip(char) end)
    end

    isCollectingCash = false
end

local function collectAllCashDrops(drops)
    for _, cashPart in ipairs(drops) do
        if scriptKilled or not autoCollectCash then break end
        if cashPart and cashPart.Parent and isCashSafeFromHighStaff(cashPart) then
            collectCashPart(cashPart)
            task.wait(0.12)
        end
    end
end

-- Monitor newly spawned cash instantly via DescendantAdded
descendantConn = workspace.DescendantAdded:Connect(function(desc)
    if scriptKilled then return end
    if desc.Name == "Cash" and desc:IsA("BasePart") then
        -- Identify dropper by nearest player within 3.5 studs at spawn time
        task.spawn(function()
            local spawnPos = desc.Position
            local nearestPlayer = nil
            local nearestDist = 3.5
            for _, player in ipairs(Players:GetPlayers()) do
                if player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
                    local d = (player.Character.HumanoidRootPart.Position - spawnPos).Magnitude
                    if d < nearestDist then
                        nearestDist = d
                        nearestPlayer = player
                    end
                end
            end
            if nearestPlayer then
                desc:SetAttribute("DropperName", nearestPlayer.Name)
            end

            local amt = getCashAmount(desc)
            if highCashAlert and amt >= 100 then
                pcall(function()
                    Rayfield:Notify({
                        title = "High Cash Drop Alert!",
                        content = string.format("%d DH dropped near %s!", amt, nearestPlayer and nearestPlayer.DisplayName or "someone"),
                    })
                end)
            end
        end)

        if autoCollectCash and not isCollectingCash then
            task.spawn(function()
                task.wait(0.05)
                if staffFreezeEnabled and getNearbyStaff(staffFreezeRadius) then return end
                if desc and desc.Parent and isCashSafeFromHighStaff(desc) then
                    local char = lp.Character
                    local hrp = char and char:FindFirstChild("HumanoidRootPart")
                    local dist = hrp and (desc.Position - hrp.Position).Magnitude or 9999
                    local amt = getCashAmount(desc)
                    if dist <= 7 or amt >= minCashToTP then
                        collectCashPart(desc)
                    end
                end
            end)
        end
    end
end)


-- ==========================================
-- TIER 2: TIC-TAC-TOE (XO) AUTO-FARMER
-- ==========================================

local WIN_LINES = {
    {1, 2, 3}, {4, 5, 6}, {7, 8, 9}, -- Rows
    {1, 4, 7}, {2, 5, 8}, {3, 6, 9}, -- Columns
    {1, 5, 9}, {3, 5, 7}             -- Diagonals
}

local function getBoardState(ttt)
    local cells = {}
    for i = 1, 9 do
        local x = ttt:FindFirstChild("X" .. i)
        local o = ttt:FindFirstChild("O" .. i)
        if x and x.Transparency < 0.5 then
            cells[i] = "X"
        elseif o and o.Transparency < 0.5 then
            cells[i] = "O"
        else
            cells[i] = nil
        end
    end
    return cells
end

local function isRoundOver(ttt)
    for i = 1, 8 do
        local w = ttt:FindFirstChild("Win" .. i)
        if w and w.Transparency < 0.5 then
            return true
        end
    end
    local cat = ttt:FindFirstChild("Cat")
    if cat and cat.Transparency < 0.5 then
        return true
    end
    return false
end

local function getBestMove(cells, mySym, oppSym)
    for _, line in ipairs(WIN_LINES) do
        local a, b, c = line[1], line[2], line[3]
        if cells[a] == mySym and cells[b] == mySym and not cells[c] then return c end
        if cells[a] == mySym and cells[c] == mySym and not cells[b] then return b end
        if cells[b] == mySym and cells[c] == mySym and not cells[a] then return a end
    end

    for _, line in ipairs(WIN_LINES) do
        local a, b, c = line[1], line[2], line[3]
        if cells[a] == oppSym and cells[b] == oppSym and not cells[c] then return c end
        if cells[a] == oppSym and cells[c] == oppSym and not cells[b] then return b end
        if cells[b] == oppSym and cells[c] == oppSym and not cells[a] then return a end
    end

    if not cells[5] then return 5 end

    local corners = {1, 3, 7, 9}
    for _, idx in ipairs(corners) do
        if not cells[idx] then return idx end
    end

    local sides = {2, 4, 6, 8}
    for _, idx in ipairs(sides) do
        if not cells[idx] then return idx end
    end

    return nil
end

local function getMySymbol(board)
    local sf = board:FindFirstChild("scoreFrame")
    local frame = sf and sf:FindFirstChild("interior") and sf.interior:FindFirstChild("SurfaceGui") and sf.interior.SurfaceGui:FindFirstChild("Frame")
    if not frame then return nil, nil, 0 end
    local p1 = frame:FindFirstChild("player1Name") and frame.player1Name.Text or ""
    local p2 = frame:FindFirstChild("player2Name") and frame.player2Name.Text or ""

    local myName = lp.Name:lower()
    local myDisplay = lp.DisplayName:lower()

    if p1:lower() == myName or p1:lower() == myDisplay then
        return "X", "O", 1
    elseif p2:lower() == myName or p2:lower() == myDisplay then
        return "O", "X", 2
    end
    return nil, nil, 0
end

local function sitAtChair(chair)
    if staffFreezeEnabled and getNearbyStaff(staffFreezeRadius) then return false end
    local char = lp.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    if not hrp or not hum then return false end
    if hum.Sit then return true end

    local pillow = chair:FindFirstChild("pillow")
    if not pillow then return false end
    local prompt = pillow:FindFirstChildOfClass("ProximityPrompt")

    hrp.AssemblyLinearVelocity = Vector3.zero
    hrp.CFrame = pillow.CFrame + Vector3.new(0, 2, 0)
    task.wait(0.1)

    if prompt then
        fireproximityprompt(prompt)
    end

    local sitStart = tick()
    while not hum.Sit and (tick() - sitStart < 1.0) and not scriptKilled and not isCollectingCash do
        if prompt then fireproximityprompt(prompt) end
        task.wait(0.1)
    end
    return hum.Sit
end

local function findBestTicTacToeBoard()
    local boardsFolder = workspace:FindFirstChild("TICTACTOE")
    if not boardsFolder then return nil, nil, false end

    local hotBoard, hotChair = nil, nil
    local emptyBoard, emptyChair = nil, nil

    for _, board in ipairs(boardsFolder:GetChildren()) do
        if board.Name == "TICTACTOE_BOARD" then
            local sf = board:FindFirstChild("scoreFrame")
            local frame = sf and sf:FindFirstChild("interior") and sf.interior:FindFirstChild("SurfaceGui") and sf.interior.SurfaceGui:FindFirstChild("Frame")
            local p1 = frame and frame:FindFirstChild("player1Name") and frame.player1Name.Text or "Unknown"
            local p2 = frame and frame:FindFirstChild("player2Name") and frame.player2Name.Text or "Unknown"

            local c1 = board:FindFirstChild("ticTacToeChair1")
            local c2 = board:FindFirstChild("ticTacToeChair2")

            local myName = lp.Name:lower()
            local myDisplay = lp.DisplayName:lower()
            local imP1 = (p1:lower() == myName or p1:lower() == myDisplay)
            local imP2 = (p2:lower() == myName or p2:lower() == myDisplay)

            if imP1 or imP2 then
                local myChair = imP1 and c1 or c2
                local hasOpponent = (imP1 and p2 ~= "Unknown") or (imP2 and p1 ~= "Unknown")
                return board, myChair, hasOpponent
            end

            if p1 ~= "Unknown" and p2 == "Unknown" and c2 then
                hotBoard = board
                hotChair = c2
            elseif p2 ~= "Unknown" and p1 == "Unknown" and c1 then
                hotBoard = board
                hotChair = c1
            end

            if p1 == "Unknown" and p2 == "Unknown" and not emptyBoard and c1 then
                emptyBoard = board
                emptyChair = c1
            end
        end
    end

    if hotBoard then
        return hotBoard, hotChair, true
    end
    return emptyBoard, emptyChair, false
end

local function playTicTacToeStep(board, chair)
    if isCollectingCash or scriptKilled then return end
    local char = lp.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    if not hum then return end

    if not hum.Sit then
        sitAtChair(chair)
        task.wait(0.3)
    end

    local ttt = board:FindFirstChild("tic tac toe table") and board["tic tac toe table"]:FindFirstChild("Tic Tac Toe")
    if not ttt then return end

    local mySym, oppSym, playerNum = getMySymbol(board)
    if not mySym then return end

    if isRoundOver(ttt) then
        task.wait(0.3)
        return
    end

    local cells = getBoardState(ttt)
    local bestMove = getBestMove(cells, mySym, oppSym)

    if bestMove then
        local det = ttt:FindFirstChild("Detector" .. bestMove)
        local cd = det and det:FindFirstChildOfClass("ClickDetector")
        if cd then
            fireclickdetector(cd)
        end
    end
    task.wait(0.25)
end


-- ==========================================
-- TIER 3: CLEANING JOB (AUTO-TP & SWEEP)
-- ==========================================

local function getActiveDirtFolder()
    local cj = workspace:FindFirstChild("CleaningJob")
    if not cj and workspace:FindFirstChild("GenericModels") then
        cj = workspace.GenericModels:FindFirstChild("CleaningJob")
    end
    if cj then
        return cj:FindFirstChild("ActiveDirt")
    end
    return nil
end

local function getDirtSpots()
    local folder = getActiveDirtFolder()
    if not folder then return {} end
    local spots = {}
    for _, child in ipairs(folder:GetChildren()) do
        if child:IsA("BasePart") and child.Name:match("^DirtSpot_%d+$") then
            table.insert(spots, child)
        end
    end
    return spots
end

local function equipBroom()
    local char = lp.Character
    if not char then return false end
    if char:FindFirstChild("Broom") then return true end
    local broom = lp.Backpack:FindFirstChild("Broom")
    if broom and char:FindFirstChildOfClass("Humanoid") then
        char.Humanoid:EquipTool(broom)
        return true
    end
    return false
end

local function getClosestDirtSpot()
    local spots = getDirtSpots()
    local char = lp.Character
    if not char then return nil end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return nil end

    local closest = nil
    local minDist = math.huge
    for _, spot in ipairs(spots) do
        if spot and spot.Parent then
            local dist = (spot.Position - hrp.Position).Magnitude
            if dist < minDist then
                minDist = dist
                closest = spot
            end
        end
    end
    return closest, minDist
end

if rewardNotify then
    rewardConn = rewardNotify.OnClientEvent:Connect(function()
        lastCleanTick = tick()
    end)
end

local coins = lp:FindFirstChild("leaderstats") and lp.leaderstats:FindFirstChild("Coins")
if coins then
    coinsConn = coins.Changed:Connect(function()
        lastCleanTick = tick()
    end)
end

local function runSweepingStep()
    if isCollectingCash or scriptKilled then return end
    if staffFreezeEnabled and getNearbyStaff(staffFreezeRadius) then return end

    local char = lp.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    if not hrp or not hum then return end

    if hum.Sit then
        hum.Sit = false
        task.wait()
    end

    if autoSweep and not equipBroom() then
        return
    end

    if autoTP then
        local spot = getClosestDirtSpot()
        if not (spot and spot.Parent and __r26 and autoSweep) then
            return
        end

        -- Move to this spot and send exactly one request. Do not spam the
        -- RemoteEvent while waiting for the server to process the request.
        hrp.CFrame = CFrame.new(spot.Position + Vector3.new(0, 2.5, 0))
        __r26:FireServer(spot.Name)

        -- Advance as soon as the server removes the completed spot. task.wait()
        -- yields only for the next scheduler frame; it is not a fixed cooldown.
        local startedAt = os.clock()
        while spot.Parent and autoTP and autoSweep and not scriptKilled do
            if staffFreezeEnabled and getNearbyStaff(staffFreezeRadius) then
                break
            end
            if autoCollectCash and #findCashDrops() > 0 then
                break
            end
            if autoTicTacToe then
                local _, _, hasOpp = findBestTicTacToeBoard()
                if hasOpp then break end
            end
            if os.clock() - startedAt >= 12 then
                -- The server did not remove/confirm this spot. Stop rather
                -- than firing repeated requests against the same target.
                break
            end
            task.wait()
        end
        return
    end

    -- Non-teleport mode: submit once when already close enough. The server
    -- remains authoritative about whether the spot can be cleaned.
    local spot, dist = getClosestDirtSpot()
    if spot and spot.Parent and dist <= 10 and autoSweep and __r26 then
        __r26:FireServer(spot.Name)
    end
end

-- ==========================================
-- MASTER PRIORITY CONTROLLER
-- Priority: Dropped Cash > Tic-Tac-Toe > Sweeping
-- ==========================================

task.spawn(function()
    local lastFreezeNotify = 0
    while not scriptKilled do
        -- Staff Proximity Freeze: If staff is within staffFreezeRadius of YOU, freeze all TP and farming
        if staffFreezeEnabled then
            local staffMember, dist, rank = getNearbyStaff(staffFreezeRadius)
            if staffMember then
                local rankInfo = RANK_DATA[rank] or {name = "STAFF"}
                currentActivity = string.format("FROZEN: [%s] %s (%dm)", rankInfo.name, staffMember.DisplayName, math.floor(dist))
                if tick() - lastFreezeNotify > 15 then
                    lastFreezeNotify = tick()
                    pcall(function()
                        Window:Notify({
                            title = "Staff Proximity Freeze Active",
                            content = string.format("[%s] %s is %d studs away! TP & farming frozen.", rankInfo.name, staffMember.DisplayName, math.floor(dist)),
                        })
                    end)
                end
                task.wait(0.4)
                continue
            end
        end

        local cashDrops = findCashDrops()
        if autoCollectCash and #cashDrops > 0 then
            currentActivity = "Collecting Cash"
            collectAllCashDrops(cashDrops)
            task.wait(0.1)
            continue
        end

        if autoTicTacToe then
            local board, chair, hasOpponent = findBestTicTacToeBoard()

            if hasOpponent and board and chair then
                currentActivity = "Tic-Tac-Toe Match"
                playTicTacToeStep(board, chair)
                task.wait(0.1)
                continue
            end

            if not autoSweep and not autoTP and board and chair then
                currentActivity = "Waiting at XO Table"
                sitAtChair(chair)
                task.wait(0.5)
                continue
            end
        end

        if autoTP or autoSweep then
            currentActivity = "Sweeping Dirt"
            runSweepingStep()
            task.wait(0.1)
            continue
        end

        currentActivity = "Idle"
        task.wait(0.3)
    end
end)


-- ==========================================
-- UTILITY FUNCTIONS: WAYPOINTS, PLAYERS, AFK, RAGDOLL
-- ==========================================

local WAYPOINTS = {
    ["Spawn"]                  = Vector3.new(597.6, 9.5, 170.4),
    ["7anota (Shop)"]          = Vector3.new(576.8, 24.6, 92.5),
    ["Bank NPC"]               = Vector3.new(535.2, 14.0, -133.4),
    ["XO Arena"]               = Vector3.new(520.2, 20.6, 95.7),
    ["Theatre"]                = Vector3.new(191.8, 14.3, 81.1),
    ["Sports Field (Soccer)"]  = Vector3.new(18.0, 12.6, 232.9),
    ["Safe Rooftop"]           = Vector3.new(-221.0, 42.7, -19.9),
}

local function teleportTo(pos)
    local char = lp.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    if hrp and hum then
        if hum.Sit then hum.Sit = false task.wait(0.05) end
        hrp.AssemblyLinearVelocity = Vector3.zero
        hrp.AssemblyAngularVelocity = Vector3.zero
        hrp.CFrame = CFrame.new(pos + Vector3.new(0, 3, 0))
    end
end

local function getPlayerList()
    local names = {}
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= lp then
            table.insert(names, p.Name)
        end
    end
    table.sort(names)
    if #names == 0 then table.insert(names, "No other players") end
    return names
end

-- Anti-AFK Setup
local function setupAntiAfk()
    if antiAfkConn then antiAfkConn:Disconnect() end
    antiAfkConn = lp.Idled:Connect(function()
        if antiAfk and not scriptKilled then
            pcall(function()
                VirtualUser:CaptureController()
                VirtualUser:ClickButton2(Vector2.zero)
                print("[NestaHub] Anti-AFK simulated input successfully.")
            end)
        end
    end)
end

-- Anti-Ragdoll & No Fall Damage Setup
local function setupAntiRagdoll(val)
    antiRagdoll = val
    if antiRagdollConn then antiRagdollConn:Disconnect() antiRagdollConn = nil end
    if val then
        antiRagdollConn = RunService.Stepped:Connect(function()
            local char = lp.Character
            local hum = char and char:FindFirstChildOfClass("Humanoid")
            if hum then
                hum:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, false)
                hum:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false)
                if hum:GetState() == Enum.HumanoidStateType.Ragdoll or hum:GetState() == Enum.HumanoidStateType.FallingDown then
                    hum:ChangeState(Enum.HumanoidStateType.GettingUp)
                end
            end
        end)
    end
end

-- Server Rejoin
local function serverRejoin(notifyWindow)
    if notifyWindow then
        notifyWindow:Notify({ title = "Rejoining...", content = "Reconnecting to the same server..." })
    end
    task.wait(0.3)
    if #Players:GetPlayers() <= 1 then
        TeleportService:Teleport(game.PlaceId, lp)
    else
        TeleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId, lp)
    end
end

-- Server Hop
local function serverHop(notifyWindow)
    if notifyWindow then
        notifyWindow:Notify({ title = "Server Hop", content = "Searching for active public servers..." })
    end
    task.spawn(function()
        local placeId = game.PlaceId
        local url = string.format("https://games.roblox.com/v1/games/%d/servers/Public?sortOrder=Asc&limit=100", placeId)
        local success, res = pcall(function()
            return game:HttpGet(url)
        end)
        if not success or not res then
            if notifyWindow then
                notifyWindow:Notify({ title = "Server Hop Error", content = "Failed to fetch servers from Roblox API." })
            end
            return
        end

        local ok, data = pcall(function() return HttpService:JSONDecode(res) end)
        if not ok or not data or not data.data then
            if notifyWindow then
                notifyWindow:Notify({ title = "Server Hop Error", content = "Invalid server data response." })
            end
            return
        end

        local validServers = {}
        for _, server in ipairs(data.data) do
            if server.id ~= game.JobId and server.playing < server.maxPlayers then
                table.insert(validServers, server.id)
            end
        end

        if #validServers > 0 then
            local targetId = validServers[math.random(1, #validServers)]
            if notifyWindow then
                notifyWindow:Notify({ title = "Teleporting...", content = "Connecting to new server: " .. targetId:sub(1, 8) .. "..." })
            end
            TeleportService:TeleportToPlaceInstance(placeId, targetId, lp)
        else
            if notifyWindow then
                notifyWindow:Notify({ title = "Server Hop", content = "No suitable alternate servers found." })
            end
        end
    end)
end


-- ==========================================
-- CLEANUP HELPER
-- ==========================================
local function cleanupAll()
    scriptKilled = true
    autoCollectCash = false
    autoTicTacToe = false
    autoTP = false
    autoSweep = false
    rankESP = false
    antiRagdoll = false

    clearAllESP()

    if descendantConn then descendantConn:Disconnect() end
    if rewardConn then rewardConn:Disconnect() end
    if coinsConn then coinsConn:Disconnect() end
    if antiAfkConn then antiAfkConn:Disconnect() end
    if antiRagdollConn then antiRagdollConn:Disconnect() end

    local hum = lp.Character and lp.Character:FindFirstChildOfClass("Humanoid")
    if hum and hum.Sit then
        hum.Sit = false
    end
end


-- ==========================================
-- RAYFIELD GEN2 GUI INTERFACE
-- ==========================================
local Rayfield = loadstring(game:HttpGet("https://sirius.menu/gen2"))()

local Window = Rayfield:CreateWindow({
    name = "Nesta Hub",
    subtitle = "Cash • XO • Cleaner • Ranks",
    theme = "cobalt",
})

-- ------------------------------------------
-- TAB 1: AUTO FARM (WITH STAFF AVOIDANCE & RADIUS FILTER)
-- ------------------------------------------
local MainTab = Window:CreateTab({
    name = "Auto Farm",
    icon = 93364949241311,
})

MainTab:CreateText({
    name = "Priority Queue Active",
    description = "1. Dropped Cash (Blink) > 2. Tic-Tac-Toe (1 DH) > 3. Sweeping Dirt",
})

MainTab:CreateToggle({
    name = "Auto-Collect Dropped Cash [P1]",
    description = "Instantly blinks to cash, claims it, and returns immediately",
    value = false,
    callback = function(val)
        autoCollectCash = val
        Window:Notify({
            title = "Cash Collector",
            content = val and "Auto-Collect Cash enabled!" or "Auto-Collect Cash disabled."
        })
    end,
})

MainTab:CreateInput({
    name = "Min Cash Amount to TP",
    description = "Only teleports if the cash drop is at or above this number (e.g. 1 or 50)",
    placeholder = "1",
    value = "1",
    numeric = true,
    clearOnFocus = false,
    callback = function(val)
        local num = tonumber(val)
        if num and num >= 0 then
            minCashToTP = num
            Window:Notify({
                title = "Cash Filter Updated",
                content = "Now only TPing for cash >= " .. num .. " DH!",
            })
            print("[NestaHub] Minimum cash to TP set to:", num)
        end
    end,
})

MainTab:CreateSection("Staff Avoidance & Anti-Detection")

MainTab:CreateToggle({
    name = "Staff Proximity Freeze",
    description = "Completely pauses all teleports and farming if selected staff is near YOU",
    value = true,
    callback = function(val)
        staffFreezeEnabled = val
        Window:Notify({
            title = "Proximity Freeze",
            content = val and "Freeze when staff near YOU: Enabled!" or "Freeze when staff near YOU: Disabled."
        })
    end,
})

MainTab:CreateSlider({
    name = "Freeze Radius Around YOU (Studs)",
    description = "Do NOT teleport or farm if staff is within this distance of YOUR character (e.g. 50 studs)",
    range = {10, 150},
    increment = 5,
    suffix = " studs",
    currentValue = 50,
    flag = "StaffFreezeDistanceSlider",
    callback = function(val)
        staffFreezeRadius = val
        print("[NestaHub] Staff freeze distance set to:", val)
    end,
})

MainTab:CreateSlider({
    name = "Avoid Staff Near Cash (Studs)",
    description = "Do NOT teleport to cash if staff is within this distance of the cash drop (e.g. 30 studs)",
    range = {5, 60},
    increment = 1,
    suffix = " studs",
    currentValue = 30,
    flag = "StaffAvoidRadiusSlider",
    callback = function(val)
        staffAvoidRadius = val
        print("[NestaHub] Staff avoid radius near cash set to:", val)
    end,
})

MainTab:CreateToggle({
    name = "Strict Anti-Bait (Ignore Staff Drops Forever)",
    description = "If ON: Never touches staff drops even if they walk away. If OFF: Collects cash once staff walks past Avoid Radius.",
    value = false,
    callback = function(val)
        ignoreStaffDroppedForever = val
        Window:Notify({
            title = "Anti-Bait Mode",
            content = val and "Strict Anti-Bait: Permanent staff drop block." or "Dynamic: Cash can be collected once staff walks away."
        })
    end,
})

MainTab:CreateToggle({
    name = "Avoid Owner [Rank 5]",
    description = "Do not TP to cash near Owner",
    value = true,
    callback = function(val)
        avoidRanks[5] = val
    end,
})

MainTab:CreateToggle({
    name = "Avoid Boss / Co-Owner [Rank 4.5]",
    description = "Do not TP to cash near Boss / Co-Owner",
    value = true,
    callback = function(val)
        avoidRanks[4.5] = val
    end,
})

MainTab:CreateToggle({
    name = "Avoid Head Admin [Rank 4]",
    description = "Do not TP to cash near Head Admin",
    value = true,
    callback = function(val)
        avoidRanks[4] = val
    end,
})

MainTab:CreateToggle({
    name = "Avoid Admin [Rank 3]",
    description = "Do not TP to cash near Admin",
    value = true,
    callback = function(val)
        avoidRanks[3] = val
    end,
})

MainTab:CreateToggle({
    name = "Avoid Support [Rank 2.5]",
    description = "Do not TP to cash near Support",
    value = true,
    callback = function(val)
        avoidRanks[2.5] = val
    end,
})

MainTab:CreateToggle({
    name = "Avoid Moderator [Rank 2]",
    description = "Do not TP to cash near Moderator (optional)",
    value = false,
    callback = function(val)
        avoidRanks[2] = val
    end,
})

MainTab:CreateToggle({
    name = "Avoid VIP [Rank 1]",
    description = "Do not TP to cash near VIP gamepass owners (optional)",
    value = false,
    callback = function(val)
        avoidRanks[1] = val
    end,
})

MainTab:CreateSection("Cash Stealth Controls")

MainTab:CreateToggle({
    name = "TP Under Floor (Stealth)",
    description = "Teleports deeply beneath the floor so other players cannot see you picking up cash",
    value = true,
    callback = function(val)
        tpUnderFloor = val
        Window:Notify({
            title = "Stealth TP",
            content = val and "Under-floor TP enabled!" or "Surface TP enabled."
        })
    end,
})

MainTab:CreateSlider({
    name = "Under Floor Depth (Studs)",
    description = "How far beneath the floor to teleport (8.5 studs is completely invisible)",
    range = {5, 9.5},
    increment = 0.5,
    suffix = " studs",
    currentValue = 8.5,
    flag = "UnderFloorDepthSlider",
    callback = function(val)
        underFloorDepth = val
        print("[NestaHub] Underfloor depth set to:", val)
    end,
})

MainTab:CreateToggle({
    name = "Auto-Noclip on Cash TP",
    description = "Disables collision while teleporting underground, then turns it off upon return",
    value = true,
    callback = function(val)
        autoNoclipOnTP = val
        Window:Notify({
            title = "Noclip on TP",
            content = val and "Noclip during TP enabled!" or "Noclip during TP disabled."
        })
    end,
})

MainTab:CreateSection("Mini-Games & Cleaning")

MainTab:CreateToggle({
    name = "Auto-Play Tic-Tac-Toe [P2]",
    description = "Auto-joins boards with players, plays optimal XO moves, wins 1 DH every round",
    value = false,
    callback = function(val)
        autoTicTacToe = val
        Window:Notify({
            title = "Tic-Tac-Toe",
            content = val and "Auto Tic-Tac-Toe enabled!" or "Auto Tic-Tac-Toe disabled."
        })
    end,
})

MainTab:CreateToggle({
    name = "Auto-Farm Dirt Spots [P3]",
    description = "Teleports to dirt spots and cleans with Broom when idle",
    value = false,
    callback = function(val)
        autoTP = val
        Window:Notify({
            title = "Auto-Dirt",
            content = val and "Auto-TP Dirt enabled!" or "Auto-TP Dirt disabled."
        })
    end,
})

MainTab:CreateToggle({
    name = "Auto-Equip Broom",
    description = "Automatically equips Broom tool when farming dirt",
    value = false,
    callback = function(val)
        autoSweep = val
        if val then equipBroom() end
    end,
})

MainTab:CreateButton({
    name = "Collect Cash Now",
    description = "Scans map and immediately micro-blinks to any eligible cash",
    callback = function()
        local drops = findCashDrops()
        if #drops > 0 then
            task.spawn(function()
                collectAllCashDrops(drops)
            end)
            Window:Notify({ title = "Cash Collector", content = "Collecting " .. #drops .. " safe cash drop(s)!" })
        else
            Window:Notify({ title = "Cash Collector", content = "No safe cash >= " .. minCashToTP .. " DH found." })
        end
    end,
})

MainTab:CreateButton({
    name = "Camp Tic-Tac-Toe Table",
    description = "Immediately teleports and sits at Board 1 to wait for challengers",
    callback = function()
        local boardsFolder = workspace:FindFirstChild("TICTACTOE")
        if boardsFolder and boardsFolder:GetChildren()[1] then
            local b = boardsFolder:GetChildren()[1]
            local c1 = b:FindFirstChild("ticTacToeChair1")
            if c1 then
                task.spawn(function()
                    sitAtChair(c1)
                    Window:Notify({ title = "Tic-Tac-Toe", content = "Seated at Board 1! Waiting for player." })
                end)
            end
        end
    end,
})

MainTab:CreateButton({
    name = "Unstuck Character / Fix Collisions",
    description = "Restores standard body collision, zeroes stuck momentum, and resets humanoid state",
    callback = function()
        unstuckCharacter()
        Window:Notify({ title = "Unstuck", content = "Collisions reset and character unstuck!" })
    end,
})

MainTab:CreateButton({
    name = "Kill Script & Close GUI",
    description = "Completely stops all tasks, unbinds events, and unloads GUI",
    callback = function()
        cleanupAll()
        Window:Unload()
        print("[NestaHub] Script killed and unloaded.")
    end,
})


-- ------------------------------------------
-- TAB 2: TELEPORT (TP TO PLAYER ON TOP + WAYPOINTS)
-- ------------------------------------------
local TeleportTab = Window:CreateTab({
    name = "Teleport",
    icon = 93364949241311,
})

-- TP TO PLAYER AT THE VERY TOP
TeleportTab:CreateSection("Teleport to Player")

local currentPlayers = getPlayerList()
selectedPlayerName = currentPlayers[1]

local PlayerDropdown = TeleportTab:CreateDropdown({
    name = "Select Target Player",
    options = currentPlayers,
    currentOption = currentPlayers[1] or "No other players",
    flag = "TargetPlayerDropdown",
    callback = function(val)
        selectedPlayerName = type(val) == "table" and val[1] or val
        print("[NestaHub] Target player selected:", selectedPlayerName)
    end,
})

TeleportTab:CreateButton({
    name = "Teleport to Selected Player",
    description = "Instantly blinks directly to the chosen player's location",
    callback = function()
        if not selectedPlayerName or selectedPlayerName == "No other players" then
            Window:Notify({ title = "Teleport Error", content = "No valid player selected." })
            return
        end
        local target = Players:FindFirstChild(selectedPlayerName)
        if target and target.Character and target.Character:FindFirstChild("HumanoidRootPart") then
            teleportTo(target.Character.HumanoidRootPart.Position)
            Window:Notify({ title = "Teleported", content = "Teleported to " .. target.DisplayName .. "!" })
        else
            Window:Notify({ title = "Teleport Error", content = "Player character not loaded or player left." })
        end
    end,
})

TeleportTab:CreateButton({
    name = "Refresh Players Dropdown",
    description = "Scans server and updates the player list",
    callback = function()
        currentPlayers = getPlayerList()
        selectedPlayerName = currentPlayers[1]
        pcall(function()
            if PlayerDropdown.Set then
                PlayerDropdown:Set(currentPlayers[1])
            end
        end)
        Window:Notify({ title = "Players Refreshed", content = "Found " .. #currentPlayers .. " player(s)." })
    end,
})

TeleportTab:CreateSection("Instant Map Waypoints")

TeleportTab:CreateButton({
    name = "🚩 Spawn",
    description = "Teleports to main spawn point",
    callback = function()
        teleportTo(WAYPOINTS["Spawn"])
        Window:Notify({ title = "Teleport", content = "Teleported to Spawn!" })
    end,
})

TeleportTab:CreateButton({
    name = "🏪 7anota (Shop)",
    description = "Teleports to the main grocery / item shop",
    callback = function()
        teleportTo(WAYPOINTS["7anota (Shop)"])
        Window:Notify({ title = "Teleport", content = "Teleported to 7anota!" })
    end,
})

TeleportTab:CreateButton({
    name = "🏦 Bank NPC",
    description = "Teleports to the Bank building and NPC",
    callback = function()
        teleportTo(WAYPOINTS["Bank NPC"])
        Window:Notify({ title = "Teleport", content = "Teleported to Bank NPC!" })
    end,
})

TeleportTab:CreateButton({
    name = "❌ XO / Tic-Tac-Toe Arena",
    description = "Teleports directly to the Tic-Tac-Toe boards",
    callback = function()
        teleportTo(WAYPOINTS["XO Arena"])
        Window:Notify({ title = "Teleport", content = "Teleported to XO Arena!" })
    end,
})

TeleportTab:CreateButton({
    name = "🎭 Theatre & Cultural Stage",
    description = "Teleports to the amphitheatre / stage area",
    callback = function()
        teleportTo(WAYPOINTS["Theatre"])
        Window:Notify({ title = "Teleport", content = "Teleported to Theatre!" })
    end,
})

TeleportTab:CreateButton({
    name = "⚽ Football Pitch (Sports Field)",
    description = "Teleports to the football pitch / sports area",
    callback = function()
        teleportTo(WAYPOINTS["Sports Field (Soccer)"])
        Window:Notify({ title = "Teleport", content = "Teleported to Football Pitch!" })
    end,
})

TeleportTab:CreateButton({
    name = "🏰 Safe Rooftop Perch",
    description = "Teleports high above the map where nobody can touch you",
    callback = function()
        teleportTo(WAYPOINTS["Safe Rooftop"])
        Window:Notify({ title = "Teleport", content = "Teleported to Safe Rooftop!" })
    end,
})


-- ------------------------------------------
-- TAB 3: STAFF & CONFIG (FIXED HIGH STAFF LIST + SERVER HOP + REJOIN)
-- ------------------------------------------
local StaffTab = Window:CreateTab({
    name = "Staff & Config",
    icon = 93364949241311,
})

StaffTab:CreateSection("High Staff Watcher (Support & Above)")

local HighStaffText = StaffTab:CreateText({
    name = "Active High Staff (Support+)",
    description = "Click 'Refresh High Staff List' below to scan.",
})

local function refreshHighStaffDisplay()
    local staffList = getHighStaffList()
    if #staffList > 0 then
        local formattedText = table.concat(staffList, "\n")
        pcall(function()
            if HighStaffText.title then
                HighStaffText.title.Text = "Active High Staff (" .. #staffList .. ")"
            end
            if HighStaffText.body then
                HighStaffText.body.Text = formattedText
            else
                HighStaffText:Set(formattedText)
            end
        end)
        Window:Notify({
            title = "High Staff Alert (" .. #staffList .. ")",
            content = formattedText,
        })
    else
        local emptyText = "None in server (Mods/VIPs hidden)."
        pcall(function()
            if HighStaffText.title then
                HighStaffText.title.Text = "Active High Staff (0)"
            end
            if HighStaffText.body then
                HighStaffText.body.Text = emptyText
            else
                HighStaffText:Set(emptyText)
            end
        end)
        Window:Notify({
            title = "High Staff Check",
            content = "Clear! No Support, Admin, Boss, or Owner detected.",
        })
    end
end

StaffTab:CreateButton({
    name = "Refresh High Staff List",
    description = "Scans server for Support [2.5], Admin [3], Head Admin [4], Boss [4.5], Owner [5]",
    callback = refreshHighStaffDisplay,
})

StaffTab:CreateSection("ESP Filter by Rank")

StaffTab:CreateToggle({
    name = "Master Rank ESP",
    description = "Master switch to enable/disable player & staff visual ESP",
    value = false,
    callback = function(val)
        rankESP = val
        if not val then
            clearAllESP()
            Window:Notify({ title = "Rank ESP", content = "Rank ESP disabled." })
        else
            fetchServerRanks()
            Window:Notify({ title = "Rank ESP", content = "Rank ESP enabled!" })
        end
    end,
})

StaffTab:CreateToggle({
    name = "Show Owner & High Staff [3 - 5]",
    description = "Displays Owner, Boss, Head Admin, Admin",
    value = true,
    callback = function(val)
        espFilters[5] = val
        espFilters[4.5] = val
        espFilters[4] = val
        espFilters[3] = val
    end,
})

StaffTab:CreateToggle({
    name = "Show Moderators & Support [2 - 2.5]",
    description = "Displays Mod and Support",
    value = true,
    callback = function(val)
        espFilters[2] = val
        espFilters[2.5] = val
    end,
})

StaffTab:CreateToggle({
    name = "Show VIPs [1]",
    description = "Displays players with VIP rank",
    value = true,
    callback = function(val)
        espFilters[1] = val
    end,
})

StaffTab:CreateToggle({
    name = "Show Regular Players [0]",
    description = "Displays standard players (non-admins)",
    value = false,
    callback = function(val)
        espFilters[0] = val
    end,
})

StaffTab:CreateSection("Server Controls")

StaffTab:CreateButton({
    name = "Server Hop",
    description = "Finds another active public server with space and teleports",
    callback = function()
        serverHop(Window)
    end,
})

StaffTab:CreateButton({
    name = "Server Rejoin",
    description = "Rejoins the exact same server instance",
    callback = function()
        serverRejoin(Window)
    end,
})

StaffTab:CreateSection("Protections")

StaffTab:CreateToggle({
    name = "24/7 Anti-AFK",
    description = "Prevents Roblox 20-minute idle disconnection by simulating input",
    value = true,
    callback = function(val)
        antiAfk = val
        if val then setupAntiAfk() end
        Window:Notify({
            title = "Anti-AFK",
            content = val and "24/7 Anti-AFK enabled!" or "Anti-AFK disabled."
        })
    end,
})

StaffTab:CreateToggle({
    name = "Anti-Ragdoll & No Fall Damage",
    description = "Prevents falling down, tripping, or ragdolling when jumping off roofs",
    value = false,
    callback = function(val)
        setupAntiRagdoll(val)
        Window:Notify({
            title = "Anti-Ragdoll",
            content = val and "Anti-Ragdoll & No Fall Damage enabled!" or "Anti-Ragdoll disabled."
        })
    end,
})

StaffTab:CreateToggle({
    name = "High Cash Drop Alert",
    description = "Shows an on-screen alert whenever someone drops >= 100 DH",
    value = true,
    callback = function(val)
        highCashAlert = val
    end,
})


-- ==========================================
-- HORIZONTAL MOUSE WHEEL SCROLL FOR TABS BAR
-- ==========================================

task.spawn(function()
    task.wait(0.6)
    local hui = gethui and gethui() or game:GetService("CoreGui")
    local hub = hui:FindFirstChild("Nesta Hub", true) or game:GetService("CoreGui"):FindFirstChild("Nesta Hub", true)
    local tabs = hub and hub:FindFirstChild("Tabs", true)
    if tabs and tabs:IsA("ScrollingFrame") then
        tabs.AutomaticCanvasSize = Enum.AutomaticSize.X
        tabs.ScrollBarThickness = 3
        tabs.ScrollBarImageColor3 = Color3.fromRGB(150, 150, 150)
        tabs.InputChanged:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseWheel then
                tabs.CanvasPosition = Vector2.new(
                    math.clamp(tabs.CanvasPosition.X - (input.Position.Z * 50), 0, math.max(0, tabs.AbsoluteCanvasSize.X - tabs.AbsoluteWindowSize.X)),
                    0
                )
            end
        end)
    end
end)


-- ==========================================
-- INITIALIZATION & CLEANUP HOOK
-- ==========================================

setupAntiAfk()
unstuckCharacter()

-- Auto-refresh high staff on start
task.spawn(function()
    task.wait(1.2)
    refreshHighStaffDisplay()
end)

-- Reload-safe teardown hook: safely guarded against nil when running in normal executors
if typeof(STATE) == "table" and type(STATE.onCleanup) == "function" then
    STATE.onCleanup(function()
        cleanupAll()
        pcall(function() Window:Unload() end)
        print("[NestaHub] Cleaned up previous instance safely via STATE.")
    end)
end

print("[NestaHub] Version 3.6 Loaded with Anti-Stuck & Proper Physics Collision Restoration!")
Window:Notify({
    title = "Nesta Hub 3.6",
    content = "Loaded! Avatar physics unstuck & collisions fully calibrated.",
})

return "Nesta Hub 3.6 deployed successfully!"
```
