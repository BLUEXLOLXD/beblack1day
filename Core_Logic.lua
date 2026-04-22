return function(Config, UI, Utils)
    local lp = game:GetService("Players").LocalPlayer
    local ReplicatedStorage = game:GetService("ReplicatedStorage")
    local RemoteEvent = ReplicatedStorage:WaitForChild("Remote"):WaitForChild("Server"):WaitForChild("PlayRoom"):WaitForChild("Event")
    local PlayerData = ReplicatedStorage:WaitForChild("Player_Data")
    local IsInMatch = false

    print("[CORE] System V13 - Logic Engine Started.")

    -- [[ 1. LOOP ตรวจจับสถานะหน้าจอ (Monitor) ]] --
    task.spawn(function()
        while true do
            pcall(function()
                local hud = lp.PlayerGui:FindFirstChild("HUD")
                local stageLabel = hud and hud.InGame.Main.GameInfo.Stage.Label
                local rewardsUI = lp.PlayerGui:FindFirstChild("RewardsUI")

                -- A. ตรวจจับสถานะในด่านปกติ
                if stageLabel then
                    local txt = string.lower(stageLabel.Text)
                    if string.find(txt, "chapter") then
                        IsInMatch = true
                        UI.StatusLabel.Text = "⚔️ กำลัง clear story"
                        UI.StatusLabel.TextColor3 = Color3.fromRGB(0, 200, 255)
                    elseif string.find(txt, "shibuya") or string.find(txt, "calamity") then
                        IsInMatch = true
                        UI.StatusLabel.Text = "🔥 กำลังหา sukuna"
                        UI.StatusLabel.TextColor3 = Color3.fromRGB(255, 80, 80)
                    end
                end

                -- B. ⭐ CONDITION: [WORLD CLEAR READY] (Chapter 5 + WON)
                if rewardsUI and rewardsUI.Enabled then
                    local chapterTxt = rewardsUI.Main.LeftSide.Chapter.Text
                    local statusTxt = rewardsUI.Main.LeftSide.GameStatus.Text
                    
                    if string.find(chapterTxt, "Chapter 5") and string.find(statusTxt, "~ WON") then
                        warn("[MATCH ENDED] Chapter 5 WON! Triggering Rerun...")
                        UI.StatusLabel.Text = "🎉 จบโลกแล้ว! กำลังกลับล็อบบี้เพื่อ Rerun..."
                        UI.StatusLabel.TextColor3 = Color3.fromRGB(255, 255, 0)
                        
                        task.wait(3) -- รอรางวัลเด้ง
                        local leaveBtn = rewardsUI.Main.LeftSide.Buttons:FindFirstChild("Leave")
                        if leaveBtn then
                            -- กดยืนยันการ Leave (Rerun Process)
                            local signals = {"Activated", "MouseButton1Click"}
                            for _, sig in pairs(signals) do
                                if leaveBtn:FindFirstChild(sig) or leaveBtn[sig] then
                                    for _, con in pairs(getconnections(leaveBtn[sig])) do con:Fire() end
                                end
                            end
                        end
                        -- ปลดล็อค IsInMatch เพื่อให้กลับไปสร้างห้องโลกถัดไปเมื่อถึงล็อบบี้
                        task.wait(5)
                        IsInMatch = false 
                    end
                else
                    -- ตรวจสอบว่าอยู่ล็อบบี้หรือยัง (ถ้าเจอ PlayRoom แปลว่าอยู่ล็อบบี้แล้ว)
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
        print("[HOST] Leader Mode Running...")
        task.spawn(function()
            while true do
                if not IsInMatch then
                    local targetChapter, targetWorld, modeType = nil, nil, "Story"

                    -- หาด่านที่ยังไม่ผ่านของทุกคนในทีม
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

                    -- ถ้า Story ครบหมด -> เช็ค Sukuna (Calamity)
                    if not targetChapter and Config.CheckSukuna then
                        local missing = false
                        for _, j in ipairs(Config.Joiners) do
                            local d = PlayerData:FindFirstChild(j)
                            if d and d:FindFirstChild("Collection") and not d.Collection:FindFirstChild("Sukuna:") then
                                missing = true; break
                            end
                        end
                        if missing then
                            modeType, targetWorld, targetChapter = "Calamity", "Calamity", "Calamity_Chapter1"
                        end
                    end

                    -- เริ่มกระบวนการสร้างห้อง
                    if targetChapter then
                        warn("[HOST] Creating Room: " .. targetChapter)
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

                        -- รอจนทีมครบ
                        while not Utils.isTeamInRoom(fullTeam, Config.HostName) and not IsInMatch do
                            UI.StatusLabel.Text = "⏳ รอทีมเข้าห้อง: " .. targetChapter
                            task.wait(1.5)
                        end

                        -- Start Game
                        if Config.AutoSubmit and not IsInMatch then
                            print("[REMOTE] All Ready. Firing Start!")
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
        -- Logic สำหรับ Joiner
        task.spawn(function()
            print("[JOINER] Follower Mode Running...")
            while true do
                if not IsInMatch then
                    pcall(function()
                        local room = ReplicatedStorage.PlayRoom:FindFirstChild(Config.HostName)
                        if room and not Utils.isTeamInRoom({lp.Name}, Config.HostName) then
                            RemoteEvent:FireServer("Join-Room", { Room = room })
                        end
                    end)
                end
                task.wait(2)
            end
        end)
    end
end
