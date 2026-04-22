local Detector = {}
local lp = game:GetService("Players").LocalPlayer
local ReRunTriggered = false

function Detector.Start(Config, UI, Utils, CORE_URL)
    print("[DETECTOR] Monitoring Module Active.")
    
    task.spawn(function()
        while true do
            local success, err = pcall(function()
                local hud = lp.PlayerGui:FindFirstChild("HUD")
                local rewardsUI = lp.PlayerGui:FindFirstChild("RewardsUI")
                
                -- [[ A. ตรวจจับสถานะในด่าน (HUD) ]] --
                if hud and hud.InGame.Visible then
                    local stageLabel = hud.InGame.Main.GameInfo.Stage.Label
                    local txt = string.lower(stageLabel.Text)
                    
                    if string.find(txt, "chapter") then
                        UI.StatusLabel.Text = "⚔️ กำลัง clear story: " .. stageLabel.Text
                        UI.StatusLabel.TextColor3 = Color3.fromRGB(0, 200, 255)
                    elseif string.find(txt, "shibuya") or string.find(txt, "calamity") then
                        UI.StatusLabel.Text = "🔥 กำลังหา sukuna"
                        UI.StatusLabel.TextColor3 = Color3.fromRGB(255, 80, 80)
                    end
                end

                -- [[ B. ตรวจจับจบโลก (RewardsUI) ]] --
                if rewardsUI and rewardsUI.Enabled then
                    local chapterTxt = rewardsUI.Main.LeftSide.Chapter.Text
                    local statusTxt = rewardsUI.Main.LeftSide.GameStatus.Text
                    
                    -- ⭐ เมื่อเจอ Chapter 5 Finish
                    if string.find(chapterTxt, "Chapter 5") and string.find(statusTxt, "~ WON") then
                        if not ReRunTriggered then
                            ReRunTriggered = true
                            UI.StatusLabel.Text = "⭐ DETECTED: CHAPTER 5 CLEAR!\nกำลัง Rerun ระบบ..."
                            UI.StatusLabel.TextColor3 = Color3.fromRGB(255, 215, 0)
                            warn("[DETECTOR] World Clear! Re-executing Core Logic...")

                            -- 1. กด Leave
                            task.wait(3)
                            local leaveBtn = rewardsUI.Main.LeftSide.Buttons:FindFirstChild("Leave")
                            if leaveBtn then
                                for _, sig in pairs({"Activated", "MouseButton1Click"}) do
                                    if leaveBtn:FindFirstChild(sig) or leaveBtn[sig] then
                                        for _, con in pairs(getconnections(leaveBtn[sig])) do con:Fire() end
                                    end
                                end
                            end

                            -- 2. รีโหลด Core ใหม่จาก GitHub
                            task.wait(2)
                            local content = game:HttpGet(CORE_URL)
                            if content then
                                local func = loadstring(content)()
                                task.spawn(function() func(Config, UI, Utils) end)
                            end
                        end
                    end
                else
                    -- รีเซ็ต Trigger เมื่อ Rewards ปิด (กลับล็อบบี้)
                    ReRunTriggered = false
                end
            end)
            if not success then print("[DETECTOR ERROR] " .. err) end
            task.wait(1.5)
        end
    end)
end

return Detector
