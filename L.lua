-- =============================================================================
-- GRAPE REMASTERED UI LIBRARY (FOR GITHUB)
-- =============================================================================
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Theme = {
    Background = Color3.fromRGB(15, 15, 15),
    TopBar = Color3.fromRGB(20, 20, 20),
    Accent = Color3.fromRGB(218, 47, 47),
    TabActive = Color3.fromRGB(218, 47, 47),
    TabInactive = Color3.fromRGB(33, 33, 38),
    Text = Color3.fromRGB(255, 255, 255),
    TextDark = Color3.fromRGB(160, 160, 160),
    ElementBg = Color3.fromRGB(28, 28, 32),
    ElementHover = Color3.fromRGB(40, 40, 45)
}

local FontMain = Enum.Font.Ubuntu
local FontBold = Enum.Font.GothamBold

local function Tween(instance, properties, duration)
    local tweenInfo = TweenInfo.new(duration or 0.3, Enum.EasingStyle.Cubic, Enum.EasingDirection.Out)
    local tween = TweenService:Create(instance, tweenInfo, properties)
    tween:Play()
    return tween
end

local Library = {}
local ToggleMinimizeGlobal = function() end

function Library:CreateWindow(titleText)
    local ScreenGui = Instance.new("ScreenGui")
    ScreenGui.Name = "Grape_Remastered_Final"
    ScreenGui.ResetOnSpawn = false
    ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    pcall(function() ScreenGui.DisplayOrder = 999999 end)
    
    local success = pcall(function() ScreenGui.Parent = game:GetService("CoreGui") end)
    if not success then ScreenGui.Parent = game:GetService("Players").LocalPlayer:WaitForChild("PlayerGui") end

    local MainFrame = Instance.new("Frame")
    MainFrame.Size = UDim2.new(0, 0, 0, 0)
    MainFrame.Position = UDim2.new(0.5, 0, 0.5, 0)
    MainFrame.BackgroundColor3 = Theme.Background
    MainFrame.BorderSizePixel = 0
    MainFrame.ClipsDescendants = true
    MainFrame.Active = true
    MainFrame.Parent = ScreenGui

    local UICorner = Instance.new("UICorner")
    UICorner.CornerRadius = UDim.new(0, 5)
    UICorner.Parent = MainFrame

    local TopBar = Instance.new("Frame")
    TopBar.Size = UDim2.new(1, 0, 0, 35)
    TopBar.BackgroundTransparency = 1
    TopBar.Parent = MainFrame

    local Title = Instance.new("TextLabel")
    Title.Size = UDim2.new(1, 0, 1, 0)
    Title.BackgroundTransparency = 1
    Title.Text = titleText
    Title.TextColor3 = Theme.Text
    Title.TextSize = 14
    Title.Font = FontMain
    Title.TextXAlignment = Enum.TextXAlignment.Center
    Title.Parent = TopBar

    local TopLine = Instance.new("Frame")
    TopLine.Size = UDim2.new(1, -24, 0, 4)
    TopLine.Position = UDim2.new(0, 12, 0, 35)
    TopLine.BackgroundColor3 = Theme.Accent
    TopLine.BorderSizePixel = 0
    TopLine.Parent = MainFrame
    Instance.new("UICorner", TopLine).CornerRadius = UDim.new(0, 2)

    local TabContainer = Instance.new("Frame")
    TabContainer.Size = UDim2.new(1, 0, 0, 40)
    TabContainer.Position = UDim2.new(0, 0, 0, 45)
    TabContainer.BackgroundTransparency = 1
    TabContainer.Parent = MainFrame

    local TabList = Instance.new("UIListLayout")
    TabList.Padding = UDim.new(0, 10)
    TabList.FillDirection = Enum.FillDirection.Horizontal
    TabList.HorizontalAlignment = Enum.HorizontalAlignment.Center
    TabList.VerticalAlignment = Enum.VerticalAlignment.Center
    TabList.SortOrder = Enum.SortOrder.LayoutOrder
    TabList.Parent = TabContainer

    local ContentContainer = Instance.new("Frame")
    ContentContainer.Size = UDim2.new(1, -20, 1, -120)
    ContentContainer.Position = UDim2.new(0, 10, 0, 95)
    ContentContainer.BackgroundTransparency = 1
    ContentContainer.Parent = MainFrame

    local CollapseBtn = Instance.new("TextButton")
    CollapseBtn.Size = UDim2.new(0, 30, 0, 15)
    CollapseBtn.Position = UDim2.new(0.5, -15, 1, -15)
    CollapseBtn.BackgroundTransparency = 1
    CollapseBtn.Text = "/\\"
    CollapseBtn.TextColor3 = Theme.TextDark
    CollapseBtn.Font = Enum.Font.Code
    CollapseBtn.TextSize = 12
    CollapseBtn.ZIndex = 10
    CollapseBtn.Parent = MainFrame

    local DragArea = Instance.new("TextButton")
    DragArea.Size = UDim2.new(1, 0, 0, 39)
    DragArea.BackgroundTransparency = 1
    DragArea.Text = ""
    DragArea.Parent = MainFrame

    local dragging, dragInput, dragStart, startPos
    DragArea.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = true; dragStart = input.Position; startPos = MainFrame.Position
            input.Changed:Connect(function() if input.UserInputState == Enum.UserInputState.End then dragging = false end end)
        end
    end)
    DragArea.InputChanged:Connect(function(input) if input.UserInputType == Enum.UserInputType.MouseMovement then dragInput = input end end)
    UserInputService.InputChanged:Connect(function(input)
        if input == dragInput and dragging then
            local delta = input.Position - dragStart
            MainFrame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        end
    end)

    local Window = { Tabs = {}, CurrentTab = nil, IsMinimized = false, StoredSize = UDim2.new(0, 650, 0, 420), GuiInstance = ScreenGui }

    local function ToggleMinimize()
        Window.IsMinimized = not Window.IsMinimized
        if Window.IsMinimized then
            ContentContainer.Visible = false; TabContainer.Visible = false
            Tween(MainFrame, {Size = UDim2.new(0, MainFrame.Size.X.Offset, 0, 44)}, 0.2)
            Tween(CollapseBtn, {Position = UDim2.new(0.5, -15, 0, 26)}, 0.3)
            task.spawn(function() task.wait(0.15); if Window.IsMinimized then CollapseBtn.Text = "\\/" end end)
        else
            Tween(MainFrame, {Size = Window.StoredSize}, 0.3)
            local arrowTween = Tween(CollapseBtn, {Position = UDim2.new(0.5, -15, 1, -15)}, 0.01)
            task.spawn(function() task.wait(0.15); if not Window.IsMinimized then CollapseBtn.Text = "/\\" end end)
            arrowTween.Completed:Connect(function() if not Window.IsMinimized then ContentContainer.Visible = true; TabContainer.Visible = true end end)
        end
    end

    CollapseBtn.MouseButton1Click:Connect(ToggleMinimize)
    ToggleMinimizeGlobal = ToggleMinimize

    function Window:CreateTab(tabName)
        local TabBtn = Instance.new("TextButton")
        TabBtn.Size = UDim2.new(0, 110, 0, 28)
        TabBtn.BackgroundColor3 = Theme.TabInactive
        TabBtn.Text = tabName
        TabBtn.TextColor3 = Theme.TextDark
        TabBtn.Font = FontMain
        TabBtn.TextSize = 14
        TabBtn.AutoButtonColor = false
        TabBtn.Parent = TabContainer

        local ContentScroll = Instance.new("ScrollingFrame")
        ContentScroll.Size = UDim2.new(1, 0, 1, 0)
        ContentScroll.BackgroundTransparency = 1
        ContentScroll.ScrollBarThickness = 3
        ContentScroll.ScrollBarImageColor3 = Theme.Accent
        ContentScroll.Visible = false
        ContentScroll.Parent = ContentContainer

        local ContentList = Instance.new("UIListLayout")
        ContentList.Padding = UDim.new(0, 6)
        ContentList.SortOrder = Enum.SortOrder.LayoutOrder
        ContentList.Parent = ContentScroll
        ContentList:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
            ContentScroll.CanvasSize = UDim2.new(0, 0, 0, ContentList.AbsoluteContentSize.Y + 10)
        end)

        TabBtn.MouseEnter:Connect(function() if Window.CurrentTab ~= ContentScroll then Tween(TabBtn, {BackgroundColor3 = Theme.ElementHover, TextColor3 = Theme.Text}, 0.2) end end)
        TabBtn.MouseLeave:Connect(function() if Window.CurrentTab ~= ContentScroll then Tween(TabBtn, {BackgroundColor3 = Theme.TabInactive, TextColor3 = Theme.TextDark}, 0.2) end end)

        TabBtn.MouseButton1Click:Connect(function()
            for _, tab in pairs(Window.Tabs) do
                tab.Content.Visible = false
                Tween(tab.Button, {BackgroundColor3 = Theme.TabInactive, TextColor3 = Theme.TextDark}, 0.2)
            end
            Window.CurrentTab = ContentScroll
            ContentScroll.Visible = true
            Tween(TabBtn, {BackgroundColor3 = Theme.TabActive, TextColor3 = Theme.Text}, 0.2)
        end)

        table.insert(Window.Tabs, {Button = TabBtn, Content = ContentScroll})
        if #Window.Tabs == 1 then
            Window.CurrentTab = ContentScroll
            ContentScroll.Visible = true
            TabBtn.BackgroundColor3 = Theme.TabActive
            TabBtn.TextColor3 = Theme.Text
        end

        local TabElements = {}
        function TabElements:CreateAccordion(title)
            local AccordionFrame = Instance.new("Frame")
            AccordionFrame.Size = UDim2.new(1, 0, 0, 32)
            AccordionFrame.BackgroundColor3 = Color3.fromRGB(18, 18, 18)
            AccordionFrame.ClipsDescendants = true
            AccordionFrame.Parent = ContentScroll
            Instance.new("UICorner", AccordionFrame).CornerRadius = UDim.new(0, 4)

            local AccordionBtn = Instance.new("TextButton")
            AccordionBtn.Size = UDim2.new(1, 0, 0, 32)
            AccordionBtn.BackgroundTransparency = 1
            AccordionBtn.Text = "  ▷  " .. title
            AccordionBtn.TextColor3 = Theme.Text
            AccordionBtn.TextXAlignment = Enum.TextXAlignment.Left
            AccordionBtn.Font = FontBold
            AccordionBtn.TextSize = 13
            AccordionBtn.Parent = AccordionFrame

            local ItemContainer = Instance.new("Frame")
            ItemContainer.Size = UDim2.new(1, -20, 0, 0)
            ItemContainer.Position = UDim2.new(0, 10, 0, 38)
            ItemContainer.BackgroundTransparency = 1
            ItemContainer.Parent = AccordionFrame

            local ItemList = Instance.new("UIListLayout")
            ItemList.Padding = UDim.new(0, 8)
            ItemList.SortOrder = Enum.SortOrder.LayoutOrder
            ItemList.Parent = ItemContainer

            local isOpen = false
            AccordionBtn.MouseButton1Click:Connect(function()
                isOpen = not isOpen
                AccordionBtn.Text = (isOpen and "  ▽  " or "  ▷  ") .. title
                Tween(AccordionFrame, {Size = UDim2.new(1, 0, 0, isOpen and (ItemList.AbsoluteContentSize.Y + 48) or 32)}, 0.25)
            end)
            ItemList:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
                if isOpen then Tween(AccordionFrame, {Size = UDim2.new(1, 0, 0, ItemList.AbsoluteContentSize.Y + 48)}, 0.15) end
            end)

            local AccordionElements = {}
            function AccordionElements:CreateToggle(text, startState, callback)
                local ToggleFrame = Instance.new("TextButton")
                ToggleFrame.Size = UDim2.new(1, 0, 0, 24)
                ToggleFrame.BackgroundTransparency = 1
                ToggleFrame.Text = ""
                ToggleFrame.Parent = ItemContainer
                
                local Checkbox = Instance.new("Frame")
                Checkbox.Size = UDim2.new(0, 16, 0, 16)
                Checkbox.Position = UDim2.new(0, 5, 0.5, -8)
                Checkbox.BackgroundColor3 = startState and Theme.Accent or Theme.ElementBg
                Checkbox.BorderSizePixel = 0
                Checkbox.Parent = ToggleFrame
                Instance.new("UICorner", Checkbox).CornerRadius = UDim.new(0, 3)

                local Label = Instance.new("TextLabel")
                Label.Size = UDim2.new(1, -30, 1, 0)
                Label.Position = UDim2.new(0, 30, 0, 0)
                Label.BackgroundTransparency = 1
                Label.Text = text
                Label.TextColor3 = startState and Theme.Text or Theme.TextDark
                Label.TextXAlignment = Enum.TextXAlignment.Left
                Label.Font = FontMain
                Label.TextSize = 14
                Label.Parent = ToggleFrame
                
                local state = startState
                task.spawn(function() callback(state) end)

                ToggleFrame.MouseEnter:Connect(function() Tween(Label, {TextColor3 = Theme.Text}, 0.15) end)
                ToggleFrame.MouseLeave:Connect(function() if not state then Tween(Label, {TextColor3 = Theme.TextDark}, 0.15) end end)
                ToggleFrame.MouseButton1Click:Connect(function()
                    state = not state
                    Tween(Checkbox, {BackgroundColor3 = state and Theme.Accent or Theme.ElementBg}, 0.2)
                    Tween(Label, {TextColor3 = state and Theme.Text or Theme.TextDark}, 0.2)
                    callback(state)
                end)
            end

            function AccordionElements:CreateSlider(text, min, max, default, callback)
                local SliderFrame = Instance.new("Frame")
                SliderFrame.Size = UDim2.new(1, 0, 0, 42)
                SliderFrame.BackgroundTransparency = 1
                SliderFrame.Parent = ItemContainer
                
                local Label = Instance.new("TextLabel")
                Label.Size = UDim2.new(1, 0, 0, 18)
                Label.Position = UDim2.new(0, 5, 0, 0)
                Label.BackgroundTransparency = 1
                Label.Text = text
                Label.TextColor3 = Theme.TextDark
                Label.TextXAlignment = Enum.TextXAlignment.Left
                Label.Font = FontMain
                Label.TextSize = 13
                Label.Parent = SliderFrame
                
                local MainBlock = Instance.new("TextButton")
                MainBlock.Size = UDim2.new(1, -10, 0, 20)
                MainBlock.Position = UDim2.new(0, 5, 0, 20)
                MainBlock.BackgroundColor3 = Theme.ElementBg
                MainBlock.AutoButtonColor = false
                MainBlock.Text = ""
                MainBlock.Parent = SliderFrame
                Instance.new("UICorner", MainBlock).CornerRadius = UDim.new(0, 4)

                local Fill = Instance.new("Frame")
                Fill.Size = UDim2.new((default - min) / (max - min), 0, 1, 0)
                Fill.BackgroundColor3 = Theme.Accent
                Fill.BorderSizePixel = 0
                Fill.Parent = MainBlock
                Instance.new("UICorner", Fill).CornerRadius = UDim.new(0, 4)

                local ValueLabel = Instance.new("TextLabel")
                ValueLabel.Size = UDim2.new(1, 0, 1, 0)
                ValueLabel.BackgroundTransparency = 1
                ValueLabel.Text = tostring(default)
                ValueLabel.TextColor3 = Theme.Text
                ValueLabel.Font = FontBold
                ValueLabel.TextSize = 12
                ValueLabel.ZIndex = 3
                ValueLabel.Parent = MainBlock
                task.spawn(function() callback(default) end)

                local dragging = false
                local function UpdateSlider(input)
                    local relative = math.clamp((input.Position.X - MainBlock.AbsolutePosition.X) / MainBlock.AbsoluteSize.X, 0, 1)
                    local value = math.floor(min + ((max - min) * relative))
                    Tween(Fill, {Size = UDim2.new(relative, 0, 1, 0)}, 0.1)
                    ValueLabel.Text = tostring(value)
                    callback(value)
                end

                MainBlock.InputBegan:Connect(function(input) if input.UserInputType == Enum.UserInputType.MouseButton1 then dragging = true; UpdateSlider(input) end end)
                UserInputService.InputEnded:Connect(function(input) if input.UserInputType == Enum.UserInputType.MouseButton1 then dragging = false end end)
                UserInputService.InputChanged:Connect(function(input) if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then UpdateSlider(input) end end)
            end

            function AccordionElements:CreateKeybindInputWithCheckbox(text, defaultKey, startEnabled, onKeyChange, onCheckboxChange)
                local KeyFrame = Instance.new("Frame")
                KeyFrame.Size = UDim2.new(1, 0, 0, 36)
                KeyFrame.BackgroundTransparency = 1
                KeyFrame.Parent = ItemContainer
                
                local Checkbox = Instance.new("TextButton")
                Checkbox.Size = UDim2.new(0, 16, 0, 16)
                Checkbox.Position = UDim2.new(0, 5, 0.5, -8)
                Checkbox.BackgroundColor3 = startEnabled and Theme.Accent or Theme.ElementBg
                Checkbox.Text = ""
                Checkbox.Parent = KeyFrame
                Instance.new("UICorner", Checkbox).CornerRadius = UDim.new(0, 3)
                
                local cbState = startEnabled
                task.spawn(function() onCheckboxChange(cbState) end)
                
                Checkbox.MouseButton1Click:Connect(function()
                    cbState = not cbState
                    Tween(Checkbox, {BackgroundColor3 = cbState and Theme.Accent or Theme.ElementBg}, 0.2)
                    onCheckboxChange(cbState)
                end)

                local Label = Instance.new("TextLabel")
                Label.Size = UDim2.new(0.45, -25, 1, 0)
                Label.Position = UDim2.new(0, 30, 0, 0)
                Label.BackgroundTransparency = 1
                Label.Text = text
                Label.TextColor3 = Theme.TextDark
                Label.TextXAlignment = Enum.TextXAlignment.Left
                Label.Font = FontMain
                Label.TextSize = 13
                Label.Parent = KeyFrame
                
                local KeyInput = Instance.new("TextBox")
                KeyInput.Size = UDim2.new(0.3, 0, 0.8, 0)
                KeyInput.Position = UDim2.new(0.5, 0, 0.1, 0)
                KeyInput.BackgroundColor3 = Theme.ElementBg
                KeyInput.Text = defaultKey
                KeyInput.TextColor3 = Theme.Text
                KeyInput.Font = FontMain
                KeyInput.TextSize = 13
                KeyInput.ClearTextOnFocus = false
                KeyInput.Parent = KeyFrame
                Instance.new("UICorner", KeyInput).CornerRadius = UDim.new(0, 4)
                
                local SetBtn = Instance.new("TextButton")
                SetBtn.Size = UDim2.new(0.15, 0, 0.8, 0)
                SetBtn.Position = UDim2.new(0.85, 0, 0.1, 0)
                SetBtn.BackgroundColor3 = Theme.Accent
                SetBtn.Text = "Set"
                SetBtn.TextColor3 = Theme.Text
                SetBtn.Font = FontBold
                SetBtn.TextSize = 13
                SetBtn.Parent = KeyFrame
                Instance.new("UICorner", SetBtn).CornerRadius = UDim.new(0, 4)
                
                SetBtn.MouseButton1Click:Connect(function()
                    local newKey = string.upper(KeyInput.Text:gsub("%s+", ""))
                    if newKey ~= "" then onKeyChange(newKey) KeyInput.Text = newKey else KeyInput.Text = defaultKey end
                end)
                KeyInput.FocusLost:Connect(function(enterPressed) if enterPressed then SetBtn.MouseButton1Click:Fire() end end)
            end

            function AccordionElements:CreateColorPicker(text, defaultColor, callback)
                local CPFrame = Instance.new("Frame")
                CPFrame.Size = UDim2.new(1, 0, 0, 24)
                CPFrame.BackgroundTransparency = 1
                CPFrame.ClipsDescendants = true
                CPFrame.Parent = ItemContainer
                
                local Label = Instance.new("TextLabel")
                Label.Size = UDim2.new(1, -60, 0, 24)
                Label.Position = UDim2.new(0, 25, 0, 0)
                Label.BackgroundTransparency = 1
                Label.Text = text
                Label.TextColor3 = Theme.TextDark
                Label.TextXAlignment = Enum.TextXAlignment.Left
                Label.Font = FontMain
                Label.TextSize = 12
                Label.Parent = CPFrame
                
                local ColorDisplay = Instance.new("TextButton")
                ColorDisplay.Size = UDim2.new(0, 30, 0, 14)
                ColorDisplay.Position = UDim2.new(1, -40, 0, 5)
                ColorDisplay.BackgroundColor3 = defaultColor
                ColorDisplay.Text = ""
                ColorDisplay.Parent = CPFrame
                Instance.new("UICorner", ColorDisplay).CornerRadius = UDim.new(0, 2)
                task.spawn(function() callback(defaultColor) end)

                local PickerContainer = Instance.new("Frame")
                PickerContainer.Size = UDim2.new(0, 200, 0, 140)
                PickerContainer.Position = UDim2.new(0, 25, 0, 28)
                PickerContainer.BackgroundColor3 = Color3.fromRGB(22, 22, 26)
                PickerContainer.Parent = CPFrame
                Instance.new("UICorner", PickerContainer).CornerRadius = UDim.new(0, 4)

                local currentH, currentS, currentV = defaultColor:ToHSV()
                local SV_Canvas = Instance.new("Frame")
                SV_Canvas.Size = UDim2.new(0, 130, 0, 120)
                SV_Canvas.Position = UDim2.new(0, 10, 0, 10)
                SV_Canvas.BackgroundColor3 = Color3.fromHSV(currentH, 1, 1)
                SV_Canvas.BorderSizePixel = 0
                SV_Canvas.Parent = PickerContainer
                
                local WhiteGrad = Instance.new("Frame")
                WhiteGrad.Size = UDim2.new(1, 0, 1, 0)
                WhiteGrad.Parent = SV_Canvas
                local wg = Instance.new("UIGradient", WhiteGrad)
                wg.Color = ColorSequence.new(Color3.fromRGB(255, 255, 255))
                wg.Transparency = NumberSequence.new(0, 1)
                
                local BlackGrad = Instance.new("Frame")
                BlackGrad.Size = UDim2.new(1, 0, 1, 0)
                BlackGrad.Parent = SV_Canvas
                local bg = Instance.new("UIGradient", BlackGrad)
                bg.Color = ColorSequence.new(Color3.fromRGB(0, 0, 0))
                bg.Rotation = 90
                bg.Transparency = NumberSequence.new(1, 0)
                
                local SV_Cursor = Instance.new("Frame")
                SV_Cursor.Size = UDim2.new(0, 6, 0, 6)
                SV_Cursor.Position = UDim2.new(currentS, -3, 1 - currentV, -3)
                SV_Cursor.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
                SV_Cursor.Parent = SV_Canvas
                Instance.new("UICorner", SV_Cursor).CornerRadius = UDim.new(1, 0)

                local Hue_Track = Instance.new("Frame")
                Hue_Track.Size = UDim2.new(0, 15, 0, 120)
                Hue_Track.Position = UDim2.new(0, 150, 0, 10)
                Hue_Track.Parent = PickerContainer
                local hg = Instance.new("UIGradient", Hue_Track)
                hg.Rotation = 90
                hg.Color = ColorSequence.new({
                    ColorSequenceKeypoint.new(0, Color3.fromRGB(255,0,0)), ColorSequenceKeypoint.new(0.17, Color3.fromRGB(255,255,0)),
                    ColorSequenceKeypoint.new(0.33, Color3.fromRGB(0,255,0)), ColorSequenceKeypoint.new(0.5, Color3.fromRGB(0,255,255)),
                    ColorSequenceKeypoint.new(0.67, Color3.fromRGB(0,0,255)), ColorSequenceKeypoint.new(0.83, Color3.fromRGB(255,0,255)),
                    ColorSequenceKeypoint.new(1, Color3.fromRGB(255,0,0))
                })
                
                local Hue_Cursor = Instance.new("Frame")
                Hue_Cursor.Size = UDim2.new(1, 4, 0, 4)
                Hue_Cursor.Position = UDim2.new(0, -2, currentH, -2)
                Hue_Cursor.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
                Hue_Cursor.Parent = Hue_Track

                local function UpdateColor()
                    local chosenColor = Color3.fromHSV(currentH, currentS, currentV)
                    SV_Canvas.BackgroundColor3 = Color3.fromHSV(currentH, 1, 1)
                    ColorDisplay.BackgroundColor3 = chosenColor
                    callback(chosenColor)
                end

                local draggingSV, draggingHue = false, false
                SV_Canvas.InputBegan:Connect(function(input) if input.UserInputType == Enum.UserInputType.MouseButton1 then draggingSV = true end end)
                Hue_Track.InputBegan:Connect(function(input) if input.UserInputType == Enum.UserInputType.MouseButton1 then draggingHue = true end end)
                UserInputService.InputEnded:Connect(function(input) if input.UserInputType == Enum.UserInputType.MouseButton1 then draggingSV = false; draggingHue = false end end)

                UserInputService.InputChanged:Connect(function(input)
                    if input.UserInputType == Enum.UserInputType.MouseMovement then
                        if draggingSV then
                            local mouseX = math.clamp(input.Position.X - SV_Canvas.AbsolutePosition.X, 0, SV_Canvas.AbsoluteSize.X)
                            local mouseY = math.clamp(input.Position.Y - SV_Canvas.AbsolutePosition.Y, 0, SV_Canvas.AbsoluteSize.Y)
                            currentS = mouseX / SV_Canvas.AbsoluteSize.X
                            currentV = 1 - (mouseY / SV_Canvas.AbsoluteSize.Y)
                            SV_Cursor.Position = UDim2.new(currentS, -3, 1 - currentV, -3)
                            UpdateColor()
                        elseif draggingHue then
                            local mouseY = math.clamp(input.Position.Y - Hue_Track.AbsolutePosition.Y, 0, Hue_Track.AbsoluteSize.Y)
                            currentH = mouseY / Hue_Track.AbsoluteSize.Y
                            Hue_Cursor.Position = UDim2.new(0, -2, currentH, -2)
                            UpdateColor()
                        end
                    end
                end)

                local isPickerOpen = false
                ColorDisplay.MouseButton1Click:Connect(function()
                    isPickerOpen = not isPickerOpen
                    Tween(CPFrame, {Size = UDim2.new(1, 0, 0, isPickerOpen and 175 or 24)}, 0.2)
                end)
            end

            return AccordionElements
        end
        return TabElements
    end

    local openTweenInfo = TweenInfo.new(0.6, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
    TweenService:Create(MainFrame, openTweenInfo, { Size = UDim2.new(0, 650, 0, 420), Position = UDim2.new(0.5, -325, 0.5, -210) }):Play()

    return Window
end

getgenv().GrapeLibrary = Library
return Library
