local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("SkyboundRemotes")
local statusEvent = remotes:WaitForChild("Status")
local crewMateEvent = remotes:WaitForChild("ChooseCrewMate")
local guideEvent = remotes:WaitForChild("OpenIslandGuide")
local returnHomeEvent = remotes:WaitForChild("ReturnToHarbor")
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Theme = Config.Theme
local HudUi = require(script.Parent:WaitForChild("HudUi"))
local addCorner = HudUi.addCorner
local addStroke = HudUi.addStroke
local text = HudUi.text
local scaleForViewport = HudUi.scaleForViewport

local gui = Instance.new("ScreenGui")
gui.Name = "SkyboundHud"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 10
gui.Parent = player:WaitForChild("PlayerGui")

local function makePanel(name, position, size)
    return HudUi.makePanel(gui, Theme, name, position, size)
end

-- Bottom-center keeps the always-useful game state clear of Roblox chat.
-- Deeper progress still lives behind Journey.
local statusBar = makePanel("StatusBar", UDim2.new(0.5, 0, 1, -20), UDim2.fromOffset(574, 66))
statusBar.AnchorPoint = Vector2.new(0.5, 1)
scaleForViewport(statusBar, 574, 0.6)
-- Persistent but separate from gameplay toasts: Studio fallback never saves.
local sessionNotice = Instance.new("TextLabel")
sessionNotice.Name = "SessionOnlyNotice"
sessionNotice.AnchorPoint = Vector2.new(0.5, 1)
sessionNotice.Position = UDim2.new(0.5, 0, 1, -2)
sessionNotice.Size = UDim2.new(0.9, 0, 0, 16)
sessionNotice.BackgroundTransparency = 1
sessionNotice.Font = Enum.Font.GothamBold
sessionNotice.TextSize = 10
sessionNotice.TextColor3 = Theme.Gold
sessionNotice.TextStrokeTransparency = 0.4
sessionNotice.Text = "STUDIO TEST • PROGRESS WILL NOT SAVE"
sessionNotice.Visible = false
sessionNotice.Parent = gui
local function updateSessionNotice()
    sessionNotice.Visible = player:GetAttribute("ProgressSessionOnly") == true
end
player:GetAttributeChangedSignal("ProgressSessionOnly"):Connect(updateSessionNotice)
updateSessionNotice()
local statusGradient = Instance.new("UIGradient")
statusGradient.Color = ColorSequence.new(Theme.PanelRaised, Theme.Panel)
statusGradient.Rotation = 90
statusGradient.Parent = statusBar

text(statusBar, "SALVAGE", UDim2.fromOffset(16, 8), UDim2.fromOffset(76, 12), Enum.Font.GothamBold, 9, Theme.Muted)
local salvageValue = text(statusBar, "0", UDim2.fromOffset(16, 21), UDim2.fromOffset(82, 30), Enum.Font.GothamBlack, 22, Theme.Gold)

local divider = Instance.new("Frame")
divider.Position = UDim2.fromOffset(108, 13)
divider.Size = UDim2.fromOffset(1, 40)
divider.BackgroundColor3 = Theme.Border
divider.BackgroundTransparency = 0.6
divider.Parent = statusBar

text(statusBar, "EXPLORER RANK", UDim2.fromOffset(124, 10), UDim2.fromOffset(88, 12), Enum.Font.GothamBold, 9, Theme.Muted)
local rankValue = text(statusBar, "RANK 1", UDim2.fromOffset(124, 25), UDim2.fromOffset(88, 20), Enum.Font.GothamBold, 13, Theme.Gold)

local rankDivider = Instance.new("Frame")
rankDivider.Position = UDim2.fromOffset(220, 13)
rankDivider.Size = UDim2.fromOffset(1, 40)
rankDivider.BackgroundColor3 = Theme.Border
rankDivider.BackgroundTransparency = 0.6
rankDivider.Parent = statusBar

text(statusBar, "HARBOR LEVEL", UDim2.fromOffset(236, 10), UDim2.fromOffset(86, 12), Enum.Font.GothamBold, 9, Theme.Muted)
local harborValue = text(statusBar, "LEVEL 1", UDim2.fromOffset(236, 25), UDim2.fromOffset(86, 20), Enum.Font.GothamBold, 13, Theme.Text)

local mateDivider = Instance.new("Frame")
mateDivider.Position = UDim2.fromOffset(334, 13)
mateDivider.Size = UDim2.fromOffset(1, 40)
mateDivider.BackgroundColor3 = Theme.Border
mateDivider.BackgroundTransparency = 0.6
mateDivider.Parent = statusBar

text(statusBar, "CREW MATE", UDim2.fromOffset(350, 10), UDim2.fromOffset(100, 12), Enum.Font.GothamBold, 9, Theme.Muted)
local mateValue = text(statusBar, "CHOOSE ONE", UDim2.fromOffset(350, 25), UDim2.fromOffset(112, 20), Enum.Font.GothamBold, 13, Theme.Text)

local journeyButton = Instance.new("TextButton")
journeyButton.Name = "JourneyButton"
journeyButton.AnchorPoint = Vector2.new(1, 0.5)
journeyButton.Position = UDim2.new(1, -12, 0.5, 0)
journeyButton.Size = UDim2.fromOffset(86, 36)
journeyButton.BackgroundColor3 = Theme.Aqua
journeyButton.BackgroundTransparency = 0.82
journeyButton.Font = Enum.Font.GothamBold
journeyButton.Text = "JOURNEY"
journeyButton.TextColor3 = Theme.Aqua
journeyButton.TextSize = 9
journeyButton.AutoButtonColor = false
journeyButton.Parent = statusBar
addCorner(journeyButton, 9)
local journeyStroke = addStroke(journeyButton, Theme.Aqua, 0.48)
local journeyAlert = Instance.new("Frame")
journeyAlert.Name = "ReadyAction"
journeyAlert.AnchorPoint = Vector2.new(0.5, 0.5)
journeyAlert.Position = UDim2.new(1, -1, 0, 1)
journeyAlert.Size = UDim2.fromOffset(9, 9)
journeyAlert.BackgroundColor3 = Theme.Gold
journeyAlert.Visible = false
journeyAlert.ZIndex = 2
journeyAlert.Parent = journeyButton
addCorner(journeyAlert, 5)
addStroke(journeyAlert, Theme.Text, 0.25)

local chainChip = Instance.new("Frame")
chainChip.Name = "DiscoveryChain"
chainChip.AnchorPoint = Vector2.new(0.5, 1)
chainChip.Position = UDim2.new(0.5, 0, 1, -96)
chainChip.Size = UDim2.fromOffset(180, 30)
chainChip.BackgroundColor3 = Theme.Mint
chainChip.BackgroundTransparency = 0.12
chainChip.Visible = false
chainChip.Parent = gui
addCorner(chainChip, 10)
local chainStroke = addStroke(chainChip, Theme.Text, 0.62)
local chainValue = text(chainChip, "DISCOVERY CHAIN", UDim2.fromOffset(10, 4), UDim2.new(1, -20, 0, 22), Enum.Font.GothamBold, 10, Theme.Ink, Enum.TextXAlignment.Center)

local drawer = makePanel("JourneyDrawer", UDim2.new(0.5, 0, 1, -96), UDim2.fromOffset(360, 245))
drawer.AnchorPoint = Vector2.new(0.5, 1)
scaleForViewport(drawer, 360, 0.82)
drawer.Visible = false
local drawerGradient = Instance.new("UIGradient")
drawerGradient.Color = ColorSequence.new(Theme.PanelRaised, Theme.Panel)
drawerGradient.Rotation = 90
drawerGradient.Parent = drawer

