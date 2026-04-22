local UI = {}
local lp = game:GetService("Players").LocalPlayer

function UI.Setup()
    print("[UI] Setting up Graphical Interface...")
    local playerGui = lp:FindFirstChild("PlayerGui") or lp:WaitForChild("PlayerGui", 15)
    if not playerGui then warn("[UI] Fail: PlayerGui not found.") return nil end

    -- ลบ GUI เก่าถ้ามี
    if playerGui:FindFirstChild("AutoSystemGui") then playerGui.AutoSystemGui:Destroy() end

    local ScreenGui = Instance.new("ScreenGui", playerGui)
    ScreenGui.Name = "AutoSystemGui"
    ScreenGui.ResetOnSpawn = false

    local MainFrame = Instance.new("Frame", ScreenGui)
    MainFrame.BackgroundColor3 = Color3.fromRGB(15, 15, 20)
    MainFrame.Position = UDim2.new(0.5, -110, 0.02, 0) 
    MainFrame.Size = UDim2.new(0, 220, 0, 100)
    Instance.new("UICorner", MainFrame)

    local Title = Instance.new("TextLabel", MainFrame)
    Title.Size = UDim2.new(1, 0, 0, 30)
    Title.BackgroundTransparency = 1
    Title.Font = Enum.Font.GothamBold
    Title.TextColor3 = Color3.fromRGB(255, 255, 255)
    Title.TextSize = 13
    Title.Text = "SYSTEM MONITOR V11"

    UI.StatusLabel = Instance.new("TextLabel", MainFrame)
    UI.StatusLabel.Position = UDim2.new(0, 10, 0, 35)
    UI.StatusLabel.Size = UDim2.new(1, -20, 0, 55)
    UI.StatusLabel.BackgroundTransparency = 1
    UI.StatusLabel.Font = Enum.Font.Gotham
    UI.StatusLabel.TextColor3 = Color3.fromRGB(0, 255, 180)
    UI.StatusLabel.TextSize = 10
    UI.StatusLabel.TextWrapped = true
    UI.StatusLabel.Text = "Ready to work..."

    print("[UI] Setup Complete.")
    return UI
end

return UI
