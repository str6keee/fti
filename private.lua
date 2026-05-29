--[[
    KUP HUB V2.
    Advanced Reach & Damage System.
    Not guaranteed to bypass Anti-Cheats. - Will bypass some better ones now
    Scripted by vkupz @ fjordius
--]]
local SG = game:GetService("StarterGui")
local RS = game:GetService("RunService")
local Players = game:GetService("Players")
local WS = game:GetService("Workspace")
local Player = Players.LocalPlayer
local Mouse = Player:GetMouse()
local Active = true

-- Notification function
local function Notify(Title, Text)
    task.spawn(function()
        SG:SetCore('SendNotification', {
            Title = tostring(Title),
            Text = tostring(Text),
            Duration = 2
        })
    end)
end

-- Use local variables instead of _G to avoid detection
local KupHub = true

-- Configuration with metatable for stealth
local Config = {}
local ConfigData = {
    Reach = true,
    Distance = 2,
    Increment = 0.1,
    Decrement = 0.1,
    DamageMultiplier = 3
}

setmetatable(Config, {
    __index = function(_, key)
        return ConfigData[key]
    end,
    __newindex = function(_, key, value)
        ConfigData[key] = value
    end
})

-- Options with metatable for stealth
local Options = {}
local OptionsData = {
    AutoClicker = true,
    EmulateTouch = true,
    DamageAmp = true,
    Notifications = true,
    SmartTargeting = true
}

setmetatable(Options, {
    __index = function(_, key)
        return OptionsData[key]
    end,
    __newindex = function(_, key, value)
        OptionsData[key] = value
    end
})

-- Keybinds with direct mapping for reliability
local Keys = {
    ToggleReach = "e",
    ToggleAC = "q",
    IncreaseReach = "z",
    DecreaseReach = "x",
    ToggleDamageAmp = "c",
    IncreaseDamage = "j",
    DecreaseDamage = "k",
    KillScript = "p",
    ToggleNotifications = "n"
}

-- Data storage
local WhitelistedChars = {}
local WhitelistedLimbs = {}
local HandleInfo = {}
local Connections = {}

-- Limb size reference
local Limbs = {
    ["Head"] = Vector3.new(2, 1, 1),
    ["Torso"] = Vector3.new(2, 2, 1),
    ["Left Arm"] = Vector3.new(1, 2, 1),
    ["Right Arm"] = Vector3.new(1, 2, 1),
    ["Left Leg"] = Vector3.new(1, 2, 1),
    ["Right Leg"] = Vector3.new(1, 2, 1),
    ["HumanoidRootPart"] = Vector3.new(2, 2, 1)
}

-- Welcome message with slight delay
if KupHub then
    task.spawn(function()
        wait(0.2) -- Small delay
        Notify("System Ready", "Initialized")
        wait(0.3)
        Notify("Status", string.format("R: %.1f | M: %dx", 
            Config.Distance, 
            Config.DamageMultiplier))
    end)
end

-- Keybind handler
local KeyConn = Mouse.KeyDown:Connect(function(key)
    key = string.lower(key)
    
    -- Add small delay to avoid detection
    task.spawn(function()
        wait(0.01)
        
        if key == Keys.ToggleReach then
            Config.Reach = not Config.Reach
            if Options.Notifications then
                Notify("Reach", tostring(Config.Reach))
            end
            
        elseif key == Keys.ToggleAC then
            Options.AutoClicker = not Options.AutoClicker
            if Options.Notifications then
                Notify("Auto Click", tostring(Options.AutoClicker))
            end
            
        elseif key == Keys.ToggleDamageAmp then
            Options.DamageAmp = not Options.DamageAmp
            if Options.Notifications then
                Notify("damage amp", tostring(Options.DamageAmp))
            end
            
        elseif key == Keys.IncreaseReach then
            Config.Distance = Config.Distance + Config.Increment
            if Options.Notifications then
                Notify("reach up", string.format("%.1f", Config.Distance))
            end
            
        elseif key == Keys.DecreaseReach then
            Config.Distance = math.max(0.5, Config.Distance - Config.Decrement)
            if Options.Notifications then
                Notify("reach up", string.format("%.1f", Config.Distance))
            end
            
        elseif key == Keys.IncreaseDamage then
            Config.DamageMultiplier = math.min(10, Config.DamageMultiplier + 1)
            if Options.Notifications then
                Notify("damage up", string.format("%dx", Config.DamageMultiplier))
            end
            
        elseif key == Keys.DecreaseDamage then
            Config.DamageMultiplier = math.max(1, Config.DamageMultiplier - 1)
            if Options.Notifications then
                Notify("damage down", string.format("%dx", Config.DamageMultiplier))
            end
            
        elseif key == Keys.ToggleNotifications then
            Options.Notifications = not Options.Notifications
            Notify("Alerts", tostring(Options.Notifications))
            
        elseif key == Keys.KillScript then
            Notify("System", "Shutting down...")
            for _, conn in pairs(Connections) do
                conn:Disconnect()
            end
            Active = false
            KupHub = false
        end
    end)
end)