text(drawer, "JOURNEY", UDim2.fromOffset(16, 12), UDim2.fromOffset(110, 20), Enum.Font.GothamBlack, 16, Theme.Text)
local journeySubtitle = text(drawer, "PROGRESS & DISCOVERY", UDim2.fromOffset(16, 31), UDim2.fromOffset(210, 13), Enum.Font.GothamBold, 9, Theme.Muted)

local guideButton = Instance.new("TextButton")
guideButton.Name = "IslandGuideScroll"
guideButton.AnchorPoint = Vector2.new(1, 0.5)
guideButton.Position = UDim2.new(1, -22, 0.5, 0)
guideButton.Size = UDim2.fromOffset(82, 112)
guideButton.BackgroundColor3 = Color3.fromRGB(237, 211, 151)
guideButton.BackgroundTransparency = 0.03
guideButton.Font = Enum.Font.GothamBold
guideButton.Text = "ISLAND\nGUIDE"
guideButton.TextColor3 = Theme.Ink
guideButton.TextSize = 12
guideButton.TextWrapped = true
guideButton.AutoButtonColor = false
guideButton.ZIndex = 12
guideButton.Parent = gui
addCorner(guideButton, 8)
addStroke(guideButton, Color3.fromRGB(126, 83, 42), 0.12)

local parchmentGradient = Instance.new("UIGradient")
parchmentGradient.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0, Color3.fromRGB(185, 133, 72)),
    ColorSequenceKeypoint.new(0.18, Color3.fromRGB(245, 224, 169)),
    ColorSequenceKeypoint.new(0.82, Color3.fromRGB(235, 205, 141)),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(168, 112, 59)),
})
parchmentGradient.Rotation = 90
parchmentGradient.Parent = guideButton

local topRoll = Instance.new("Frame")
topRoll.AnchorPoint = Vector2.new(0.5, 0.5)
topRoll.Position = UDim2.new(0.5, 0, 0, 2)
topRoll.Size = UDim2.new(1, -8, 0, 12)
topRoll.BackgroundColor3 = Color3.fromRGB(183, 132, 73)
topRoll.ZIndex = 13
topRoll.Parent = guideButton
addCorner(topRoll, 6)

local bottomRoll = Instance.new("Frame")
bottomRoll.AnchorPoint = Vector2.new(0.5, 0.5)
bottomRoll.Position = UDim2.new(0.5, 0, 1, -2)
bottomRoll.Size = UDim2.new(1, -8, 0, 12)
bottomRoll.BackgroundColor3 = Color3.fromRGB(183, 132, 73)
bottomRoll.ZIndex = 13
bottomRoll.Parent = guideButton
addCorner(bottomRoll, 6)

for index, y in ipairs({ 36, 73 }) do
    local inkLine = Instance.new("Frame")
    inkLine.Position = UDim2.fromOffset(14, y)
    inkLine.Size = UDim2.new(1, -28, 0, 1)
    inkLine.BackgroundColor3 = Color3.fromRGB(126, 83, 42)
    inkLine.BackgroundTransparency = 0.58
    inkLine.ZIndex = 13
    inkLine.Parent = guideButton
end

local compassSeal = Instance.new("TextLabel")
compassSeal.AnchorPoint = Vector2.new(0.5, 0.5)
compassSeal.Position = UDim2.new(0.5, 0, 0.5, 0)
compassSeal.Size = UDim2.fromOffset(24, 24)
compassSeal.BackgroundColor3 = Color3.fromRGB(145, 61, 47)
compassSeal.Text = "✦"
compassSeal.TextColor3 = Color3.fromRGB(255, 228, 174)
compassSeal.Font = Enum.Font.GothamBlack
compassSeal.TextSize = 14
compassSeal.ZIndex = 14
compassSeal.Parent = guideButton
addCorner(compassSeal, 12)

local closeButton = Instance.new("TextButton")
closeButton.AnchorPoint = Vector2.new(1, 0)
closeButton.Position = UDim2.new(1, -12, 0, 10)
closeButton.Size = UDim2.fromOffset(28, 28)
closeButton.BackgroundColor3 = Theme.Ink
closeButton.BackgroundTransparency = 0.45
closeButton.Text = "×"
closeButton.TextColor3 = Theme.Muted
closeButton.Font = Enum.Font.GothamBold
closeButton.TextSize = 20
closeButton.AutoButtonColor = false
closeButton.Parent = drawer
addCorner(closeButton, 8)

local homeButton = Instance.new("TextButton")
homeButton.Name = "ReturnHome"
homeButton.AnchorPoint = Vector2.new(1, 0)
homeButton.Position = UDim2.new(1, -48, 0, 11)
homeButton.Size = UDim2.fromOffset(46, 26)
homeButton.BackgroundColor3 = Theme.Mint
homeButton.BackgroundTransparency = 0.75
homeButton.BorderSizePixel = 0
homeButton.Text = "HOME"
homeButton.TextColor3 = Theme.Mint
homeButton.Font = Enum.Font.GothamBold
homeButton.TextSize = 8
homeButton.AutoButtonColor = false
homeButton.Parent = drawer
addCorner(homeButton, 8)
addStroke(homeButton, Theme.Mint, 0.45)

local drawerLine = Instance.new("Frame")
drawerLine.Position = UDim2.fromOffset(16, 53)
drawerLine.Size = UDim2.new(1, -32, 0, 1)
drawerLine.BackgroundColor3 = Theme.Border
drawerLine.BackgroundTransparency = 0.62
drawerLine.Parent = drawer

local function drawerRow(y, title, accent)
    local marker = Instance.new("Frame")
    marker.Position = UDim2.fromOffset(16, y + 7)
    marker.Size = UDim2.fromOffset(3, 11)
    marker.BackgroundColor3 = accent
    marker.Parent = drawer
    addCorner(marker, 2)
    text(drawer, title, UDim2.fromOffset(28, y), UDim2.fromOffset(120, 24), Enum.Font.GothamBold, 10, Theme.Muted)
    return text(drawer, "—", UDim2.fromOffset(153, y), UDim2.new(1, -169, 0, 24), Enum.Font.GothamBold, 12, Theme.Text, Enum.TextXAlignment.Right)
end

local contractValue = drawerRow(65, "CONTRACT", Theme.Mint)
local collectionValue = drawerRow(91, "COLLECTION", Theme.Violet)
local crewValue = drawerRow(117, "CREW", Theme.Aqua)
local rankDetailValue = drawerRow(143, "EXPLORER", Theme.Gold)

local function drawerProgress(y, color)
    local track = Instance.new("Frame")
    track.Position = UDim2.fromOffset(28, y)
    track.Size = UDim2.new(1, -44, 0, 3)
    track.BackgroundColor3 = Theme.Ink
    track.BackgroundTransparency = 0.42
    track.Parent = drawer
    addCorner(track, 2)
    local fill = Instance.new("Frame")
    fill.Size = UDim2.fromScale(0, 1)
    fill.BackgroundColor3 = color
    fill.Parent = track
    addCorner(fill, 2)
    return fill
end

local contractProgressFill = drawerProgress(87, Theme.Mint)
local explorerProgressFill = drawerProgress(165, Theme.Gold)

local objective = Instance.new("Frame")
objective.Position = UDim2.fromOffset(16, 174)
objective.Size = UDim2.new(1, -32, 0, 54)
objective.BackgroundColor3 = Theme.Ink
objective.BackgroundTransparency = 0.3
objective.Parent = drawer
addCorner(objective, 10)
addStroke(objective, Theme.Border, 0.72)
text(objective, "NEXT UP", UDim2.fromOffset(10, 5), UDim2.fromOffset(80, 12), Enum.Font.GothamBold, 9, Theme.Muted)
local objectiveValue = text(objective, "Recover salvage at the Whispering Wreck", UDim2.fromOffset(10, 19), UDim2.new(1, -96, 0, 29), Enum.Font.GothamMedium, 10, Theme.Text)
objectiveValue.TextWrapped = true

