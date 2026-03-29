local lucide = loadstring(game:HttpGet("https://raw.githubusercontent.com/xxpwnxxx420lord/Lucide.Lua/refs/heads/main/lucide.lua", true))()

local icon = lucide:geticon("arrow-right", {
	size = 48,
	color = "#ffffff",
	stroke_width = 1.5,
})

local screenGui = Instance.new("ScreenGui")
screenGui.ResetOnSpawn = false
screenGui.Parent = game.CoreGui
print("made at "..screenGui:GetFullName())

local imageLabel = Instance.new("ImageLabel")
imageLabel.Image = icon
print('print set image to'..icon)
imageLabel.Size = UDim2.new(0, 48, 0, 48)
imageLabel.Position = UDim2.new(0.5, -24, 0.5, -24)
imageLabel.BackgroundTransparency = 1
imageLabel.ScaleType = Enum.ScaleType.Fit
imageLabel.Parent = screenGui
print("made at "..imageLabel:GetFullName())
