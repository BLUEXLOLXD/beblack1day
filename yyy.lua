
-- [[ 0. CLEANUP ]] --
local player = game:GetService("Players").LocalPlayer
local pGui = player:WaitForChild("PlayerGui")
if pGui:FindFirstChild("ARX_Defeat_Fix") then pGui.ARX_Defeat_Fix:Destroy() end

-- [[ ⚙️ CONFIGURATION ]] --
local Config = {
    HostName = "Waterman_Bc", 
    JoinerName = "eFUegQTr36004", 
    SelectedChapter = "InvasionBug", 
    TargetFPS = 20, 
    RamLeakFix = true,
    AutoRestartTime = 5, 
    SuperFPSBooster = false 
}

-- [[ 1. 🚀 SYSTEM OPTIMIZER ]] --
if setfpscap then setfpscap(Config.TargetFPS) end
if Config.SuperFPSBooster then
    pcall(function()
        for _, v in pairs(game:GetDescendants()) do
            if v:IsA("BasePart") or v:IsA("MeshPart") then v.Material = Enum.Material.SmoothPlastic v.CastShadow = false
            elseif v:IsA("Decal") or v:IsA("Texture") then v:Destroy() end
        end
    end)
end

-- [[ 2. 🎨 PREMIUM GUI ]] --
local sgui = Instance.new("ScreenGui", pGui)
sgui.Name = "ARX_Defeat_Fix"
sgui.ResetOnSpawn = false
local main = Instance.new("Frame", sgui)
main.Size = UDim2.new(0, 280, 0, 260)
main.Position = UDim2.new(0.5, -140, 0, 60)
main.BackgroundColor3 = Color3.fromRGB(12, 12, 15)
main.BackgroundTransparency = 0.1
Instance.new("UICorner", main).CornerRadius = UDim.new(0, 12)
local glow = Instance.new("UIStroke", main)
glow.Thickness = 2.5
glow.Color = Color3.fromRGB(0, 255, 150)
local header = Instance.new("Frame", main)
header.Size = UDim2.new(1, 0, 0, 35)
header.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
Instance.new("UICorner", header).CornerRadius = UDim.new(0, 12)
local grad = Instance.new("UIGradient", header)
grad.Color = ColorSequence.new(Color3.fromRGB(0, 200, 255), Color3.fromRGB(0, 255, 150))
local title = Instance.new("TextLabel", header)
title.Size = UDim2.new(1, 0, 1, 0)
title.BackgroundTransparency = 1
title.Text = "ARX - DEFEAT FIX SYSTEM"
title.TextColor3 = Color3.fromRGB(0, 0, 0)
title.Font = Enum.Font.GothamBold
title.TextSize = 12
local content = Instance.new("TextLabel", main)
content.Size = UDim2.new(1, -20, 1, -45)
content.Position = UDim2.new(0, 10, 0, 42)
content.BackgroundTransparency = 1
content.TextColor3 = Color3.fromRGB(220, 220, 220)
content.TextSize = 10
content.Font = Enum.Font.GothamMedium
content.TextXAlignment = Enum.TextXAlignment.Left
content.TextYAlignment = Enum.TextYAlignment.Top
content.RichText = true

-- [[ 3. 📡 REMOTE ENGINE ]] --
local remoteEvent = game:GetService("ReplicatedStorage"):WaitForChild("Remote"):WaitForChild("Server"):WaitForChild("PlayRoom"):WaitForChild("Event")
local lastActionTime = 0

local function ExecuteMapSequence(mode)
    if tick() - lastActionTime < 15 then return end
    lastActionTime = tick()
    
    warn(">>> RE-MATCHING START: " .. tostring(mode))
    remoteEvent:FireServer("Create")
    task.wait(3) -- เพิ่มเวลารอให้ห้องสร้างเสร็จ
    
    if mode == "Sukuna" then
        remoteEvent:FireServer("Change-Mode", { Mode = "Calamity" }) task.wait(0.4)
        remoteEvent:FireServer("Change-Chapter", { Chapter = "Calamity_Chapter1" }) task.wait(0.4)
        remoteEvent:FireServer("Submit")
    elseif mode == "Shinra" then
        remoteEvent:FireServer("Change-Mode", { Mode = "Calamity" }) task.wait(0.4)
        remoteEvent:FireServer("Change-Chapter", { Chapter = "Calamity_Chapter2" }) task.wait(0.4)
        remoteEvent:FireServer("Submit")
    elseif mode == "Ghoul" then
        remoteEvent:FireServer("Fate Mode")
    elseif mode == "Gojo" then
        remoteEvent:FireServer("Change-Mode", { Mode = "Raids Stage" }) task.wait(0.4)
        remoteEvent:FireServer("Change-Chapter", { Chapter = "JJK_Raid_Chapter2" }) task.wait(0.4)
        remoteEvent:FireServer("Submit")
    elseif mode == "Mob" then
        remoteEvent:FireServer("Change-Mode", { Mode = "Raids Stage" }) task.wait(0.4)
        remoteEvent:FireServer("Change-World", { World = "EsperRaid" }) task.wait(0.4)
        remoteEvent:FireServer("Submit")
    elseif mode == "Invasion" then
        remoteEvent:FireServer("Change-Mode", { Mode = "Calamity" }) task.wait(0.4)
        remoteEvent:FireServer("Change-World", { World = "Invasion" }) task.wait(0.4)
        remoteEvent:FireServer("Submit")
    elseif mode == "InvasionBug" then
        remoteEvent:FireServer("Change-Mode", { Mode = "Calamity" }) task.wait(0.4)
        remoteEvent:FireServer("Change-World", { World = "Invasion" }) task.wait(0.4)
        remoteEvent:FireServer("Change-Chapter", { Chapter = "Invasion_Chapter1" }) task.wait(0.4)
        remoteEvent:FireServer("Submit")
    end
