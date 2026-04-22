local UI = {}
local lp = game:GetService("Players").LocalPlayer

function UI.Setup()
    local playerGui = lp:FindFirstChild("PlayerGui") or lp:WaitForChild("PlayerGui", 15)
    if playerGui:FindFirstChild("AutoSystemGui") then playerGui.AutoSystemGui:Destroy() end

    local ScreenGui = Instance.new("ScreenGui", playerGui)
    ScreenGui.Name = "AutoSystemGui"
    ScreenGui.ResetOnSpawn = false
    ScreenGui.DisplayOrder = 999 -- บนสุดเสมอ

    local MainFrame = Instance.new("Frame", ScreenGui)
    MainFrame.BackgroundColor3 = Color3.fromRGB(15, 15, 20)
    MainFrame.Position = UDim2.new(0.5, -110, 0.02, 0) 
    MainFrame.Size = UDim2.new(0, 220, 0, 100)
    MainFrame.Active = true
    MainFrame.Draggable = true
    Instance.new("UICorner", MainFrame)

    UI.StatusLabel = Instance.new("TextLabel", MainFrame)
    UI.StatusLabel.Position = UDim2.new(0, 10, 0, 10)
    UI.StatusLabel.Size = UDim2.new(1, -20, 1, -20)
    UI.StatusLabel.BackgroundTransparency = 1
    UI.StatusLabel.Font = Enum.Font.Gotham
    UI.StatusLabel.TextColor3 = Color3.fromRGB(0, 255, 180)
    UI.StatusLabel.TextSize = 11
    UI.StatusLabel.TextWrapped = true
    UI.StatusLabel.Text = "System Ready..."

    return UI
end

return UI