local objectiveAction = Instance.new("TextButton")
objectiveAction.Name = "ObjectiveReturn"
objectiveAction.AnchorPoint = Vector2.new(1, 1)
objectiveAction.Position = UDim2.new(1, -9, 1, -9)
objectiveAction.Size = UDim2.fromOffset(68, 22)
objectiveAction.BackgroundColor3 = Theme.Mint
objectiveAction.BackgroundTransparency = 0.14
objectiveAction.BorderSizePixel = 0
objectiveAction.Font = Enum.Font.GothamBold
objectiveAction.Text = "RETURN"
objectiveAction.TextColor3 = Theme.Ink
objectiveAction.TextSize = 8
objectiveAction.AutoButtonColor = false
objectiveAction.Visible = false
objectiveAction.Parent = objective
addCorner(objectiveAction, 7)
addStroke(objectiveAction, Theme.Text, 0.58)

local toast = Instance.new("TextLabel")
toast.AnchorPoint = Vector2.new(0.5, 0)
toast.Position = UDim2.new(0.5, 0, 0, 22)
toast.Size = UDim2.fromOffset(490, 40)
toast.BackgroundColor3 = Theme.Ink
toast.BackgroundTransparency = 1
toast.Font = Enum.Font.GothamBold
toast.Text = ""
toast.TextColor3 = Theme.Text
toast.TextSize = 14
toast.TextTransparency = 1
toast.TextXAlignment = Enum.TextXAlignment.Center
toast.Parent = gui
addCorner(toast, 12)
local toastStroke = addStroke(toast, Theme.Aqua, 0.45)
scaleForViewport(toast, 490, 0.62)

-- Rank-ups deserve a calm, unmistakable moment. It is deliberately separate
-- from the short status toast so the player sees the lasting reward.
local rankBanner = Instance.new("Frame")
rankBanner.Name = "RankUp"
rankBanner.AnchorPoint = Vector2.new(0.5, 0)
rankBanner.Position = UDim2.new(0.5, 0, 0.11, 0)
rankBanner.Size = UDim2.fromOffset(292, 76)
rankBanner.BackgroundColor3 = Theme.Ink
rankBanner.BackgroundTransparency = 1
rankBanner.Visible = false
rankBanner.ZIndex = 9
rankBanner.Parent = gui
addCorner(rankBanner, 14)
local rankBannerStroke = addStroke(rankBanner, Theme.Gold, 1)
scaleForViewport(rankBanner, 292, 0.7)

local rankKicker = text(rankBanner, "RANK UP", UDim2.fromOffset(12, 8), UDim2.new(1, -24, 0, 15), Enum.Font.GothamBold, 10, Theme.Gold, Enum.TextXAlignment.Center)
rankKicker.ZIndex = 10
rankKicker.TextTransparency = 1
local rankName = text(rankBanner, "WAYFINDER  •  RANK 3", UDim2.fromOffset(12, 25), UDim2.new(1, -24, 0, 21), Enum.Font.GothamBlack, 16, Theme.Text, Enum.TextXAlignment.Center)
rankName.ZIndex = 10
rankName.TextTransparency = 1
local rankBonus = text(rankBanner, "+4% PERMANENT SALVAGE", UDim2.fromOffset(12, 48), UDim2.new(1, -24, 0, 15), Enum.Font.GothamBold, 10, Theme.Mint, Enum.TextXAlignment.Center)
rankBonus.ZIndex = 10
rankBonus.TextTransparency = 1

local beaconNotice = Instance.new("TextLabel")
beaconNotice.Name = "RescueBeaconReady"
beaconNotice.AnchorPoint = Vector2.new(0.5, 0)
beaconNotice.Position = UDim2.new(0.5, 0, 0.24, 0)
beaconNotice.Size = UDim2.fromOffset(268, 42)
beaconNotice.BackgroundColor3 = Theme.Violet:Lerp(Theme.Ink, 0.3)
beaconNotice.BackgroundTransparency = 1
beaconNotice.Font = Enum.Font.GothamBlack
beaconNotice.Text = "RESCUE BEACON READY  •  RETURN HOME"
beaconNotice.TextColor3 = Theme.Text
beaconNotice.TextSize = 11
beaconNotice.TextTransparency = 1
beaconNotice.Visible = false
beaconNotice.ZIndex = 9
beaconNotice.Parent = gui
addCorner(beaconNotice, 12)
local beaconNoticeStroke = addStroke(beaconNotice, Theme.Violet, 1)
scaleForViewport(beaconNotice, 268, 0.7)

local function setDrawerOpen(isOpen)
    drawer.Visible = isOpen
    journeyButton.Text = isOpen and "CLOSE" or "JOURNEY"
    journeyButton.BackgroundTransparency = isOpen and 0.62 or 0.82
    chainChip.Visible = not isOpen and (remotes:GetAttribute("StormActive") or (player:GetAttribute("DiscoveryChain") or 0) >= 2)
end

journeyButton.Activated:Connect(function()
    setDrawerOpen(not drawer.Visible)
end)
closeButton.Activated:Connect(function()
    setDrawerOpen(false)
end)

homeButton.Activated:Connect(function()
    returnHomeEvent:FireServer()
    setDrawerOpen(false)
end)

objectiveAction.Activated:Connect(function()
    returnHomeEvent:FireServer()
    setDrawerOpen(false)
end)

local guideOverlay = Instance.new("Frame")
guideOverlay.Name = "IslandGuide"
guideOverlay.Size = UDim2.fromScale(1, 1)
guideOverlay.BackgroundColor3 = Theme.Ink
guideOverlay.BackgroundTransparency = 0.16
guideOverlay.Visible = false
guideOverlay.ZIndex = 30
guideOverlay.Parent = gui

local guidePanel = Instance.new("Frame")
guidePanel.AnchorPoint = Vector2.new(0.5, 0.5)
guidePanel.Position = UDim2.fromScale(0.5, 0.5)
guidePanel.Size = UDim2.fromScale(0.9, 0.9)
guidePanel.BackgroundColor3 = Theme.Panel
guidePanel.ZIndex = 31
guidePanel.Parent = guideOverlay
addCorner(guidePanel, 18)
addStroke(guidePanel, Theme.Border, 0.2)
local guideSizeConstraint = Instance.new("UISizeConstraint")
guideSizeConstraint.MaxSize = Vector2.new(640, 448)
guideSizeConstraint.Parent = guidePanel

local guideGradient = Instance.new("UIGradient")
guideGradient.Color = ColorSequence.new(Theme.PanelRaised, Theme.Panel)
guideGradient.Rotation = 90
guideGradient.Parent = guidePanel

local guideContent = Instance.new("ScrollingFrame")
guideContent.Name = "GuideExplanations"
guideContent.Position = UDim2.fromOffset(12, 62)
guideContent.Size = UDim2.new(1, -24, 1, -130)
guideContent.BackgroundTransparency = 1
guideContent.BorderSizePixel = 0
guideContent.ScrollBarThickness = 5
guideContent.ScrollBarImageColor3 = Theme.Aqua
guideContent.ScrollingDirection = Enum.ScrollingDirection.Y
guideContent.AutomaticCanvasSize = Enum.AutomaticSize.Y
guideContent.CanvasSize = UDim2.fromOffset(0, 0)
guideContent.ZIndex = 32
guideContent.Parent = guidePanel
local guideLayout = Instance.new("UIListLayout")
guideLayout.SortOrder = Enum.SortOrder.LayoutOrder
guideLayout.Padding = UDim.new(0, 12)
guideLayout.Parent = guideContent
local guidePadding = Instance.new("UIPadding")
guidePadding.PaddingLeft = UDim.new(0, 8)
guidePadding.PaddingBottom = UDim.new(0, 12)
guidePadding.Parent = guideContent