Connections["KeyDown"] = KeyConn

-- Character validation function
local function ValidateCharacters(Descendants)
    local Result = {}
    local ValidLimbs = {}
    
    -- Helper functions
    local function IsPlayerCharacter(Char)
        return Players:GetPlayerFromCharacter(Char)
    end
    
    local function CheckSize(Size, Reference)
        -- Add small tolerance
        local tolerance = 0.02
        return math.abs(Size.X - Reference.X) <= tolerance and 
               math.abs(Size.Y - Reference.Y) <= tolerance and 
               math.abs(Size.Z - Reference.Z) <= tolerance
    end
    
    for _, obj in pairs(Descendants) do
        if obj:IsA("Model") then
            local Humanoid = obj:FindFirstChild("Humanoid")
            if Humanoid and obj ~= Player.Character and 
               Humanoid:GetState() ~= Enum.HumanoidStateType.Dead and 
               IsPlayerCharacter(obj) then
                
                local CharLimbs = {}
                
                for _, Part in pairs(obj:GetChildren()) do
                    if Part:IsA("BasePart") and Limbs[Part.Name] and 
                       CheckSize(Part.Size, Limbs[Part.Name]) then
                        table.insert(CharLimbs, Part)
                    end
                end
                
                if #CharLimbs > 6 then
                    for _, Limb in pairs(CharLimbs) do
                        table.insert(ValidLimbs, Limb)
                    end
                    table.insert(Result, obj)
                end
            end
        end
    end
    
    WhitelistedLimbs = ValidLimbs
    WhitelistedChars = Result
end

-- Get closest target function
local function GetClosestTarget()
    local ClosestDist = math.huge
    local ClosestChar = nil
    
    for _, Char in pairs(WhitelistedChars) do
        local HRP = Char:FindFirstChild("HumanoidRootPart")
        if HRP and Player.Character and Player.Character:FindFirstChild("HumanoidRootPart") then
            local Dist = (Player.Character.HumanoidRootPart.Position - HRP.Position).Magnitude
            if Dist < ClosestDist and Dist <= Config.Distance then
                ClosestDist = Dist
                ClosestChar = Char
            end
        end
    end
    
    return ClosestChar
end

-- Find connected handles function
local function FindHandles(Handle)
    local Handles = {}
    
    pcall(function()
        for _, part in pairs(Handle:GetConnectedParts()) do
            local Humanoid = part.Parent:FindFirstChild("Humanoid")
            if Humanoid then
                if Humanoid:GetLimb(part) == Enum.Limb.Unknown then
                    table.insert(Handles, part)
                end
            else
                table.insert(Handles, part)
            end
        end
    end)
    
    return Handles
end

-- Damage amplification function
local function AmplifyDamage(Handle, TargetParts)
    if not Options.DamageAmp then return end
    
    local Multiplier = Config.DamageMultiplier
    
    for _, Part in pairs(TargetParts) do
        if Part:IsA("BasePart") and table.find(WhitelistedLimbs, Part) then
            Part.CanTouch = true
            
            -- Use task.spawn for better performance
            for i = 1, Multiplier do
                task.spawn(function()
                    pcall(function()
                        firetouchinterest(Handle, Part, 0)
                        task.wait(0.001)
                        firetouchinterest(Handle, Part, 1)
                    end)
                end)
            end
        end
    end
