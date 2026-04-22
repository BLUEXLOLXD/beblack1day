local Detector = {}
local lp = game:GetService("Players").LocalPlayer
local ReRunTriggered = false

function Detector.Start(Config, UI, Utils, CORE_URL)
    print("[DETECTOR] Watchdog Module Started.")
    
    task.spawn(function()
        while true do
            pcall(function()
                local rewardsUI = lp.PlayerGui:FindFirstChild("RewardsUI")
                
                if rewardsUI and rewardsUI.Enabled then
                    local chapterTxt = rewardsUI.Main.LeftSide.Chapter.Text
                    local statusTxt = rewardsUI.Main.LeftSide.GameStatus.Text
                    
                    -- ⭐ เงื่อนไข: DETECTED: CHAPTER 5 CLEAR
                    if string.find(chapterTxt, "Chapter 5") and string.find(statusTxt, "~ WON") then
                        if not ReRunTriggered then
                            ReRunTriggered = true 
                            warn("⭐ [DETECTOR] Chapter 5 Finished! Re-running Core Logic...")
                            
                            if UI and UI.StatusLabel then
                                UI.StatusLabel.Text = "🎉 Chapter 5 Clear! Re-loading Core..."
                                UI.StatusLabel.TextColor3 = Color3.fromRGB(255, 215, 0)
                            end

                            -- 1. กด Leave อัตโนมัติ (ใส่เพิ่มเพื่อความลื่นไหล)
                            task.wait(3)
                            local leaveBtn = rewardsUI.Main.LeftSide.Buttons:FindFirstChild("Leave")
                            if leaveBtn then
                                for _, sig in pairs({"Activated", "MouseButton1Click"}) do
                                    if leaveBtn:FindFirstChild(sig) or leaveBtn[sig] then
                                        for _, con in pairs(getconnections(leaveBtn[sig])) do con:Fire() end
                                    end
                                end
                            end

                            -- 2. ดึง Core_Logic ตัวล่าสุดมา Re-run
                            task.wait(2)
                            local success, content = pcall(function() return game:HttpGet(CORE_URL) end)
                            if success and content ~= "" then
                                local CoreFunc = loadstring(content)()
                                if type(CoreFunc) == "function" then
                                    task.spawn(function()
                                        CoreFunc(Config, UI, Utils)
                                    end)
                                    print("🚀 [DETECTOR] Core_Logic Re-executed.")
                                end
                            end
                        end
                    end
                else
                    -- รีเซ็ตสถานะเมื่อ RewardsUI ปิดลง (เช่น เมื่อถึงล็อบบี้)
                    ReRunTriggered = false
                end
            end)
            task.wait(2)
        end
    end)
end

return Detector
