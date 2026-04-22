return function(Config, UI, Utils)
    local lp = game:GetService("Players").LocalPlayer
    local ReplicatedStorage = game:GetService("ReplicatedStorage")
    local RemoteEvent = ReplicatedStorage:WaitForChild("Remote"):WaitForChild("Server"):WaitForChild("PlayRoom"):WaitForChild("Event")
    local PlayerData = ReplicatedStorage:WaitForChild("Player_Data")
    
    -- สถานะเริ่มต้น: ให้ถือว่า "อยู่ในแมพ" ไว้ก่อนเพื่อความปลอดภัย
    local IsInMatch = true 

    print("[CORE] System V14 - Strict Logic Engine Started.")

    -- [[ 1. LOOP ตรวจจับสถานะ (Strict Monitor) ]] --
    task.spawn(function()
        while true do
            pcall(function()
                local playRoomFolder = ReplicatedStorage:FindFirstChild("PlayRoom")
                local hud = lp.PlayerGui:FindFirstChild("HUD")
                local rewardsUI = lp.PlayerGui:FindFirstChild("RewardsUI")
                
                -- เช็คว่า "อยู่ล็อบบี้จริงๆ" หรือไม่
                -- เงื่อนไข: ต้องมีโฟลเดอร์ PlayRoom และ "ไม่มี" HUD ของด่าน
                if playRoomFolder and (not hud or not hud.InGame.Visible) then
                    if IsInMatch then
                        print("[MONITOR] ล็อบบี้ตรวจพบ: พร้อมรับคำสั่งสร้างห้อง")
                        IsInMatch = false
                    end
                    UI.StatusLabel.Text = "📡 อยู่ล็อบบี้: รอระบบสแกนด่าน..."
                    UI.StatusLabel.TextColor3 = Color3.fromRGB(0, 255, 180)
                else
                    -- ถ้าไม่มี PlayRoom หรือมี HUD แสดงว่า "อยู่ในด่าน" หรือ "กำลังโหลด"
                    IsInMatch = true
                    
                    -- ตรวจสอบหน้าจอจบเกม (เฉพาะด่าน 5)
                    if rewardsUI and rewardsUI.Enabled then
                        local chapterTxt = rewardsUI.Main.LeftSide.Chapter.Text
                        local statusTxt = rewardsUI.Main.LeftSide.GameStatus.Text
                        
                        if string.find(chapterTxt, "Chapter 5") and string.find(statusTxt, "~ WON") then
                            UI.StatusLabel.Text = "🎉 จบด่าน 5! กำลังกด Leave..."
                            UI.StatusLabel.TextColor3 = Color3.fromRGB(255, 255, 0)
                            
                            task.wait(3)
                            local leaveBtn = rewardsUI.Main.LeftSide.Buttons:FindFirstChild("Leave")
                            if leaveBtn then
                                -- กด Leave
                                for _, sig in pairs({"Activated", "MouseButton1Click"}) do
                                    if leaveBtn:FindFirstChild(sig) or leaveBtn[sig] then
                                        for _, con in pairs(getconnections(leaveBtn[sig])) do con:Fire() end
                                    end
                                end
                            end
                        end
                    else
                        -- แสดงสถานะตาม HUD
                        local stageLabel = hud and hud.InGame.Main.GameInfo.Stage.Label
                        if stageLabel then
                            local txt = string.lower(stageLabel.Text)
                            if string.find(txt, "chapter") then
                                UI.StatusLabel.Text = "⚔️ กำลัง clear story ("..stageLabel.Text..")"
                                UI.StatusLabel.TextColor3 = Color3.fromRGB(0, 200, 255)
                            elseif string.find(txt, "shibuya") or string.find(txt, "calamity") then
                                UI.StatusLabel.Text = "🔥 กำลังหา sukuna"
                                UI.StatusLabel.TextColor3 = Color3.fromRGB(255, 80, 80)
                            end
                        end
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
        task.spawn(function()
            while true do
                -- กฎเหล็ก: ถ้า IsInMatch เป็น true ห้ามทำอะไรทั้งนั้น
                if not IsInMatch then
                    local targetChapter, targetWorld, modeType = nil, nil, "Story"

                    -- สแกนหาด่าน
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

                    -- สแกน Sukuna
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

                    -- สร้างห้อง (รันเฉพาะตอน IsInMatch == false เท่านั้น)
                    if targetChapter and not IsInMatch then
                        warn("[HOST] กำลังสร้างห้อง: " .. targetChapter)
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
                            UI.StatusLabel.Text = "⏳ รอทีมเข้า: " .. targetChapter
                            task.wait(2)
                        end

                        -- Start Game
                        if Config.AutoSubmit and not IsInMatch then
                            print("[REMOTE] เริ่มเกม!")
                            task.wait(Config.DelayTime)
                            RemoteEvent:FireServer("Start")
                            -- ล็อคสถานะทันทีหลังจากกดเริ่ม เพื่อไม่ให้ลูปมันทำงานซ้ำขณะกำลังวาร์ป
                            IsInMatch = true 
                            task.wait(10)
                        end
                    end
                end
                task.wait(3)
            end
        end)
    else
        -- Joiner Logic
        task.spawn(function()
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