local guideEntries = {}
local function guideText(value, y, height, font, textSize, color)
    local label = Instance.new("TextLabel")
    label.BackgroundTransparency = 1
    label.LayoutOrder = y
    label.Size = UDim2.new(1, -24, 0, height)
    label.AutomaticSize = Enum.AutomaticSize.Y
    label.Font = font
    label.Text = value
    label.TextColor3 = color
    label.TextSize = textSize
    label.TextWrapped = true
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.TextYAlignment = Enum.TextYAlignment.Center
    label.ZIndex = 32
    label.Parent = guideContent
    table.insert(guideEntries, label)
    return label
end

guideText("ISLAND GUIDE", 18, 25, Enum.Font.GothamBlack, 19, Theme.Text)
guideText("Keyboard: G for guide, J for Journey. Controller: B to close a panel.", 43, 18, Enum.Font.GothamMedium, 11, Theme.Muted)
guideText("SALVAGE, RANK & DANGER  •  Recover crates for salvage and Explorer XP. Guardians hit harder in later skies, but their prizes rise too.", 82, 32, Enum.Font.GothamMedium, 11, Theme.Text)
guideText("CONTRACTS  •  Every 8 regular crates completes a contract and earns a rescue beacon.", 124, 32, Enum.Font.GothamMedium, 11, Theme.Text)
guideText("SANCTUARY  •  At your harbor, spend rescue beacons to welcome Skylings. Every 2 adds bonus salvage, up to +3.", 166, 40, Enum.Font.GothamMedium, 11, Theme.Text)
guideText("HARBOR & LOG  •  Upgrade at the Uplink to chart new islands. Claim your Captain's Log each day to grow a salvage streak.", 216, 40, Enum.Font.GothamMedium, 11, Theme.Text)
guideText("CREW TRAINING & BATTLE  •  Train for +1 salvage per tier. Rook can strike during a charge to cancel it (8s cooldown per guardian). Luma takes less damage; Briggs earns larger guardian prizes.", 266, 40, Enum.Font.GothamMedium, 11, Theme.Text)
guideText("CREW EXPEDITION  •  Join up to 3 deckhands at the wreck. Recover crates for shared rewards; stay near guardians for assist payouts.", 312, 36, Enum.Font.GothamMedium, 11, Theme.Text)
guideText("SKYWAYS & GATES  •  Walk freely between Harbors and the Wreck. Visit friends through the Directory; Level 2 / 4 gates reach tougher skies.", 356, 32, Enum.Font.GothamMedium, 11, Theme.Text)

local mapPage = Instance.new("ScrollingFrame")
mapPage.Name = "SkyMap"
mapPage.Position = UDim2.fromOffset(20, 62)
mapPage.Size = UDim2.new(1, -40, 1, -130)
mapPage.BorderSizePixel = 0
mapPage.ScrollBarThickness = 5
mapPage.ScrollBarImageColor3 = Theme.Aqua
mapPage.ScrollingDirection = Enum.ScrollingDirection.Y
mapPage.CanvasSize = UDim2.fromOffset(0, 350)
mapPage.BackgroundTransparency = 1
mapPage.Visible = false
mapPage.ZIndex = 32
mapPage.Parent = guidePanel

local mapTitle = Instance.new("TextLabel")
mapTitle.BackgroundTransparency = 1
mapTitle.Size = UDim2.new(1, 0, 0, 26)
mapTitle.Font = Enum.Font.GothamBlack
mapTitle.Text = "SKY MAP"
mapTitle.TextColor3 = Theme.Text
mapTitle.TextSize = 19
mapTitle.TextXAlignment = Enum.TextXAlignment.Left
mapTitle.ZIndex = 33
mapTitle.Parent = mapPage

local mapSubhead = Instance.new("TextLabel")
mapSubhead.BackgroundTransparency = 1
mapSubhead.Position = UDim2.fromOffset(0, 25)
mapSubhead.Size = UDim2.new(1, -8, 0, 48)
mapSubhead.TextWrapped = true
mapSubhead.Font = Enum.Font.GothamMedium
mapSubhead.Text = "Raise your Harbor Level, then use home routes to find Ancient Caches."
mapSubhead.TextColor3 = Theme.Muted
mapSubhead.TextSize = 11
mapSubhead.TextXAlignment = Enum.TextXAlignment.Left
mapSubhead.ZIndex = 33
mapSubhead.Parent = mapPage

local route = Instance.new("Frame")
route.Position = UDim2.fromOffset(27, 107)
route.Size = UDim2.fromOffset(2, 180)
route.BackgroundColor3 = Theme.Border
route.BackgroundTransparency = 0.4
route.ZIndex = 33
route.Parent = mapPage

local mapNodes = {}
for index, biome in ipairs(Config.Biomes) do
    local y = 87 + ((index - 1) * 86)
    local node = Instance.new("Frame")
    node.AnchorPoint = Vector2.new(0.5, 0.5)
    node.Position = UDim2.fromOffset(28, y + 14)
    node.Size = UDim2.fromOffset(22, 22)
    node.BackgroundColor3 = biome.Color
    node.ZIndex = 34
    node.Parent = mapPage
    addCorner(node, 11)
    addStroke(node, Theme.Text, 0.42)

    local card = Instance.new("Frame")
    card.Position = UDim2.fromOffset(52, y)
    card.Size = UDim2.new(1, -52, 0, 65)
    card.BackgroundColor3 = Theme.Ink
    card.BackgroundTransparency = 0.32
    card.ZIndex = 33
    card.Parent = mapPage
    addCorner(card, 10)
    addStroke(card, Theme.Border, 0.68)

    local name = text(card, biome.Name:upper(), UDim2.fromOffset(12, 7), UDim2.new(1, -24, 0, 18), Enum.Font.GothamBold, 12, Theme.Text)
    name.ZIndex = 34
    name.TextScaled = true
    local nameLimit = Instance.new("UITextSizeConstraint")
    nameLimit.MaxTextSize = 12
    nameLimit.Parent = name
    local state = text(card, "", UDim2.fromOffset(12, 27), UDim2.new(1, -24, 0, 30), Enum.Font.GothamMedium, 9, Theme.Muted)
    state.TextWrapped = true
    state.ZIndex = 34
    mapNodes[index] = { Node = node, State = state, Biome = biome }
end

local mapButton = Instance.new("TextButton")
mapButton.AnchorPoint = Vector2.new(1, 0)
mapButton.Position = UDim2.new(1, -22, 0, 10)
mapButton.Size = UDim2.fromOffset(86, 44)
mapButton.BackgroundColor3 = Theme.Aqua
mapButton.BackgroundTransparency = 0.8
mapButton.Font = Enum.Font.GothamBold
mapButton.Text = "SKY MAP"
mapButton.TextColor3 = Theme.Aqua
mapButton.TextSize = 8
mapButton.AutoButtonColor = false
mapButton.ZIndex = 34
mapButton.Parent = guidePanel
addCorner(mapButton, 7)