end

-- Enhanced touch emulation
local function EmulateTouch(MainHandle, Handles)
    local Distance = Config.Distance
    local ScaleX = Distance / MainHandle.Size.X
    local ScaleY = Distance / MainHandle.Size.Y
    local ScaleZ = Distance / MainHandle.Size.Z
    
    local TargetChar = Options.SmartTargeting and GetClosestTarget() or nil
    
    for _, Handle in pairs(Handles) do
        local RegionMin = Handle.Position - Vector3.new(
            Handle.Size.X * ScaleX,
            Handle.Size.Y * ScaleY,
            Handle.Size.Z * ScaleZ
        )
        local RegionMax = Handle.Position + Vector3.new(
            Handle.Size.X * ScaleX,
            Handle.Size.Y * ScaleY,
            Handle.Size.Z * ScaleZ
        )
        
        local Region = Region3.new(RegionMin, RegionMax)
        
        -- Use pcall to prevent errors
        local success, PartsInRegion = pcall(function()
            return WS:FindPartsInRegion3(Region, Player.Character, 100)
        end)
        
        if not success then
            continue
        end
        
        if not HandleInfo[Handle] then
            HandleInfo[Handle] = {Touching = {}, Hit = 0}
        end
        
        local PartsToAmplify = {}
        
        for _, Part in pairs(PartsInRegion) do
            if table.find(WhitelistedLimbs, Part) then
                -- Smart targeting logic
                if Options.SmartTargeting and TargetChar then
                    if Part:IsDescendantOf(TargetChar) then
                        table.insert(PartsToAmplify, Part)
                    end
                else
                    table.insert(PartsToAmplify, Part)
                end
                
                if not table.find(HandleInfo[Handle].Touching, Part) then
                    table.insert(HandleInfo[Handle].Touching, Part)
                    
                    pcall(function()
                        firetouchinterest(Handle, Part, 0)
                        task.wait(0.001)
                        firetouchinterest(Handle, Part, 1)
                    end)
                end
            end
        end
        
        -- Apply damage amplification
        if #PartsToAmplify > 0 then
            AmplifyDamage(Handle, PartsToAmplify)
        end
    end
end

-- Character whitelist loop
coroutine.wrap(function()
    while Active do
        ValidateCharacters(WS:GetDescendants())
        wait(1)
    end
end)()

-- Reset on character respawn
local CharAddedConn = Player.CharacterAdded:Connect(function()
    HandleInfo = {}
end)

Connections["CharacterAdded"] = CharAddedConn

-- Main loop
local RenderConn = RS.RenderStepped:Connect(function()
    if not Config.Reach or not Active then return end
    
    local Character = Player.Character
    if not Character then return end
    
    local Tool = Character:FindFirstChildOfClass("Tool")
    if not Tool then return end
    
    -- Auto clicker
    if Options.AutoClicker then
        local Humanoid = Character:FindFirstChild("Humanoid")
        if Humanoid and Humanoid.Health > 0 then
            pcall(function()
                Tool:Activate()
            end)
        end
    end
    
    local Handle = Tool:FindFirstChild("Handle")
    if not Handle then return end
    
    -- Optimize handle properties
    pcall(function()
        Handle.CanCollide = false
        Handle.CanTouch = true
    end)
    
    -- Find handles with error handling
    local success, Handles = pcall(function()
        return FindHandles(Handle)
    end)
    
    if not success then
        Handles = {}
    end
    
    -- Emulate touch
    if Options.EmulateTouch then
        EmulateTouch(Handle, Handles)
    end
end)

Connections["RenderStepped"] = RenderConn

-- Add memory cleanup
task.spawn(function()
    while Active do
        wait(30)
        collectgarbage("collect")
    end
end)
