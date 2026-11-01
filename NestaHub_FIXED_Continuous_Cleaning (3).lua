-- ==========================================
-- TIER 3: OPTIMIZED CLEANING SYSTEM
-- ==========================================

local CLEANING_RETRY_INTERVAL = 0.1
local CLEANING_TIMEOUT = 12

local cleaningQueue = {}
local queuedSpots = {}
local isCleaning = false

local function getActiveDirtFolder()
    local cj = workspace:FindFirstChild("CleaningJob")

    if not cj then
        local models = workspace:FindFirstChild("GenericModels")
        cj = models and models:FindFirstChild("CleaningJob")
    end

    return cj and cj:FindFirstChild("ActiveDirt")
end

local function enqueueDirtSpot(spot)
    if not spot
        or not spot:IsA("BasePart")
        or not spot.Parent
        or queuedSpots[spot] then
        return
    end

    queuedSpots[spot] = true
    table.insert(cleaningQueue, spot)
end

local function refreshCleaningQueue()
    local folder = getActiveDirtFolder()
    if not folder then return end

    for _, spot in ipairs(folder:GetChildren()) do
        if spot.Name:match("^DirtSpot_%d+$") then
            enqueueDirtSpot(spot)
        end
    end
end

local function getNextDirtSpot()
    while #cleaningQueue > 0 do
        local spot = table.remove(cleaningQueue, 1)
        queuedSpots[spot] = nil

        if spot and spot.Parent then
            return spot
        end
    end

    return nil
end

local function equipBroom()
    local char = lp.Character
    if not char then return false end

    if char:FindFirstChild("Broom") then
        return true
    end

    local backpack = lp:FindFirstChildOfClass("Backpack")
    local broom = backpack and backpack:FindFirstChild("Broom")
    local hum = char:FindFirstChildOfClass("Humanoid")

    if broom and hum then
        hum:EquipTool(broom)
        return true
    end

    return false
end

local function runSweepingStep()
    if isCleaning or scriptKilled then return end
    if not autoTP and not autoSweep then return end

    if staffFreezeEnabled
        and getNearbyStaff(staffFreezeRadius) then
        return
    end

    local char = lp.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    local hum = char and char:FindFirstChildOfClass("Humanoid")

    if not hrp or not hum then return end

    isCleaning = true

    local success, err = pcall(function()

        if hum.Sit then
            hum.Sit = false
        end

        if autoSweep then
            equipBroom()
        end

        refreshCleaningQueue()

        local spot = getNextDirtSpot()
        if not spot then return end

        if autoTP then
            hrp.CFrame = CFrame.new(
                spot.Position + Vector3.new(0, 2.5, 0)
            )
        end

        local startTime = os.clock()

        while spot.Parent
            and not scriptKilled
            and (autoTP or autoSweep)
            and os.clock() - startTime < CLEANING_TIMEOUT do

            if staffFreezeEnabled
                and getNearbyStaff(staffFreezeRadius) then
                break
            end

            if autoSweep and not char:FindFirstChild("Broom") then
                equipBroom()
            end

            -- Stop when the server removes the cleaned spot.
            if not spot.Parent then
                break
            end

            task.wait(CLEANING_RETRY_INTERVAL)
        end

    end)

    if not success then
        warn("[NestaHub] Cleaning error:", err)
    end

    isCleaning = false
end