local mapOpen = false
local function refreshSkyMap(harborLevel)
    for _, entry in ipairs(mapNodes) do
        local unlocked = harborLevel >= entry.Biome.RequiredHarborLevel
        entry.Node.BackgroundColor3 = unlocked and entry.Biome.Color or Theme.Slate
        entry.State.Text = unlocked and ("OPEN • HOME ROUTE\nCRATES +" .. entry.Biome.SalvageValue .. " • CACHE +" .. (entry.Biome.SalvageValue * 4)) or ("LOCKED • HARBOR LEVEL " .. entry.Biome.RequiredHarborLevel)
        entry.State.TextColor3 = unlocked and Theme.Mint or Theme.Muted
    end
end

local function setMapOpen(isOpen)
    mapOpen = isOpen
    mapPage.Visible = isOpen
    guideContent.Visible = not isOpen
    for _, entry in ipairs(guideEntries) do entry.Visible = not isOpen end
    mapButton.Text = isOpen and "GUIDE" or "SKY MAP"
end

mapButton.Activated:Connect(function()
    setMapOpen(not mapOpen)
end)

local guideClose = Instance.new("TextButton")
guideClose.AnchorPoint = Vector2.new(0.5, 1)
guideClose.Position = UDim2.new(0.5, 0, 1, -12)
guideClose.Size = UDim2.fromOffset(126, 44)
guideClose.BackgroundColor3 = Theme.Aqua
guideClose.BackgroundTransparency = 0.12
guideClose.Font = Enum.Font.GothamBold
guideClose.Text = "GOT IT"
guideClose.TextColor3 = Theme.Ink
guideClose.TextSize = 11
guideClose.AutoButtonColor = false
guideClose.ZIndex = 32
guideClose.Parent = guidePanel
addCorner(guideClose, 10)

local function setGuideOpen(isOpen)
    guideOverlay.Visible = isOpen
    if isOpen then setMapOpen(false) end
end

guideButton.Activated:Connect(function()
    setGuideOpen(true)
end)
guideClose.Activated:Connect(function()
    setGuideOpen(false)
end)
guideEvent.OnClientEvent:Connect(function()
    setGuideOpen(true)
end)

UserInputService.InputBegan:Connect(function(input, processed)
    if processed or UserInputService:GetFocusedTextBox() then return end
    if not Config.crewMateById(player:GetAttribute("CrewMate")) then return end
    if input.KeyCode == Enum.KeyCode.G then
        setGuideOpen(not guideOverlay.Visible)
        if guideOverlay.Visible then setDrawerOpen(false) end
    elseif input.KeyCode == Enum.KeyCode.J then
        if guideOverlay.Visible then return end
        setDrawerOpen(not drawer.Visible)
    elseif input.KeyCode == Enum.KeyCode.ButtonB then
        if guideOverlay.Visible then
            setGuideOpen(false)
        elseif drawer.Visible then
            setDrawerOpen(false)
        end
    end
end)

-- A first-join card keeps the premise and the initial choice in one short,
-- skippable-feeling moment. The server owns the final choice and saves it.
local introOverlay = Instance.new("Frame")
introOverlay.Name = "CrewMateIntro"
introOverlay.Size = UDim2.fromScale(1, 1)
introOverlay.BackgroundColor3 = Theme.Ink
introOverlay.BackgroundTransparency = 0.16
introOverlay.Visible = false
introOverlay.ZIndex = 20
introOverlay.Parent = gui

local introPanel = Instance.new("Frame")
introPanel.AnchorPoint = Vector2.new(0.5, 0.5)
introPanel.Position = UDim2.fromScale(0.5, 0.5)
introPanel.Size = UDim2.fromScale(0.92, 0.9)
introPanel.BackgroundColor3 = Theme.Panel
introPanel.ZIndex = 21
introPanel.Parent = introOverlay
addCorner(introPanel, 18)
addStroke(introPanel, Theme.Border, 0.2)
local introSizeConstraint = Instance.new("UISizeConstraint")
introSizeConstraint.MaxSize = Vector2.new(800, 430)
introSizeConstraint.Parent = introPanel

local introGradient = Instance.new("UIGradient")
introGradient.Color = ColorSequence.new(Theme.PanelRaised, Theme.Panel)
introGradient.Rotation = 90
introGradient.Parent = introPanel

local introContent = Instance.new("ScrollingFrame")
introContent.Name = "CharacterChoices"
introContent.Position = UDim2.fromOffset(6, 6)
introContent.Size = UDim2.new(1, -12, 1, -12)
introContent.BackgroundTransparency = 1
introContent.BorderSizePixel = 0
introContent.ScrollBarThickness = 5
introContent.ScrollBarImageColor3 = Theme.Aqua
introContent.ScrollingDirection = Enum.ScrollingDirection.Y
introContent.CanvasSize = UDim2.fromOffset(0, 410)
introContent.ZIndex = 22
introContent.Parent = introPanel

local function introText(value, position, size, font, textSize, color, alignment)
    local label = text(introContent, value, position, size, font, textSize, color, alignment)
    label.ZIndex = 22
    return label
end

introText("WELCOME TO SKYBOUND SALVAGERS", UDim2.fromOffset(18, 12), UDim2.new(1, -36, 0, 48), Enum.Font.GothamBlack, 19, Theme.Text, Enum.TextXAlignment.Center).TextWrapped = true
introText("Recover lost cargo. Improve your harbor. Join crews to calm storms and unlock new skies.", UDim2.fromOffset(18, 62), UDim2.new(1, -36, 0, 44), Enum.Font.GothamMedium, 12, Theme.Muted, Enum.TextXAlignment.Center).TextWrapped = true
local selectionHint = introText("CHOOSE YOUR CREWMATE", UDim2.fromOffset(18, 112), UDim2.new(1, -36, 0, 18), Enum.Font.GothamBold, 10, Theme.Aqua, Enum.TextXAlignment.Center)

local crewMateButtons = {}
local crewMateCards = {}
for index, mate in ipairs(Config.CrewMates) do
    local card = Instance.new("Frame")
    card.Name = mate.Id .. "Card"
    card.Position = UDim2.new((index - 1) / 3, 10, 0, 140)
    card.Size = UDim2.new(1 / 3, -16, 0, 250)
    card.BackgroundColor3 = Theme.Ink
    card.BackgroundTransparency = 0.18
    card.ZIndex = 22
    card.Parent = introContent
    table.insert(crewMateCards, card)
    addCorner(card, 14)
    addStroke(card, Theme[mate.Accent], 0.26)

    local accent = Instance.new("Frame")
    accent.Size = UDim2.new(1, 0, 0, 4)
    accent.BackgroundColor3 = Theme[mate.Accent]
    accent.ZIndex = 23
    accent.Parent = card
    addCorner(accent, 14)

    local function cardText(value, y, height, font, textSize, color)
        local label = Instance.new("TextLabel")
        label.BackgroundTransparency = 1
        label.Position = UDim2.fromOffset(12, y)
        label.Size = UDim2.new(1, -24, 0, height)
        label.Font = font
        label.Text = value
        label.TextSize = textSize
        label.TextColor3 = color
        label.TextWrapped = true
        label.TextXAlignment = Enum.TextXAlignment.Center
        label.TextYAlignment = Enum.TextYAlignment.Center
        label.ZIndex = 23
        label.Parent = card
        return label
    end

    cardText(mate.Name:upper(), 20, 24, Enum.Font.GothamBlack, 17, Theme.Text)
    cardText(mate.Role, 48, 18, Enum.Font.GothamBold, 9, Theme[mate.Accent])
    cardText("STRENGTH\n" .. mate.Strength, 79, 44, Enum.Font.GothamMedium, 10, Theme.Mint)
    cardText("TRADEOFF\n" .. mate.Weakness, 126, 44, Enum.Font.GothamMedium, 10, Theme.Coral)
    cardText("BATTLE • " .. mate.Battle, 173, 18, Enum.Font.GothamBold, 8, Theme[mate.Accent])

    local chooseButton = Instance.new("TextButton")
    chooseButton.Name = "Choose"
    chooseButton.Position = UDim2.new(0, 12, 1, -54)
    chooseButton.Size = UDim2.new(1, -24, 0, 44)
    chooseButton.BackgroundColor3 = Theme[mate.Accent]
    chooseButton.BackgroundTransparency = 0.1
    chooseButton.Font = Enum.Font.GothamBold
    chooseButton.Text = "CHOOSE " .. mate.Name:upper()
    chooseButton.TextSize = 10
    chooseButton.TextColor3 = Theme.Ink
    chooseButton.AutoButtonColor = false
    chooseButton.ZIndex = 23
    chooseButton.Parent = card
    addCorner(chooseButton, 9)
    crewMateButtons[mate.Id] = chooseButton
