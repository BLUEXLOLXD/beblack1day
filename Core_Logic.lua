return function(Config, UI, Utils)
    local lp = game:GetService("Players").LocalPlayer
    local ReplicatedStorage = game:GetService("ReplicatedStorage")
    local RemoteEvent = ReplicatedStorage:WaitForChild("Remote"):WaitForChild("Server"):WaitForChild("PlayRoom"):WaitForChild("Event")
    local PlayerData = ReplicatedStorage:WaitForChild("Player_Data")
    local IsInMatch = false

    print("[CORE] Initializing Logic Engine...")

    -- [[ 1. LOOP ตรวจจับสถานะหน้าจอ (Monitor) ]] --
    task.spawn(function()
        while true do
            pcall(function()
                local hud = lp.PlayerGui:FindFirstChild("HUD")
                local stageLabel = hud and hud.InGame.Main.GameInfo.Stage.Label
                local rewardsUI = lp.PlayerGui:FindFirstChild("RewardsUI")

                -- A. ตรวจจับ Shibuya (หา Sukuna)
                if stageLabel and stageLabel.Text == "Calamity - Shibuya Incident" then
                    IsInMatch = true
                    UI.StatusLabel.Text = "🔥 กำลังหา sukuna"
                    UI.StatusLabel.TextColor3 = Color3.fromRGB(255, 80, 80)
                
                -- B. ตรวจจับ Chapter (Clear Story)
                elseif stageLabel and string.find(string.lower(stageLabel.Text), "chapter") then
                    IsInMatch = true
                    UI.StatusLabel.Text = "⚔️ กำลัง clear story"
                    UI.StatusLabel.TextColor3 = Color3.fromRGB(0, 200, 255)

                -- C. ตรวจจับ Rewards (จบด่าน 5 + WON) -> เตรียม Re-run
                elseif rewardsUI and rewardsUI.Enabled then
                    local chapterTxt = rewardsUI.Main.LeftSide.Chapter.Text
                    local statusTxt = rewardsUI.Main.LeftSide.GameStatus.Text
                    if string.find(chapterTxt, "Chapter 5") and string.find(statusTxt, "~ WON") then
                        warn("[SYSTEM] World Cleared! Preparing for next world.")
                        UI.StatusLabel.Text = "🎉 ชนะด่าน 5! กำลังรีรันใหม่..."
                        IsInMatch = true
                    end
                else
                    -- อยู่ล็อบบี้
                    if ReplicatedStorage:FindFirstChild("PlayRoom") then
                        IsInMatch = false
                    end
                end
            end)
            task.wait(1.5)
        end
    end)

    -- [[ 2. HOST / JOINER LOGIC ]] --
    local myName = Utils.cleanName(lp.Name)
    local fullTeam = {Config.HostName}
    for _, j in ipairs(Config.Joiners) do table.insert(fullTeam, j) end

    if myName == Utils.cleanName(Config.HostName) then
        print("[CORE] Host Logic Started.")
        task.spawn(function()
            while true do
                if not IsInMatch then
                    local targetChapter, targetWorld, modeType = nil, nil, "Story"

                    -- หาด่านที่ยังไม่ผ่าน
                    local worlds = {"OnePiece", "Namek", "Naruto", "TokyoGhoul", "SAO", "JJK", "TrashGround"}
                    for _, w in ipairs(worlds) do
                        for i = 1, 5 do
                            local sName = w .. "_Chapter" .. i
                            local needsClear = false
                            for _, member in ipairs(fullTeam) do
                                local d = PlayerData:FindFirstChild(member)
                                if d and d:FindFirstChild("StageClears") and not d.StageClears:FindFirstChild(sName) then
                                    needsClear = true; break
                                end
                            end
                            if needsClear then targetWorld, targetChapter = w, sName; break end
                        end
                        if targetChapter then break end
                    end

                    -- ถ้า Story ครบ -> เช็ค Sukuna
                    if not targetChapter and Config.CheckSukuna then
                        local missing = false
                        for _, j in ipairs(Config.Joiners) do
                            local d = PlayerData:FindFirstChild(j)
                            if d and d.Collection and not d.Collection:FindFirstChild("Sukuna:") then
                                missing = true; break
                            end
                        end
                        if missing then
                            modeType, targetWorld, targetChapter = "Calamity", "Calamity", "Calamity_Chapter1"
                        end
                    end

                    -- สร้างห้อง (Rebuild Sequence)
                    if targetChapter then
                        print("[HOST] Creating: " .. targetChapter)
                        RemoteEvent:FireServer("Create")
                        task.wait(Config.DelayTime)

                        if modeType == "Story" then
                            RemoteEvent:FireServer("Change-World", { World = targetWorld })
                        else
                            RemoteEvent:FireServer("Change-Mode", { Mode = "Calamity" })
                        end
                        task.wait(Config.DelayTime)

                        RemoteEvent:FireServer("Change-Chapter", { Chapter = targetChapter })
                        task.wait(Config.DelayTime)
                        RemoteEvent:FireServer("Submit")

                        -- รอทีม
                        while not Utils.isTeamInRoom(fullTeam, Config.HostName) and not IsInMatch do
                            UI.StatusLabel.Text = "⏳ รอทีมเข้าห้อง..."
                            task.wait(1)
                        end

                        -- เริ่มเกม
                        if Config.AutoSubmit and not IsInMatch then
                            warn("[HOST] Starting Game!")
                            task.wait(Config.DelayTime)
                            RemoteEvent:FireServer("Start")
                            IsInMatch = true
                            task.wait(10)
                        end
                    end
                end
                task.wait(3)
            end
        end)
    else
        print("[CORE] Joiner Logic Started.")
        task.spawn(function()
            while true do
                if not IsInMatch then
                    pcall(function()
                        local room = ReplicatedStorage.PlayRoom:FindFirstChild(Config.HostName)
                        if room and not Utils.isTeamInRoom({lp.Name}, Config.HostName) then
                            print("[JOINER] Room found, joining...")
                            RemoteEvent:FireServer("Join-Room", { Room = room })
                        end
                    end)
                end
                task.wait(2)
            end
        end)
    end
end