end

-- [[ 4. 🔄 MONITORING ENGINE ]] --
local RunService = game:GetService("RunService")
local Stats = game:GetService("Stats")
local currentFps = 0
RunService.RenderStepped:Connect(function(dt) currentFps = math.floor(1/dt) end)

local function FormatTime(s) return string.format("%02d:%02d", math.floor(s/60), s%60) end
local myRole = (player.Name == Config.HostName) and "Host" or (player.Name == Config.JoinerName and "Joiner" or "Unknown")

task.spawn(function()
    -- ปรับ Path ให้เจาะจงมากขึ้น
    local rewardsUI = pGui:WaitForChild("RewardsUI")
    local gameStatus = rewardsUI:WaitForChild("Main"):WaitForChild("LeftSide"):WaitForChild("GameStatus")
    local yenValue = pGui:WaitForChild("HUD"):WaitForChild("InGame"):WaitForChild("Main"):WaitForChild("Stats"):WaitForChild("Yen"):WaitForChild("YenValue")
    local playRoomFolder = game:GetService("ReplicatedStorage"):WaitForChild("PlayRoom")

    local lastYen, yenElapsed, ramElapsed = yenValue.Value, 0, 0

    while true do
        task.wait(1)
        ramElapsed = ramElapsed + 1
        if yenValue.Value == lastYen then yenElapsed = yenElapsed + 1 else lastYen = yenValue.Value yenElapsed = 0 end

        local mem = math.floor(Stats:GetTotalMemoryUsageMb())
        local roomPath = playRoomFolder:FindFirstChild(Config.HostName)
        local lobbyStatus, friendFound = "", false

        if roomPath then
            local pFolder = roomPath:FindFirstChild("Players")
            if pFolder then
                for i = 2, 4 do
                    local pObj = pFolder:FindFirstChild("Player" .. i)
                    local val = pObj and tostring(pObj.Value) or "Empty"
                    if val == Config.JoinerName then friendFound = true end
                    lobbyStatus = lobbyStatus .. "P" .. i .. ":[" .. (val == "" and "..." or val) .. "] "
                end
            end
        end

        local nextAction = "Monitoring..."
        if myRole == "Host" then
            -- ### จุดที่แก้ไข: ปรับปรุงการเช็ค DEFEAT ###
            local statusText = string.upper(tostring(gameStatus.Text)) -- ทำให้เป็นตัวพิมพ์ใหญ่ทั้งหมดเพื่อเช็คง่ายขึ้น
            local isDefeatFound = string.find(statusText, "DEFEAT") ~= nil
            
            local isIdleTrigger = (yenElapsed >= 120)
            local isTimeTrigger = (ramElapsed >= Config.AutoRestartTime)
            local isDefeatTrigger = (Config.SelectedChapter ~= "Invasion" and isDefeatFound)

            if isIdleTrigger or isTimeTrigger or isDefeatTrigger then
                local reason = isIdleTrigger and "IDLE" or (isTimeTrigger and "RAM FIX" or "DEFEAT")
                nextAction = "🔄 RE-MATCHING: " .. reason
                ExecuteMapSequence(Config.SelectedChapter)
                yenElapsed, ramElapsed = 0, 0
                task.wait(2) -- ป้องกันลูปเด้งซ้ำ
            elseif roomPath and friendFound then
                nextAction = "🚀 STARTING..."
                remoteEvent:FireServer("Start")
                task.wait(5) -- ลด Delay เพื่อให้เข้าเกมเร็วขึ้นเมื่อคนครบ
            end
        elseif myRole == "Joiner" and roomPath then
            nextAction = "🚪 JOINING HOST..."
            remoteEvent:FireServer(unpack({"Join-Room", { Room = roomPath }}))
        end

        -- Update UI
        content.Text = string.format(
            "💻 <b>SYSTEM:</b> FPS: %d | RAM: %dMB\n" ..
            "👤 <b>ROLE:</b> %s | <b>MAP:</b> %s\n" ..
            "--------------------------------------------\n" ..
            "⏱ <b>IDLE:</b> %s / 02:00\n" ..
            "♻️ <b>RAM FIX:</b> %s / %s\n" ..
            "--------------------------------------------\n" ..
            "👥 <b>LOBBY:</b> %s\n" ..
            "--------------------------------------------\n" ..
            "<b>ACTION:</b> <font color='#00FF96'>%s</font>\n" ..
            "📝 <b>UI STATUS:</b> %s",
            currentFps, mem, myRole, Config.SelectedChapter,
            FormatTime(yenElapsed), FormatTime(ramElapsed), FormatTime(Config.AutoRestartTime),
            lobbyStatus, nextAction, gameStatus.Text
        )
    end
end)