end

local function layoutCrewMateCards()
    local stacked = introContent.AbsoluteSize.X < 620
    for index, card in ipairs(crewMateCards) do
        card.Position = stacked and UDim2.fromOffset(10, 140 + (index - 1) * 264)
            or UDim2.new((index - 1) / #crewMateCards, 10, 0, 140)
        card.Size = stacked and UDim2.new(1, -26, 0, 250)
            or UDim2.new(1 / #crewMateCards, -20, 0, 250)
    end
    introContent.CanvasSize = UDim2.fromOffset(0, stacked and (140 + #crewMateCards * 264) or 410)
end
introContent:GetPropertyChangedSignal("AbsoluteSize"):Connect(layoutCrewMateCards)
layoutCrewMateCards()

local choosingMate = false
local selectionAttempt = 0
local function resetSelectionButtons()
    choosingMate = false
    for id, choice in pairs(crewMateButtons) do
        local mate = Config.crewMateById(id)
        choice.Text = "CHOOSE " .. mate.Name:upper()
    end
end
for mateId, button in pairs(crewMateButtons) do
    button.Activated:Connect(function()
        if choosingMate then return end
        choosingMate = true
        selectionAttempt += 1
        local attempt = selectionAttempt
        selectionHint.Text = "CONFIRMING YOUR CREWMATE..."
        button.Text = "BOARDING..."
        crewMateEvent:FireServer(mateId)
        task.delay(8, function()
            if attempt ~= selectionAttempt or not choosingMate then return end
            if player:GetAttribute("CrewMate") == "" then
                resetSelectionButtons()
                selectionHint.Text = "NO CONFIRMATION YET • TAP TO RETRY"
            end
        end)
    end)
end

local function updateCrewMateIntro()
    local mateId = player:GetAttribute("CrewMate")
    introOverlay.Visible = mateId == ""
    if mateId ~= "" then
        selectionAttempt += 1
        resetSelectionButtons()
        selectionHint.Text = "CHOOSE YOUR CREWMATE"
    end
end

local function formatRemaining(seconds)
    local minutes = math.floor(seconds / 60)
    local remainder = seconds % 60
    return string.format("%d:%02d", minutes, remainder)
end

local function updateHud()
    local stats = player:FindFirstChild("leaderstats")
    local salvage = stats and stats:FindFirstChild("Salvage")
    local level = stats and stats:FindFirstChild("Harbor Level")
    local explorerLevel = stats and stats:FindFirstChild("Explorer Level")
    local salvageAmount = salvage and salvage.Value or 0
    local harborLevel = level and level.Value or 1
    local explorerRank = explorerLevel and explorerLevel.Value or 1
    local progress = player:GetAttribute("ContractProgress") or 0
    local goal = player:GetAttribute("ContractGoal") or Config.ContractGoal
    local beacons = player:GetAttribute("RescueBeacons") or 0
    local rescued = player:GetAttribute("SkylingsRescued") or 0
    local visits = player:GetAttribute("HarborVisits") or 0
    local stormActive = remotes:GetAttribute("StormActive")
    local stormProgress = remotes:GetAttribute("StormProgress") or 0
    local stormGoal = remotes:GetAttribute("StormGoal") or 0
    local stormEndsAt = remotes:GetAttribute("StormEndsAt") or 0
    local inCrew = player:GetAttribute("InCrew")
    local crewProgress = remotes:GetAttribute("CrewProgress") or 0
    local crewGoal = remotes:GetAttribute("CrewGoal") or Config.CrewGoalBase
    local crewCount = remotes:GetAttribute("CrewMemberCount") or 0
    local firstFlightComplete = player:GetAttribute("FirstFlightComplete")
    local mate = Config.crewMateById(player:GetAttribute("CrewMate"))
    local explorerXp = player:GetAttribute("ExplorerXP") or 0
    local explorerNextXp = player:GetAttribute("ExplorerNextXP") or Config.explorerXpForLevel(explorerRank)
    local explorerBonus = player:GetAttribute("ExplorerBonusPercent") or 0
    local explorerTitle = player:GetAttribute("ExplorerTitle") or "Deckhand"
    local crewTrainingLevel = player:GetAttribute("CrewTrainingLevel") or 0
    local crewTrainingCost = player:GetAttribute("CrewTrainingCost") or 0
    local skylingBonus = player:GetAttribute("SkylingBonus") or 0
    local discoveryChain = player:GetAttribute("DiscoveryChain") or 0
    local discoveryChainEndsAt = player:GetAttribute("DiscoveryChainEndsAt") or 0
    local dailyReady = player:GetAttribute("DailyReady")
    local dailyReward = player:GetAttribute("DailyReward") or 0
    local contractFinish = progress == goal - 1
    local crewFinish = inCrew and crewProgress == crewGoal - 1
    local crewRecruiting = not inCrew and crewCount > 0 and crewCount < Config.CrewMaxMembers
    local upgradeMultiplier = mate and mate.UpgradeMultiplier or 1
    local harborUpgradeCost = math.ceil(Config.upgradeCost(harborLevel) * upgradeMultiplier)
    local trainingReady = mate and crewTrainingCost > 0 and salvageAmount >= crewTrainingCost
    -- Keep recruitment visible in the crew row without hiding an earned milestone.
    local crewInvitationReady = crewRecruiting and not contractFinish
        and not (harborLevel < Config.MaxHarborLevel and salvageAmount >= harborUpgradeCost)

    objectiveAction.Visible = false
    salvageValue.Text = tostring(salvageAmount)
    rankValue.Text = "RANK " .. explorerRank
    harborValue.Text = "LEVEL " .. harborLevel
    refreshSkyMap(harborLevel)
    mateValue.Text = mate and mate.Name:upper() or "CHOOSE ONE"
    contractValue.Text = progress .. " / " .. goal .. " CRATES"
    if skylingBonus >= Config.SkylingSalvageBonusCap then
        collectionValue.Text = rescued .. " SKYLINGS  •  +" .. skylingBonus .. " MAX"
    else
        local nextSkyling = Config.SkylingBonusEvery - (rescued % Config.SkylingBonusEvery)
        collectionValue.Text = rescued .. " SKYLINGS  •  +" .. skylingBonus .. "  •  " .. nextSkyling .. " TO NEXT"
    end
    if inCrew then
        crewValue.Text = "EXPEDITION  •  " .. crewCount .. " / " .. Config.CrewMaxMembers .. " PLAYERS  •  " .. crewProgress .. " / " .. crewGoal .. " CRATES  •  +" .. Config.CrewReward .. " EACH"
    elseif crewRecruiting then
        crewValue.Text = "EXPEDITION RECRUITING  •  " .. crewCount .. " / " .. Config.CrewMaxMembers .. " PLAYERS AT THE WRECK"
    elseif crewCount >= Config.CrewMaxMembers then
        crewValue.Text = "CREW FULL  •  YOU CAN STILL EXPLORE SOLO"
    else
        crewValue.Text = "JOIN A 1–4 PLAYER EXPEDITION AT THE WRECK"
    end
    rankDetailValue.Text = "R" .. explorerRank .. "  •  " .. explorerXp .. " / " .. explorerNextXp .. " XP  •  +" .. explorerBonus .. "%"
    TweenService:Create(contractProgressFill, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
        Size = UDim2.fromScale(math.clamp(progress / math.max(goal, 1), 0, 1), 1),
    }):Play()
    TweenService:Create(explorerProgressFill, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
        Size = UDim2.fromScale(math.clamp(explorerXp / math.max(explorerNextXp, 1), 0, 1), 1),
    }):Play()
    local chainSeconds = math.max(0, discoveryChainEndsAt - os.time())
    if stormActive then
        local remaining = math.max(0, stormEndsAt - os.time())
        chainChip.BackgroundColor3 = Theme.Violet
        chainValue.TextColor3 = Theme.Text
        chainStroke.Color = Theme.Text
        chainValue.Text = "STORM FRONT  •  " .. stormProgress .. " / " .. stormGoal .. "  •  " .. formatRemaining(remaining)
        chainChip.Visible = not drawer.Visible
    else
        chainChip.BackgroundColor3 = Theme.Mint
        chainValue.TextColor3 = Theme.Ink
        chainStroke.Color = Theme.Text
        chainValue.Text = "DISCOVERY CHAIN  x" .. discoveryChain .. "  •  +" .. math.max(0, math.min(discoveryChain - 1, Config.DiscoveryChainBonusMax)) .. "  •  " .. chainSeconds .. "s"
        chainChip.Visible = discoveryChain >= 2 and not drawer.Visible
    end
    journeySubtitle.Text = explorerTitle:upper() .. (mate and ("  •  " .. mate.Name:upper() .. "  •  " .. mate.BattleLabel) or "")

    if mate and not firstFlightComplete then
        journeyButton.BackgroundColor3 = Theme.Aqua
        journeyButton.TextColor3 = Theme.Aqua
        journeyStroke.Color = Theme.Aqua
        objectiveValue.Text = "FIRST FLIGHT • use the Wreck Navigator, then recover one crate"
    elseif stormActive then
        journeyButton.BackgroundColor3 = Theme.Violet
        journeyButton.TextColor3 = Theme.Violet
        journeyStroke.Color = Theme.Violet
        local remaining = math.max(0, stormEndsAt - os.time())
        objectiveValue.Text = "Storm cores: " .. stormProgress .. " / " .. stormGoal .. " • " .. formatRemaining(remaining) .. " remaining"
    elseif beacons > 0 then
        journeyButton.BackgroundColor3 = Theme.Violet
        journeyButton.TextColor3 = Theme.Violet
        journeyStroke.Color = Theme.Violet
        objectiveValue.Text = beacons .. " rescue beacon" .. (beacons == 1 and "" or "s") .. " ready • Return to your Sanctuary"
        objectiveAction.BackgroundColor3 = Theme.Violet
        objectiveAction.Text = "RETURN"
        objectiveAction.Visible = true
    elseif dailyReady then
        journeyButton.BackgroundColor3 = Theme.Gold
        journeyButton.TextColor3 = Theme.Gold
        journeyStroke.Color = Theme.Gold
        objectiveValue.Text = "Captain's Log ready at your harbor • +" .. dailyReward .. " salvage"
        objectiveAction.BackgroundColor3 = Theme.Gold
        objectiveAction.Text = "RETURN"
        objectiveAction.Visible = true
    elseif crewInvitationReady then
        journeyButton.BackgroundColor3 = Theme.Aqua
        journeyButton.TextColor3 = Theme.Aqua
        journeyStroke.Color = Theme.Aqua
        objectiveValue.Text = "Crew Expedition recruiting • " .. crewCount .. " / " .. Config.CrewMaxMembers .. " deckhands at the Wreck"
    elseif contractFinish or crewFinish then
        journeyButton.BackgroundColor3 = Theme.Mint
        journeyButton.TextColor3 = Theme.Mint
        journeyStroke.Color = Theme.Mint
        if contractFinish and crewFinish then
            objectiveValue.Text = "One regular crate completes your contract and advances the crew expedition"
        elseif contractFinish then
            objectiveValue.Text = "One regular crate completes your contract and earns a rescue beacon"
        else
            objectiveValue.Text = "One regular crate advances the shared crew expedition"
        end
    elseif harborLevel < Config.MaxHarborLevel and salvageAmount >= harborUpgradeCost then
        journeyButton.BackgroundColor3 = Theme.Gold
        journeyButton.TextColor3 = Theme.Gold
        journeyStroke.Color = Theme.Gold
        objectiveValue.Text = "Harbor Uplink ready • Upgrade to Harbor Level " .. (harborLevel + 1)
        objectiveAction.BackgroundColor3 = Theme.Gold
        objectiveAction.Text = "RETURN"
        objectiveAction.Visible = true
    elseif harborLevel < 2 then
        journeyButton.BackgroundColor3 = Theme.Gold
        journeyButton.TextColor3 = Theme.Gold
        journeyStroke.Color = Theme.Gold
        objectiveValue.Text = "Recover " .. (harborUpgradeCost - salvageAmount) .. " more salvage at the Whispering Wreck"
    elseif harborLevel < Config.MaxHarborLevel then
        journeyButton.BackgroundColor3 = Theme.Aqua
        journeyButton.TextColor3 = Theme.Aqua
        journeyStroke.Color = Theme.Aqua
        objectiveValue.Text = "Recover " .. (harborUpgradeCost - salvageAmount) .. " more salvage in Ember Drift"
    elseif mate and crewTrainingLevel < Config.CrewTrainingMax then
        journeyButton.BackgroundColor3 = Theme.Coral
        journeyButton.TextColor3 = Theme.Coral
        journeyStroke.Color = Theme.Coral
        objectiveValue.Text = "Train " .. mate.Name .. " at your harbor • +" .. crewTrainingLevel .. " salvage now"
        if trainingReady then
            objectiveAction.BackgroundColor3 = Theme.Coral
            objectiveAction.Text = "RETURN"
            objectiveAction.Visible = true
        end
    else
        journeyButton.BackgroundColor3 = Theme.Mint
        journeyButton.TextColor3 = Theme.Mint
        journeyStroke.Color = Theme.Mint
        objectiveValue.Text = "All biomes unlocked • collect Skylings and grow your crew"
    end

    if not stormActive and beacons > 0 then
        journeyAlert.BackgroundColor3 = Theme.Violet
        journeyAlert.Visible = true
    elseif not stormActive and dailyReady then
        journeyAlert.BackgroundColor3 = Theme.Gold
        journeyAlert.Visible = true
    elseif not stormActive and crewInvitationReady then
        journeyAlert.BackgroundColor3 = Theme.Aqua
        journeyAlert.Visible = true
    elseif not stormActive and (contractFinish or crewFinish) then
        journeyAlert.BackgroundColor3 = Theme.Mint
        journeyAlert.Visible = true
    elseif harborLevel < Config.MaxHarborLevel and salvageAmount >= harborUpgradeCost then
        journeyAlert.BackgroundColor3 = Theme.Aqua
        journeyAlert.Visible = true
    elseif trainingReady then
        journeyAlert.BackgroundColor3 = Theme.Coral
        journeyAlert.Visible = true
    else
        journeyAlert.Visible = false
    end
end

local rewardPopupNumber = 0
local function showSalvageGain(amount)
    rewardPopupNumber += 1
    local horizontalOffset = ((rewardPopupNumber % 3) - 1) * 38
    local popup = Instance.new("TextLabel")
    popup.AnchorPoint = Vector2.new(0.5, 0.5)
    popup.Position = UDim2.new(0.5, horizontalOffset, 0.61, 0)
    popup.Size = UDim2.fromOffset(150, 34)
    popup.BackgroundTransparency = 1
    popup.Font = Enum.Font.GothamBlack
    popup.Text = "+" .. amount .. " SALVAGE"
    popup.TextColor3 = Theme.Gold
    popup.TextSize = 18
    popup.TextStrokeColor3 = Theme.Ink
    popup.TextStrokeTransparency = 0.28
    popup.ZIndex = 8
    popup.Parent = gui
    TweenService:Create(popup, TweenInfo.new(0.7, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
        Position = UDim2.new(0.5, horizontalOffset, 0.61, -48),
        TextTransparency = 1,
        TextStrokeTransparency = 1,
    }):Play()
    task.delay(0.75, function() popup:Destroy() end)
end

local rankBannerNumber = 0
local function showRankUp(rank)
    rankBannerNumber += 1
    local currentBanner = rankBannerNumber
    local title = Config.explorerTitleForLevel(rank):upper()
    local bonusPercent = math.floor((Config.explorerSalvageMultiplier(rank) - 1) * 100 + 0.5)
    rankName.Text = title .. "  •  RANK " .. rank
    rankBonus.Text = "+" .. bonusPercent .. "% PERMANENT SALVAGE"
    rankBanner.Visible = true
    rankBanner.BackgroundTransparency = 1
    rankBannerStroke.Transparency = 1
    rankKicker.TextTransparency = 1
    rankName.TextTransparency = 1
    rankBonus.TextTransparency = 1
    TweenService:Create(rankBanner, TweenInfo.new(0.18), { BackgroundTransparency = 0.08 }):Play()
    TweenService:Create(rankBannerStroke, TweenInfo.new(0.18), { Transparency = 0.12 }):Play()
    for _, label in ipairs({ rankKicker, rankName, rankBonus }) do
        TweenService:Create(label, TweenInfo.new(0.18), { TextTransparency = 0 }):Play()
    end
    task.delay(3.2, function()
        if currentBanner ~= rankBannerNumber then return end
        TweenService:Create(rankBanner, TweenInfo.new(0.25), { BackgroundTransparency = 1 }):Play()
        TweenService:Create(rankBannerStroke, TweenInfo.new(0.25), { Transparency = 1 }):Play()
        for _, label in ipairs({ rankKicker, rankName, rankBonus }) do
            TweenService:Create(label, TweenInfo.new(0.25), { TextTransparency = 1 }):Play()
        end
        task.delay(0.28, function()
            if currentBanner == rankBannerNumber then rankBanner.Visible = false end
        end)
    end)
end

local beaconNoticeNumber = 0
local function showBeaconReady()
    beaconNoticeNumber += 1
    local currentNotice = beaconNoticeNumber
    beaconNotice.Visible = true
    beaconNotice.BackgroundTransparency = 1
    beaconNotice.TextTransparency = 1
    beaconNoticeStroke.Transparency = 1
    TweenService:Create(beaconNotice, TweenInfo.new(0.18), { BackgroundTransparency = 0.08, TextTransparency = 0 }):Play()
    TweenService:Create(beaconNoticeStroke, TweenInfo.new(0.18), { Transparency = 0.15 }):Play()
    task.delay(2.8, function()
        if currentNotice ~= beaconNoticeNumber then return end
        TweenService:Create(beaconNotice, TweenInfo.new(0.25), { BackgroundTransparency = 1, TextTransparency = 1 }):Play()
        TweenService:Create(beaconNoticeStroke, TweenInfo.new(0.25), { Transparency = 1 }):Play()
        task.delay(0.28, function()
            if currentNotice == beaconNoticeNumber then beaconNotice.Visible = false end
        end)
    end)
end

local function watchStats()
    local stats = player:WaitForChild("leaderstats")
    for _, stat in ipairs(stats:GetChildren()) do
        if stat:IsA("ValueBase") then stat.Changed:Connect(updateHud) end
    end
    stats.ChildAdded:Connect(function(stat)
        if stat:IsA("ValueBase") then stat.Changed:Connect(updateHud) end
    end)
    local trackedSalvage = stats:WaitForChild("Salvage")
    local previousSalvage = trackedSalvage.Value
    trackedSalvage.Changed:Connect(function()
        local newSalvage = trackedSalvage.Value
        if newSalvage > previousSalvage then showSalvageGain(newSalvage - previousSalvage) end
        previousSalvage = newSalvage
    end)
    local trackedExplorerLevel = stats:WaitForChild("Explorer Level")
    local previousExplorerLevel = trackedExplorerLevel.Value
    trackedExplorerLevel.Changed:Connect(function()
        local newExplorerLevel = trackedExplorerLevel.Value
        if newExplorerLevel > previousExplorerLevel then showRankUp(newExplorerLevel) end
        previousExplorerLevel = newExplorerLevel
    end)
    local previousBeacons = player:GetAttribute("RescueBeacons") or 0
    player:GetAttributeChangedSignal("RescueBeacons"):Connect(function()
        local newBeacons = player:GetAttribute("RescueBeacons") or 0
        if newBeacons > previousBeacons then showBeaconReady() end
        previousBeacons = newBeacons
    end)
    for _, attribute in ipairs({ "ContractProgress", "ContractGoal", "RescueBeacons", "SkylingsRescued", "HarborVisits", "InCrew", "FirstFlightComplete", "CrewMate", "CrewTrainingLevel", "CrewTrainingCost", "ExplorerXP", "ExplorerNextXP", "ExplorerBonusPercent", "ExplorerTitle", "SkylingBonus", "DiscoveryChain", "DiscoveryChainEndsAt", "DailyReady", "DailyStreak", "DailyReward" }) do
        player:GetAttributeChangedSignal(attribute):Connect(updateHud)
    end
    for _, attribute in ipairs({ "StormActive", "StormProgress", "StormGoal", "StormEndsAt", "CrewProgress", "CrewGoal", "CrewMemberCount" }) do
        remotes:GetAttributeChangedSignal(attribute):Connect(updateHud)
    end
    updateHud()
end

local toastNumber = 0
local toastColors = {
    Success = Theme.Mint,
    Warning = Theme.Coral,
    Storm = Theme.Violet,
    Info = Theme.Aqua,
}

statusEvent.OnClientEvent:Connect(function(message, kind)
    toastNumber += 1
    local currentToast = toastNumber
    local color = toastColors[kind] or Theme.Aqua
    toast.Text = message
    toast.TextColor3 = color:Lerp(Theme.Text, 0.2)
    toastStroke.Color = color
    TweenService:Create(toast, TweenInfo.new(0.18), { BackgroundTransparency = 0.1, TextTransparency = 0 }):Play()
    task.delay(4, function()
        if currentToast == toastNumber then
            TweenService:Create(toast, TweenInfo.new(0.28), { BackgroundTransparency = 1, TextTransparency = 1 }):Play()
        end
    end)
end)

task.spawn(watchStats)
task.spawn(function()
    while true do
        task.wait(1)
        if remotes:GetAttribute("StormActive") or (player:GetAttribute("DiscoveryChain") or 0) >= 2 then updateHud() end
    end
end)
player:GetAttributeChangedSignal("CrewMate"):Connect(updateCrewMateIntro)
updateCrewMateIntro()
