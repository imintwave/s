-- =============================================================================
-- АВТОНОМНЫЙ ДЕШИФРАТОР И ЗАГРУЗКА БИБЛИОТЕКИ ИНТЕРФЕЙСА (CHAOTIC v11)
-- =============================================================================
local PAYLOAD_URL = "https://raw.githubusercontent.com/LegensSoft/S/refs/heads/main/Iu"

-- 1. Скачивание зашифрованного исходника
local netSuccess, response = pcall(function()
    return game:HttpGet(PAYLOAD_URL)
end)

if not netSuccess then
    warn("❌ [Ошибка сети] Не удалось получить данные по ссылке!")
    return
end

-- Вспомогательная функция XOR
local function luau_xor(a, b)
    if bit32 then
        return bit32.bxor(a, b)
    else
        local r = 0
        for i = 0, 7 do
            if (a % 2) ~= (b % 2) then r = r + 2^i end
            a = math.floor(a / 2)
            b = math.floor(b / 2)
        end
        return r
    end
end

-- Алфавит обфускатора
local symbols = {
    "─", "━", "│", "┃", "┄", "┌", "┐", "└", "┘", "├", "┤", "┬", "┴", "┼", "═", "║", "▲", "▼", "●", "■",
    "╚", "╝", "╔", "╗", "╠", "╣", "╦", "╩", "╬", "◆", "◇", "◈", "◎"
}
local num_symbols = #symbols
local sym_map = {}
for i, sym in ipairs(symbols) do sym_map[sym] = i end

-- Корректное чтение мультибайтовых UTF-8 символов псевдографики
local function parse_symbols(s)
    local chars = {}
    local i = 1
    local b = string.byte
    while i <= #s do
        local b1 = b(s, i)
        local cl = 1
        if b1 >= 240 then cl = 4
        elseif b1 >= 224 then cl = 3
        elseif b1 >= 192 then cl = 2
        end
        chars[#chars+1] = s:sub(i, i + cl - 1)
        i = i + cl
    end
    return chars
end

-- Функция дешифрации
local function deobfuscate(code)
    -- 1. Извлекаем Bootstrap-данные, Payload-данные и Ключ лоадера
    local boot_payload, enc_payload, boot_key_str = code:match('local [%w_]+ = "([^"]+)"%s*;%s*local [%w_]+ = "([^"]+)"%s*;%s*local [%w_]+ = (%d+);')
    
    if not boot_payload or not enc_payload or not boot_key_str then
        return nil, "Не удалось распарсить структуру обфусцированного файла."
    end
    local boot_key = tonumber(boot_key_str)

    -- 2. Расшифровываем первый слой (Bootstrap)
    local boot_chars = parse_symbols(boot_payload)
    local inner_code_bytes = {}
    for idx = 1, #boot_chars, 2 do
        local s1, s2 = boot_chars[idx], boot_chars[idx+1]
        if s1 and s2 then
            local i1 = (sym_map[s1] or 1) - 1
            local i2 = (sym_map[s2] or 1) - 1
            local crypted = i1 * num_symbols + i2
            inner_code_bytes[#inner_code_bytes+1] = string.char(luau_xor(crypted, boot_key))
        end
    end
    local inner_code = table.concat(inner_code_bytes)

    -- 3. Находим математические формулы ключей внутри лоадера и вычисляем их
    local keys_str = inner_code:match("local keys = ({.-});")
    if not keys_str then
        return nil, "Не удалось извлечь внутренние ключи шифрования."
    end

    local keys = {}
    for formula in keys_str:gmatch("%b()") do
        local a, b, c, diff = formula:match("%(%((%d+)%s*%*%s*(%d+)%)%s*%+%s*(%d+)%s*-%s*(%d+)%)")
        if a and b and c and diff then
            -- Вычисляем значение ключа по исходному алгоритму обфускатора
            local k = ((tonumber(a) * tonumber(b)) + tonumber(c) - tonumber(diff)) % 256
            table.insert(keys, k)
        end
    end

    if #keys == 0 then
        return nil, "Ошибка калькуляции динамического массива ключей."
    end

    -- 4. Расшифровываем основной Payload с учетом динамического сдвига (XOR Feedback)
    local payload_chars = parse_symbols(enc_payload)
    local crypted_bytes = {}
    for idx = 1, #payload_chars, 2 do
        local s1, s2 = payload_chars[idx], payload_chars[idx+1]
        if s1 and s2 then
            local i1 = (sym_map[s1] or 1) - 1
            local i2 = (sym_map[s2] or 1) - 1
            crypted_bytes[#crypted_bytes+1] = i1 * num_symbols + i2
        end
    end

    local decrypted_source = {}
    for i = 1, #crypted_bytes do
        local idx = (i % #keys) + 1
        local cur_key = keys[idx]
        local x = crypted_bytes[i]
        
        local decrypted = luau_xor(x, cur_key)
        decrypted_source[#decrypted_source+1] = string.char(decrypted)
        
        -- Важнейший шаг: мутация ключа на основе байта шифротекста
        keys[idx] = math.floor(cur_key + x) % 256
    end

    return table.concat(decrypted_source)
end

-- Выполняем дешифрацию полученных данных
local decrypted_code, decrypt_err = deobfuscate(response)
if not decrypted_code then
    warn("❌ [Ошибка дешифрации] " .. tostring(decrypt_err))
    return
end

-- Компиляция и запуск расшифрованной библиотеки
local load_func = (string.byte("\108") and loadstring) or (_G and _G.loadstring) or (getfenv and getfenv().loadstring)
if not load_func then
    warn("❌ [Критическая ошибка] Ваша среда выполнения не поддерживает loadstring!")
    return
end

local runSuccess, Library = pcall(load_func(decrypted_code))
if not runSuccess or not Library then
    -- Пробуем вытащить Library из глобальной области видимости, если скрипт библиотеки не возвращает её напрямую через return
    Library = Library or _G.Library or shared.Library
end

if not Library then
    warn("❌ [Ошибка запуска] Библиотека успешно расшифрована, но не смогла инициализироваться в 'Library'!")
    return
end


local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local CoreGui = game:GetService("CoreGui")

local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera

-- =============================================================================
-- ПРОВЕРКА МЕТОДОВ
-- =============================================================================
local function checkProperty(className, propertyName)
    local checkSuccess = pcall(function()
        local tempObj = Instance.new(className)
        local val = tempObj[propertyName]
        tempObj:Destroy()
    end)
    return checkSuccess
end

local hasWalkSpeed = checkProperty("Humanoid", "WalkSpeed")
local hasMaxHealth = checkProperty("Humanoid", "MaxHealth")
local hasJumpPower = checkProperty("Humanoid", "JumpPower")
local hasJumpHeight = checkProperty("Humanoid", "JumpHeight")
local hasUseJumpPower = checkProperty("Humanoid", "UseJumpPower")

-- =============================================================================
-- ИЗОЛИРОВАННАЯ ПАПКА ДЛЯ CHAMS И ESP
-- =============================================================================
local ChamsSafeFolder = Instance.new("Folder")
ChamsSafeFolder.Name = "GrapeChamsSafeStorage"
local safeFolderSuccess = pcall(function() ChamsSafeFolder.Parent = CoreGui end)
if not safeFolderSuccess then ChamsSafeFolder.Parent = LocalPlayer:WaitForChild("PlayerGui") end

local ESPConfig = {
    Box = false,
    LineMode = 0,
    Health = false,
    Name = false,
    ColorBox = false,
    Distance = false,
    Rainbow = false,
    Chams = {
        Shader = false,
        Outline = false,
        Rainbow = false
    },
    Colors = {
        Box = Color3.fromRGB(0, 255, 0),
        Line = Color3.fromRGB(255, 255, 255),
        Name = Color3.fromRGB(255, 255, 255),
        Fill = Color3.fromRGB(0, 255, 0),
        Distance = Color3.fromRGB(255, 255, 255),
        ChamsShader = Color3.fromRGB(255, 0, 0),
        ChamsOutline = Color3.fromRGB(255, 255, 255)
    },
    CurrentRainbowColor = Color3.fromRGB(255, 255, 255)
}

local espCache = {}

local function createPlayerESP(player)
    if espCache[player] then return end
    espCache[player] = {
        Box = Drawing.new("Square"),
        Fill = Drawing.new("Square"),
        Line = Drawing.new("Line"),
        Name = Drawing.new("Text"),
        Distance = Drawing.new("Text"),
        HealthBg = Drawing.new("Line"),
        HealthBar = Drawing.new("Line"),
        Highlight = Instance.new("Highlight")
    }
    local obj = espCache[player]
    obj.Box.Thickness = 1.5
    obj.Box.Filled = false
    obj.Fill.Filled = true
    obj.Fill.Transparency = 0.3
    obj.Line.Thickness = 1
    obj.Name.Size = 14
    obj.Name.Center = true
    obj.Name.Outline = true
    obj.Distance.Size = 13
    obj.Distance.Center = true
    obj.Distance.Outline = true
    obj.HealthBg.Thickness = 2.5
    obj.HealthBg.Color = Color3.fromRGB(40, 0, 0)
    obj.HealthBar.Thickness = 2.5
    
    obj.Highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    obj.Highlight.Enabled = false
    obj.Highlight.Parent = ChamsSafeFolder
end

local function removePlayerESP(player)
    if espCache[player] then
        for _, drawingObj in pairs(espCache[player]) do
            if typeof(drawingObj) == "Instance" then
                drawingObj:Destroy()
            else
                drawingObj:Remove()
            end
        end
        espCache[player] = nil
    end
end

Players.PlayerRemoving:Connect(removePlayerESP)

-- =============================================================================
-- ПАРАМЕТРЫ И ФУНКЦИИ ИГРОКА
-- =============================================================================
local DEFAULT_WALKSPEED = 16
local DEFAULT_MAXHEALTH = 100
local DEFAULT_JUMPPOWER = 50
local DEFAULT_JUMPHEIGHT = 7.2

local walkSpeedEnabled = false
local walkSpeedValue = 16
local maxHealthEnabled = false
local maxHealthValue = 100
local useJumpPowerEnabled = true 
local jumpPowerEnabled = false    
local jumpHeightEnabled = false   
local jumpPowerValue = 50
local jumpHeightValue = 12
local spinBotEnabled = false
local spinSpeed = 10

-- Управление курсором V
local cursorLockToggleEnabled = false
local cursorLocked = false

-- =============================================================================
-- ТРЕТЬЕ ЛИЦО (THIRD PERSON) С ВРАЩЕНИЕМ КАМЕРЫ
-- =============================================================================
local thirdPersonEnabled = false
local thirdPersonDistance = 10
local thirdPersonOffsetX = 0
local thirdPersonOffsetY = 2
local thirdPersonHideArms = false

-- Углы поворота камеры
local cameraAngleX = 0
local cameraAngleY = 20

-- Сохранение оригинальной видимости рук
local originalArmsTransparencies = {}

-- Функция скрытия рук в 3-м лице
local function updateArmsVisibility()
    local char = LocalPlayer.Character
    if not char then return end
    
    local armNames = {"LeftArm", "RightArm", "Left Hand", "Right Hand", "LeftUpperArm", "LeftLowerArm", "RightUpperArm", "RightLowerArm"}
    
    for _, name in ipairs(armNames) do
        local part = char:FindFirstChild(name)
        if part and part:IsA("BasePart") then
            if thirdPersonEnabled and thirdPersonHideArms then
                if not originalArmsTransparencies[part] then
                    originalArmsTransparencies[part] = part.Transparency
                end
                part.Transparency = 1
            else
                if originalArmsTransparencies[part] then
                    part.Transparency = originalArmsTransparencies[part]
                    originalArmsTransparencies[part] = nil
                end
            end
        end
    end
end

-- =============================================================================
-- НЕВИДИМОСТЬ ДЛЯ ТЕЛЕКИЛЛА V2
-- =============================================================================
local isInvisible = false
local function setInvisibility(state)
    if isInvisible == state then return end
    
    local char = LocalPlayer.Character
    if not char then return end
    
    local joint = nil
    local humanoid = char:FindFirstChildOfClass("Humanoid")
    if humanoid then
        if humanoid.RigType == Enum.HumanoidRigType.R15 then
            local lowerTorso = char:FindFirstChild("LowerTorso")
            joint = lowerTorso and lowerTorso:FindFirstChild("Root")
        else
            local hrp = char:FindFirstChild("HumanoidRootPart")
            joint = hrp and hrp:FindFirstChild("RootJoint")
        end
    end
    
    if joint then
        isInvisible = state
        if state then
            if not joint:GetAttribute("OriginalC0") then
                joint:SetAttribute("OriginalC0", joint.C0)
            end
            joint.C0 = CFrame.new(0, -99999, 0)
        else
            local orig = joint:GetAttribute("OriginalC0")
            if orig then
                joint.C0 = orig
            end
        end
    end
end

local function setWalkSpeed()
    local c = LocalPlayer.Character
    local h = c and c:FindFirstChildOfClass("Humanoid")
    if h and hasWalkSpeed then h.WalkSpeed = walkSpeedEnabled and walkSpeedValue or DEFAULT_WALKSPEED end
end

local function setMaxHealth()
    local c = LocalPlayer.Character
    local h = c and c:FindFirstChildOfClass("Humanoid")
    if h and hasMaxHealth then
        h.MaxHealth = maxHealthEnabled and maxHealthValue or DEFAULT_MAXHEALTH
        if maxHealthEnabled then h.Health = maxHealthValue 
        elseif h.Health > DEFAULT_MAXHEALTH then h.Health = DEFAULT_MAXHEALTH end
    end
end

local function setUseJumpPower()
    local c = LocalPlayer.Character
    local h = c and c:FindFirstChildOfClass("Humanoid")
    if h and hasUseJumpPower then h.UseJumpPower = useJumpPowerEnabled end
end

local function setJumpPower()
    local c = LocalPlayer.Character
    local h = c and c:FindFirstChildOfClass("Humanoid")
    if h and hasJumpPower then h.JumpPower = jumpPowerEnabled and jumpPowerValue or DEFAULT_JUMPPOWER end
end

local function setJumpHeight()
    local c = LocalPlayer.Character
    local h = c and c:FindFirstChildOfClass("Humanoid")
    if h and hasJumpHeight then h.JumpHeight = jumpHeightEnabled and jumpHeightValue or DEFAULT_JUMPHEIGHT end
end

local function applyAllJumpSettings()
    setUseJumpPower()
    setJumpPower()
    setJumpHeight()
end

local function applyAllSettings()
    setWalkSpeed()
    setMaxHealth()
    applyAllJumpSettings()
end

-- NOCLIP
local noclipEnabled = false
local function toggleNoclip(state) noclipEnabled = state end

-- FLY
local flyEnabled = false
local flySpeed = 50
local flyBodyVel, flyBodyGyro
local flyConnection = nil
local flyCharacter = nil

local function stopFly()
    flyEnabled = false
    if flyConnection then
        flyConnection:Disconnect()
        flyConnection = nil
    end
    if flyBodyVel then flyBodyVel:Destroy(); flyBodyVel = nil end
    if flyBodyGyro then flyBodyGyro:Destroy(); flyBodyGyro = nil end
    
    local c = flyCharacter or LocalPlayer.Character
    if c then
        local h = c:FindFirstChildOfClass("Humanoid")
        if h then h.PlatformStand = false end
    end
    flyCharacter = nil
end

local function createFly()
    local c = LocalPlayer.Character
    if not c then return end
    local root = c:FindFirstChild("HumanoidRootPart")
    local humanoid = c:FindFirstChildOfClass("Humanoid")
    if not root or not humanoid then return end
    
    stopFly()
    flyEnabled = true
    flyCharacter = c
    humanoid.PlatformStand = true
    
    flyBodyGyro = Instance.new("BodyGyro")
    flyBodyGyro.P = 9e4
    flyBodyGyro.MaxTorque = Vector3.new(9e5, 9e5, 9e5)
    flyBodyGyro.CFrame = root.CFrame
    flyBodyGyro.Parent = root
    
    flyBodyVel = Instance.new("BodyVelocity")
    flyBodyVel.Velocity = Vector3.new(0, 0.1, 0)
    flyBodyVel.MaxForce = Vector3.new(9e5, 9e5, 9e5)
    flyBodyVel.Parent = root
    
    flyConnection = RunService.RenderStepped:Connect(function()
        if not flyEnabled or not root or not root.Parent then
            stopFly()
            return
        end
        local camCF = workspace.CurrentCamera.CFrame
        local moveDirection = Vector3.new()
        
        if UserInputService:IsKeyDown(Enum.KeyCode.W) then moveDirection = moveDirection + camCF.LookVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.S) then moveDirection = moveDirection - camCF.LookVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.A) then moveDirection = moveDirection - camCF.RightVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.D) then moveDirection = moveDirection + camCF.RightVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.Space) then moveDirection = moveDirection + Vector3.new(0, 1, 0) end
        if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then moveDirection = moveDirection - Vector3.new(0, 1, 0) end
        
        if moveDirection.Magnitude > 0 then
            flyBodyVel.Velocity = moveDirection.Unit * flySpeed
        else
            flyBodyVel.Velocity = Vector3.new(0, 0.1, 0)
        end
        flyBodyGyro.CFrame = camCF
    end)
end

-- МАСШТАБИРОВАНИЕ И ХИТБОКСЫ
local playersScaleEnabled = false
local playersScaleValue = 5
local hitboxEnabled = false
local hitboxScale = 3

local function saveOriginalSizes(character)
    for _, part in pairs(character:GetDescendants()) do
        if part:IsA("BasePart") then
            if not part:GetAttribute("ScaleOriginalSize") then
                part:SetAttribute("ScaleOriginalSize", part.Size)
                part:SetAttribute("OrigTrans", part.Transparency)
                part:SetAttribute("OrigCollide", part.CanCollide)
            end
        elseif part:IsA("Motor6D") then
            if not part:GetAttribute("OriginalC0") then part:SetAttribute("OriginalC0", part.C0) end
            if not part:GetAttribute("OriginalC1") then part:SetAttribute("OriginalC1", part.C1) end
        end
    end
end

local function applyScaleToPlayer(player, scale)
    local character = player.Character
    if not character or not playersScaleEnabled then return end
    saveOriginalSizes(character)
    
    for _, part in pairs(character:GetDescendants()) do
        if part:IsA("BasePart") then
            local originalSize = part:GetAttribute("ScaleOriginalSize")
            if originalSize then part.Size = originalSize * scale end
        elseif part:IsA("Motor6D") then
            local origC0 = part:GetAttribute("OriginalC0")
            local origC1 = part:GetAttribute("OriginalC1")
            if origC0 and origC1 then
                part.C0 = CFrame.new(origC0.Position * scale) * (origC0 - origC0.Position)
                part.C1 = CFrame.new(origC1.Position * scale) * (origC1 - origC1.Position)
            end
        end
    end
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if humanoid then humanoid.HipHeight = (humanoid.RigType == Enum.HumanoidRigType.R6 and 0 or 2) * scale end
end

local function resetPlayersScale()
    for _, player in pairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Character then
            for _, part in pairs(player.Character:GetDescendants()) do
                if part:IsA("BasePart") then
                    local originalSize = part:GetAttribute("ScaleOriginalSize")
                    if originalSize then part.Size = originalSize end
                elseif part:IsA("Motor6D") then
                    local origC0 = part:GetAttribute("OriginalC0")
                    local origC1 = part:GetAttribute("OriginalC1")
                    if origC0 and origC1 then part.C0 = origC0; part.C1 = origC1 end
                end
            end
            local humanoid = player.Character:FindFirstChildOfClass("Humanoid")
            if humanoid then humanoid.HipHeight = humanoid.RigType == Enum.HumanoidRigType.R6 and 0 or 2 end
        end
    end
end

local function updateAllPlayersScale()
    for _, player in pairs(Players:GetPlayers()) do
        if player ~= LocalPlayer then applyScaleToPlayer(player, playersScaleValue) end
    end
end

local function applyHitboxToPlayer(player, scale)
    local character = player.Character
    if not character or not hitboxEnabled then return end
    saveOriginalSizes(character)
    
    for _, part in pairs(character:GetDescendants()) do
        if part:IsA("BasePart") then
            local originalSize = part:GetAttribute("ScaleOriginalSize")
            if originalSize then part.Size = originalSize * scale end
            part.CanCollide = false
            part.Transparency = 0.75
        elseif part:IsA("Motor6D") then
            local origC0 = part:GetAttribute("OriginalC0")
            local origC1 = part:GetAttribute("OriginalC1")
            if origC0 and origC1 then
                part.C0 = CFrame.new(origC0.Position * scale) * (origC0 - origC0.Position)
                part.C1 = CFrame.new(origC1.Position * scale) * (origC1 - origC1.Position)
            end
        end
    end
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if humanoid then humanoid.HipHeight = (humanoid.RigType == Enum.HumanoidRigType.R6 and 0 or 2) * scale end
end

local function resetHitboxes()
    for _, player in pairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Character then
            for _, part in pairs(player.Character:GetDescendants()) do
                if part:IsA("BasePart") then
                    local originalSize = part:GetAttribute("ScaleOriginalSize")
                    local origTrans = part:GetAttribute("OrigTrans")
                    local origCollide = part:GetAttribute("OrigCollide")
                    if originalSize then part.Size = originalSize end
                    if origTrans then part.Transparency = origTrans end
                    if origCollide ~= nil then part.CanCollide = origCollide end
                elseif part:IsA("Motor6D") then
                    local origC0 = part:GetAttribute("OriginalC0")
                    local origC1 = part:GetAttribute("OriginalC1")
                    if origC0 and origC1 then part.C0 = origC0; part.C1 = origC1 end
                end
            end
            local humanoid = player.Character:FindFirstChildOfClass("Humanoid")
            if humanoid then humanoid.HipHeight = humanoid.RigType == Enum.HumanoidRigType.R6 and 0 or 2 end
        end
    end
end

local function updateAllHitboxes()
    for _, player in pairs(Players:GetPlayers()) do
        if player ~= LocalPlayer then applyHitboxToPlayer(player, hitboxScale) end
    end
end

-- =============================================================================
-- ПАРАМЕТРЫ СТЯГИВАНИЯ И ТЕЛЕПОРТ-КИЛЛА
-- =============================================================================
local massGatherEnabled = false
local massKillV2Enabled = false
local teleKillEnabled = false
local teleKillV2Enabled = false
local teleKillTarget = nil
local skippedTargets = {}

task.spawn(function()
    while task.wait(0.1) do
        if massGatherEnabled then
            local char = LocalPlayer.Character
            local root = char and (char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Torso") or char:FindFirstChild("UpperTorso") or char.PrimaryPart or char:FindFirstChildWhichIsA("BasePart"))
            
            if root then
                for _, player in pairs(Players:GetPlayers()) do
                    if player ~= LocalPlayer then
                        local pChar = player.Character
                        if pChar then
                            local pRoot = pChar:FindFirstChild("HumanoidRootPart") or pChar:FindFirstChild("Torso") or pChar:FindFirstChild("UpperTorso") or pChar.PrimaryPart or pChar:FindFirstChildWhichIsA("BasePart")
                            if pRoot then
                                pRoot.CFrame = root.CFrame * CFrame.new(0, 0, -5)
                            end
                        end
                    end
                end
            end
        end
    end
end)

task.spawn(function()
    while task.wait() do
        if massKillV2Enabled then
            local char = LocalPlayer.Character
            local root = char and (char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Torso") or char:FindFirstChild("UpperTorso") or char.PrimaryPart)
            if root then
                local targetPos = root.CFrame * CFrame.new(0, 0, -5)
                for _, player in pairs(Players:GetPlayers()) do
                    if player ~= LocalPlayer then
                        local pChar = player.Character
                        if pChar then
                            local pRoot = pChar:FindFirstChild("HumanoidRootPart") or pChar:FindFirstChild("Torso") or pChar:FindFirstChild("UpperTorso") or pChar.PrimaryPart
                            if pRoot then
                                pRoot.CFrame = targetPos
                                for _, part in pairs(pChar:GetChildren()) do
                                    if part:IsA("BasePart") then
                                        part.AssemblyLinearVelocity = Vector3.zero
                                        part.AssemblyAngularVelocity = Vector3.zero
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
    end
end)

local function getClosestTeleKillTarget()
    local closest = nil
    local closestDist = math.huge
    local myChar = LocalPlayer.Character
    local myRoot = myChar and (myChar:FindFirstChild("HumanoidRootPart") or myChar:FindFirstChild("Torso") or myChar.PrimaryPart)
    if not myRoot then return nil end

    local availablePlayers = {}
    local hasUnskippedTargets = false

    for _, player in pairs(Players:GetPlayers()) do
        if player ~= LocalPlayer then
            local character = player.Character
            if not character then continue end
            
            local humanoid = character:FindFirstChildOfClass("Humanoid")
            if humanoid and humanoid.Health <= 0 then continue end
            
            local root = character:FindFirstChild("HumanoidRootPart") or character:FindFirstChild("Torso") or character:FindFirstChild("UpperTorso") or character.PrimaryPart
            if not root then continue end
            
            if not skippedTargets[player] then
                hasUnskippedTargets = true
            end
            table.insert(availablePlayers, {player = player, root = root})
        end
    end

    if not hasUnskippedTargets then
        table.clear(skippedTargets)
    end

    for _, data in ipairs(availablePlayers) do
        local player = data.player
        if skippedTargets[player] then continue end
        
        local dist = (myRoot.Position - data.root.Position).Magnitude
        if dist < closestDist then
            closestDist = dist
            closest = player
        end
    end
    return closest
end

task.spawn(function()
    while task.wait() do
        if teleKillEnabled or teleKillV2Enabled then
            local myChar = LocalPlayer.Character
            local myRoot = myChar and (myChar:FindFirstChild("HumanoidRootPart") or myChar:FindFirstChild("Torso") or myChar.PrimaryPart)
            
            if myRoot then
                local validTarget = false
                
                if teleKillTarget and teleKillTarget.Parent then
                    local tChar = teleKillTarget.Character
                    if tChar then
                        local tHumanoid = tChar:FindFirstChildOfClass("Humanoid")
                        local tRoot = tChar:FindFirstChild("HumanoidRootPart") or tChar:FindFirstChild("Torso") or tChar:FindFirstChild("UpperTorso") or tChar.PrimaryPart
                        
                        if tRoot and (not tHumanoid or tHumanoid.Health > 0) and not skippedTargets[teleKillTarget] then
                            validTarget = true
                            local targetPos = tRoot.Position
                            
                            if teleKillV2Enabled then
                                setInvisibility(true)
                                local behindPos = targetPos - (tRoot.CFrame.LookVector * 3) + Vector3.new(0, 1, 0)
                                myRoot.CFrame = CFrame.lookAt(behindPos, targetPos)
                            else
                                setInvisibility(false)
                                local behindPos = targetPos - (tRoot.CFrame.LookVector * 3) + Vector3.new(0, 1, 0)
                                myRoot.CFrame = CFrame.lookAt(behindPos, targetPos)
                            end
                        end
                    end
                end
                
                if not validTarget then
                    teleKillTarget = getClosestTeleKillTarget()
                end
            end
        else
            teleKillTarget = nil
            table.clear(skippedTargets)
            setInvisibility(false)
        end
    end
end)

-- =============================================================================
-- ОБРАБОТЧИК НАЖАТИЯ КЛАВИШ
-- =============================================================================
UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    
    if input.KeyCode == Enum.KeyCode.Right or input.KeyCode == Enum.KeyCode.R then
        if (teleKillEnabled or teleKillV2Enabled) and teleKillTarget then
            skippedTargets[teleKillTarget] = true
            teleKillTarget = nil
        end
    end
    
    if input.KeyCode == Enum.KeyCode.V then
        if cursorLockToggleEnabled then
            cursorLocked = not cursorLocked
        end
    end
end)

-- Отслеживаем движение мыши для вращения камеры в 3-м лице
UserInputService.InputChanged:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    if input.UserInputType == Enum.UserInputType.MouseMovement then
        if thirdPersonEnabled then
            -- Вращаем камеру только если зажата ПКМ
            if UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2) then
                local delta = input.Delta
                cameraAngleX = cameraAngleX - delta.X * 0.5
                cameraAngleY = math.clamp(cameraAngleY - delta.Y * 0.5, -80, 80)
            end
        end
    end
end)

-- =============================================================================
-- ОСНОВНОЙ ЦИКЛ (ESP + ДВИЖЕНИЕ + 3-ЛИЦО)
-- =============================================================================
RunService.RenderStepped:Connect(function()
    if not Camera or not Camera.Parent then
        Camera = workspace.CurrentCamera
    end

    -- РАБОТА ТРЕТЬЕГО ЛИЦА
    if thirdPersonEnabled then
        local char = LocalPlayer.Character
        local root = char and (char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Torso") or char:FindFirstChild("UpperTorso"))
        
        if root then
            -- Вычисляем позицию камеры с учетом углов поворота
            local rotation = CFrame.Angles(0, math.rad(cameraAngleX), 0) * CFrame.Angles(math.rad(cameraAngleY), 0, 0)
            local offset = rotation * Vector3.new(thirdPersonOffsetX, thirdPersonOffsetY, thirdPersonDistance)
            
            local camPos = root.Position + offset
            local lookAt = root.Position + Vector3.new(0, 1, 0)
            
            Camera.CameraType = Enum.CameraType.Scriptable
            Camera.CFrame = CFrame.lookAt(camPos, lookAt)
            
            updateArmsVisibility()
        end
    else
        -- Возвращаем стандартную камеру
        Camera.CameraType = Enum.CameraType.Custom
        updateArmsVisibility()
    end

    -- ESP
    for _, p in pairs(Players:GetPlayers()) do
        if p ~= LocalPlayer and not espCache[p] then
            createPlayerESP(p)
        end
    end

    ESPConfig.CurrentRainbowColor = Color3.fromHSV((tick() * 0.2) % 1, 1, 1)
    
    for player, obj in pairs(espCache) do
        local character = player.Character
        local root = character and (character:FindFirstChild("HumanoidRootPart") or character:FindFirstChild("Torso") or character:FindFirstChild("UpperTorso") or character.PrimaryPart or character:FindFirstChildWhichIsA("BasePart"))
        local humanoid = character and character:FindFirstChildOfClass("Humanoid")
        
        local isAlive = true
        if humanoid and humanoid.Health <= 0 then
            isAlive = false
        end
        
        if character and root and isAlive then
            local hl = obj.Highlight
            if hl.Adornee ~= character then hl.Adornee = character end

            if ESPConfig.Chams.Shader or ESPConfig.Chams.Outline then
                hl.Enabled = true
                hl.FillColor = ESPConfig.Chams.Rainbow and ESPConfig.CurrentRainbowColor or ESPConfig.Colors.ChamsShader
                hl.OutlineColor = ESPConfig.Chams.Rainbow and ESPConfig.CurrentRainbowColor or ESPConfig.Colors.ChamsOutline
                hl.FillTransparency = ESPConfig.Chams.Shader and 0.4 or 1
                hl.OutlineTransparency = ESPConfig.Chams.Outline and 0 or 1
            else
                hl.Enabled = false
            end
            
            local screenPos, onScreen = Camera:WorldToViewportPoint(root.Position)
            if onScreen then
                local distance = (Camera.CFrame.Position - root.Position).Magnitude
                if distance < 1 then distance = 1 end
                local width = 1000 / distance
                local height = 1500 / distance
                local boxX = screenPos.X - width / 2
                local boxY = screenPos.Y - height / 2
                
                if ESPConfig.Box then
                    obj.Box.Position = Vector2.new(boxX, boxY)
                    obj.Box.Size = Vector2.new(width, height)
                    obj.Box.Color = ESPConfig.Rainbow and ESPConfig.CurrentRainbowColor or ESPConfig.Colors.Box
                    obj.Box.Visible = true
                else
                    obj.Box.Visible = false
                end
                
                if ESPConfig.LineMode > 0 then
                    local startVector
                    if ESPConfig.LineMode == 1 then startVector = Vector2.new(Camera.ViewportSize.X / 2, 0)
                    elseif ESPConfig.LineMode == 2 then startVector = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
                    elseif ESPConfig.LineMode == 3 then startVector = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y) end
                    obj.Line.From = startVector
                    obj.Line.To = Vector2.new(screenPos.X, boxY + height)
                    obj.Line.Color = ESPConfig.Rainbow and ESPConfig.CurrentRainbowColor or ESPConfig.Colors.Line
                    obj.Line.Visible = true
                else
                    obj.Line.Visible = false
                end
                
                if ESPConfig.Health then
                    local barX = boxX - 6
                    obj.HealthBg.From = Vector2.new(barX, boxY)
                    obj.HealthBg.To = Vector2.new(barX, boxY + height)
                    obj.HealthBg.Visible = true
                    
                    local hpValue = humanoid and humanoid.Health or 100
                    local maxHpValue = humanoid and humanoid.MaxHealth or 100
                    if maxHpValue == 0 then maxHpValue = 100 end
                    
                    local healthPercent = math.clamp(hpValue / maxHpValue, 0, 1)
                    obj.HealthBar.From = Vector2.new(barX, boxY + height)
                    obj.HealthBar.To = Vector2.new(barX, boxY + height - (height * healthPercent))
                    obj.HealthBar.Color = Color3.fromRGB(255 * (1 - healthPercent), 255 * healthPercent, 0)
                    obj.HealthBar.Visible = true
                else
                    obj.HealthBg.Visible = false
                    obj.HealthBar.Visible = false
                end
                
                if ESPConfig.Name then
                    obj.Name.Position = Vector2.new(screenPos.X, boxY - 16)
                    obj.Name.Text = player.Name
                    obj.Name.Color = ESPConfig.Rainbow and ESPConfig.CurrentRainbowColor or ESPConfig.Colors.Name
                    obj.Name.Visible = true
                else
                    obj.Name.Visible = false
                end
                
                if ESPConfig.ColorBox then
                    obj.Fill.Position = Vector2.new(boxX, boxY)
                    obj.Fill.Size = Vector2.new(width, height)
                    obj.Fill.Color = ESPConfig.Rainbow and ESPConfig.CurrentRainbowColor or ESPConfig.Colors.Fill
                    obj.Fill.Visible = true
                else
                    obj.Fill.Visible = false
                end
                
                if ESPConfig.Distance then
                    obj.Distance.Position = Vector2.new(screenPos.X, boxY + height + 4)
                    obj.Distance.Text = math.floor(distance) .. " studs"
                    obj.Distance.Color = ESPConfig.Rainbow and ESPConfig.CurrentRainbowColor or ESPConfig.Colors.Distance
                    obj.Distance.Visible = true
                else
                    obj.Distance.Visible = false
                end
            else
                for dName, drawingObj in pairs(obj) do
                    if dName ~= "Highlight" then drawingObj.Visible = false end
                end
            end
        else
            for dName, drawingObj in pairs(obj) do
                if dName == "Highlight" then
                    drawingObj.Enabled = false
                    drawingObj.Adornee = nil
                else
                    drawingObj.Visible = false
                end
            end
        end
    end

    -- ПАРАМЕТРЫ ПЕРСОНАЖА
    local myChar = LocalPlayer.Character
    local myHum = myChar and myChar:FindFirstChildOfClass("Humanoid")
    local myRoot = myChar and myChar:FindFirstChild("HumanoidRootPart")
    
    if myHum then
        if walkSpeedEnabled and hasWalkSpeed then myHum.WalkSpeed = walkSpeedValue end
        if maxHealthEnabled and hasMaxHealth then myHum.MaxHealth = maxHealthValue end
        if jumpPowerEnabled and hasJumpPower then myHum.JumpPower = jumpPowerValue end
        if jumpHeightEnabled and hasJumpHeight then myHum.JumpHeight = jumpHeightValue end
    end
    
    if spinBotEnabled and myRoot then
        myRoot.CFrame = myRoot.CFrame * CFrame.Angles(0, math.rad(spinSpeed), 0)
    end
    
    if noclipEnabled and myChar then
        for _, part in pairs(myChar:GetDescendants()) do
            if part:IsA("BasePart") then part.CanCollide = false end
        end
    end
    
    -- БЛОКИРОВКА КУРСОРА
    if cursorLockToggleEnabled then
        if cursorLocked then
            UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
        else
            UserInputService.MouseBehavior = Enum.MouseBehavior.Default
        end
    else
        if cursorLocked then
            cursorLocked = false
            UserInputService.MouseBehavior = Enum.MouseBehavior.Default
        end
    end
    
    if playersScaleEnabled or hitboxEnabled then
        local currentMultiplier = hitboxEnabled and hitboxScale or playersScaleValue
        for _, player in pairs(Players:GetPlayers()) do
            if player ~= LocalPlayer and player.Character then
                local anyPart = player.Character:FindFirstChild("HumanoidRootPart") or player.Character:FindFirstChildWhichIsA("BasePart")
                if anyPart then
                    local originalSize = anyPart:GetAttribute("ScaleOriginalSize")
                    if originalSize then
                        local expectedSize = originalSize * currentMultiplier
                        if (anyPart.Size - expectedSize).Magnitude > 0.05 then
                            if hitboxEnabled then applyHitboxToPlayer(player, hitboxScale) else applyScaleToPlayer(player, playersScaleValue) end
                        end
                    else
                        if hitboxEnabled then applyHitboxToPlayer(player, hitboxScale) else applyScaleToPlayer(player, playersScaleValue) end
                    end
                end
            end
        end
    end
end)

LocalPlayer.CharacterAdded:Connect(function(character)
    isInvisible = false
    table.clear(originalArmsTransparencies)
    task.wait(0.5)
    applyAllSettings()
    if flyEnabled then createFly() end
end)

if LocalPlayer.Character then applyAllSettings() end

Players.PlayerAdded:Connect(function(player)
    player.CharacterAdded:Connect(function()
        task.wait(0.5)
        if hitboxEnabled then applyHitboxToPlayer(player, hitboxScale)
        elseif playersScaleEnabled then applyScaleToPlayer(player, playersScaleValue) end
    end)
end)

-- =============================================================================
-- AIMBOT
-- =============================================================================
local aimbotEnabled = false
local aimbotFOV = 200
local aimbotAutoAim = false
local aimbotTargetMode = "Head"
local aimbotHitChance = 100
local aimbotSmoothing = 1

local fovCircle = Drawing.new("Circle")
fovCircle.Thickness = 1.5
fovCircle.Radius = aimbotFOV
fovCircle.Filled = false
fovCircle.Color = Color3.fromRGB(255, 255, 255)
fovCircle.Transparency = 0.5
fovCircle.Visible = false
fovCircle.ZIndex = 0

local function GetClosestPlayer3D()
    local closest = nil
    local closestDist = math.huge
    local camPos = Camera.CFrame.Position
    for _, player in pairs(Players:GetPlayers()) do
        if player ~= LocalPlayer then
            local character = player.Character
            if not character then continue end
            
            local humanoid = character:FindFirstChildOfClass("Humanoid")
            if humanoid and humanoid.Health <= 0 then continue end
            
            local targetPart = character:FindFirstChild(aimbotTargetMode) or character:FindFirstChild("HumanoidRootPart") or character:FindFirstChild("Torso") or character:FindFirstChild("UpperTorso") or character.PrimaryPart or character:FindFirstChildWhichIsA("BasePart")
            if not targetPart then continue end
            
            local distance = (camPos - targetPart.Position).Magnitude
            if distance < closestDist then
                closestDist = distance
                closest = { Player = player, Position = targetPart.Position }
            end
        end
    end
    return closest
end

local function GetClosestPlayerFOV()
    local closest = nil
    local closestDist = math.huge
    local mousePos = UserInputService:GetMouseLocation()
    for _, player in pairs(Players:GetPlayers()) do
        if player ~= LocalPlayer then
            local character = player.Character
            if not character then continue end
            
            local humanoid = character:FindFirstChildOfClass("Humanoid")
            if humanoid and humanoid.Health <= 0 then continue end
            
            local targetPart = character:FindFirstChild(aimbotTargetMode) or character:FindFirstChild("HumanoidRootPart") or character:FindFirstChild("Torso") or character:FindFirstChild("UpperTorso") or character.PrimaryPart or character:FindFirstChildWhichIsA("BasePart")
            if not targetPart then continue end
            
            local screenPos, onScreen = Camera:WorldToViewportPoint(targetPart.Position)
            if not onScreen then continue end
            local dx = screenPos.X - mousePos.X
            local dy = screenPos.Y - mousePos.Y
            local dist = math.sqrt(dx * dx + dy * dy)
            if dist < closestDist and dist < aimbotFOV then
                closestDist = dist
                closest = { Player = player, Position = targetPart.Position }
            end
        end
    end
    return closest
end

local function InstantAim(targetPos)
    if not targetPos then return end
    
    if math.random(1, 100) > aimbotHitChance then
        return
    end
    
    local targetCF = CFrame.lookAt(Camera.CFrame.Position, targetPos)
    if aimbotSmoothing > 1 then
        Camera.CFrame = Camera.CFrame:Lerp(targetCF, 1 / aimbotSmoothing)
    else
        Camera.CFrame = targetCF
    end
end

local aimbotConnection = nil
local function StartAimbot()
    if aimbotConnection then return end
    aimbotConnection = RunService.RenderStepped:Connect(function()
        fovCircle.Position = UserInputService:GetMouseLocation()
        fovCircle.Radius = aimbotFOV
        if not aimbotEnabled then return end
        local target = nil
        if aimbotAutoAim then
            target = GetClosestPlayer3D()
        else
            if UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2) then
                target = GetClosestPlayerFOV()
            end
        end
        if target then InstantAim(target.Position) end
    end)
end

-- =============================================================================
-- МЕНЮ
-- =============================================================================
local Menu = Library:CreateWindow("UniversalRoblox")

local TabAim = Menu:CreateTab("Aim")
local TabPlayers = Menu:CreateTab("Players")
local TabVisuals = Menu:CreateTab("Visuals")
local TabMovement = Menu:CreateTab("Movement")

-- Aim
local AimbotSection = TabAim:CreateAccordion("Aimbot")
AimbotSection:CreateToggle("Aimbot ON/OFF", function(state)
    aimbotEnabled = state
    if state then
        fovCircle.Visible = true
        StartAimbot()
    else
        fovCircle.Visible = false
        if aimbotConnection then aimbotConnection:Disconnect(); aimbotConnection = nil end
    end
end)
AimbotSection:CreateSlider("Hit Chance (10-100%)", 10, 100, 100, function(value) aimbotHitChance = value end)
AimbotSection:CreateSlider("Smoothing (1-20)", 1, 20, 1, function(value) aimbotSmoothing = value end)
AimbotSection:CreateSlider("FOV (50-500)", 50, 500, 200, function(value) aimbotFOV = value; fovCircle.Radius = value end)
AimbotSection:CreateToggle("Auto Aim (3D Closest)", function(state) aimbotAutoAim = state end)
local targetIndex = 1
local targetOptions = {"Head", "Body"}
AimbotSection:CreateToggle("Target: Head/Body", function(state)
    if state then
        targetIndex = targetIndex % #targetOptions + 1
        aimbotTargetMode = targetOptions[targetIndex]
    end
end)

-- Players
local RandgollSection = TabPlayers:CreateAccordion("Randgoll")
RandgollSection:CreateToggle("Spin Bot", function(state) spinBotEnabled = state end)
RandgollSection:CreateSlider("Spin Speed (1-999)", 1, 999, 10, function(value) spinSpeed = value end)

local TrollSection = TabPlayers:CreateAccordion("Trolling")
TrollSection:CreateToggle("Mass Gather V1 (Server)", function(state) massGatherEnabled = state end)
TrollSection:CreateToggle("Mass Kill V2 (Client Bring)", function(state) massKillV2Enabled = state end)
TrollSection:CreateToggle("Tele Kill (Lock TP)", function(state)
    if state and teleKillV2Enabled then teleKillV2Enabled = false; setInvisibility(false) end
    teleKillEnabled = state
end)
TrollSection:CreateToggle("Tele Kill V2 (Invisible)", function(state)
    if state and teleKillEnabled then teleKillEnabled = false end
    teleKillV2Enabled = state
    if not state then setInvisibility(false) end
end)

local PlayerSection = TabPlayers:CreateAccordion("Player Settings")
PlayerSection:CreateToggle("V-Key Lock Enable", function(state)
    cursorLockToggleEnabled = state
    if not state then
        cursorLocked = false
        UserInputService.MouseBehavior = Enum.MouseBehavior.Default
    end
end)

if hasMaxHealth then
    PlayerSection:CreateToggle("Max Health", function(state) maxHealthEnabled = state; setMaxHealth() end)
    PlayerSection:CreateSlider("Health Value (1-1000)", 1, 1000, 100, function(value) maxHealthValue = value; if maxHealthEnabled then setMaxHealth() end end)
end
if hasWalkSpeed then
    PlayerSection:CreateToggle("Walk Speed", function(state) walkSpeedEnabled = state; setWalkSpeed() end)
    PlayerSection:CreateSlider("Speed Value (1-100)", 1, 100, 16, function(value) walkSpeedValue = value; if walkSpeedEnabled then setWalkSpeed() end end)
end
if hasUseJumpPower then
    PlayerSection:CreateToggle("Use Jump Power", function(state) useJumpPowerEnabled = state; setUseJumpPower() end)
end
if hasJumpPower then
    PlayerSection:CreateToggle("Jump Power", function(state) jumpPowerEnabled = state; setJumpPower() end)
    PlayerSection:CreateSlider("Jump Power Value (1-1000)", 1, 1000, 50, function(value) jumpPowerValue = value; if jumpPowerEnabled then setJumpPower() end end)
end
if hasJumpHeight then
    PlayerSection:CreateToggle("Jump Height", function(state) jumpHeightEnabled = state; setJumpHeight() end)
    PlayerSection:CreateSlider("Jump Height Value (1-100)", 1, 100, 12, function(value) jumpHeightValue = value; if jumpHeightEnabled then setJumpHeight() end end)
end

-- Movement
local NoclipSection = TabMovement:CreateAccordion("Noclip")
NoclipSection:CreateToggle("Noclip", function(state) toggleNoclip(state) end)

local FlySection = TabMovement:CreateAccordion("Fly")
FlySection:CreateToggle("Fly", function(state) if state then createFly() else stopFly() end end)
FlySection:CreateSlider("Fly Speed (1-200)", 1, 200, 50, function(value) flySpeed = value end)

-- Visuals
local EspSection = TabVisuals:CreateAccordion("ESP")
EspSection:CreateToggle("ESP Box", function(state) ESPConfig.Box = state end)
EspSection:CreateColorPicker("Box Color", Color3.fromRGB(0, 255, 0), function(color) ESPConfig.Colors.Box = color end)
EspSection:CreateSlider("ESP Line (0:Off, 1:Top, 2:Center, 3:Bot)", 0, 3, 0, function(value) ESPConfig.LineMode = value end)
EspSection:CreateColorPicker("Line Color", Color3.fromRGB(255, 255, 255), function(color) ESPConfig.Colors.Line = color end)
EspSection:CreateToggle("ESP Health", function(state) ESPConfig.Health = state end)
EspSection:CreateToggle("ESP Name", function(state) ESPConfig.Name = state end)
EspSection:CreateColorPicker("Name Color", Color3.fromRGB(255, 255, 255), function(color) ESPConfig.Colors.Name = color end)
EspSection:CreateToggle("ESP Fill", function(state) ESPConfig.ColorBox = state end)
EspSection:CreateColorPicker("Fill Color", Color3.fromRGB(0, 255, 0), function(color) ESPConfig.Colors.Fill = color end)
EspSection:CreateToggle("ESP Distance", function(state) ESPConfig.Distance = state end)
EspSection:CreateColorPicker("Distance Color", Color3.fromRGB(255, 255, 255), function(color) ESPConfig.Colors.Distance = color end)
EspSection:CreateToggle("ESP Rainbow", function(state) ESPConfig.Rainbow = state end)

local ChamsSection = TabVisuals:CreateAccordion("Chams")
ChamsSection:CreateToggle("Chams Shader", function(state) ESPConfig.Chams.Shader = state end)
ChamsSection:CreateColorPicker("Chams Color", Color3.fromRGB(255, 0, 0), function(color) ESPConfig.Colors.ChamsShader = color end)
ChamsSection:CreateToggle("Outline", function(state) ESPConfig.Chams.Outline = state end)
ChamsSection:CreateColorPicker("Outline Color", Color3.fromRGB(255, 255, 255), function(color) ESPConfig.Colors.ChamsOutline = color end)
ChamsSection:CreateToggle("Rainbow Chams", function(state) ESPConfig.Chams.Rainbow = state end)

-- =============================================================================
-- НАСТРОЙКИ 3-ГО ЛИЦА
-- =============================================================================
local CameraSection = TabVisuals:CreateAccordion("Third Person (3-Лицо)")

CameraSection:CreateToggle("Enable Third Person", function(state)
    thirdPersonEnabled = state
    if state then
        -- При включении устанавливаем углы по умолчанию
        cameraAngleX = 0
        cameraAngleY = 20
    else
        Camera.CameraType = Enum.CameraType.Custom
    end
end)

CameraSection:CreateToggle("Hide Arms in 3D", function(state)
    thirdPersonHideArms = state
end)

CameraSection:CreateSlider("Camera Distance (2-50)", 2, 50, 10, function(value)
    thirdPersonDistance = value
end)

CameraSection:CreateSlider("Offset X (-10 to 10)", -10, 10, 0, function(value)
    thirdPersonOffsetX = value
end)

CameraSection:CreateSlider("Offset Y (-10 to 10)", -10, 10, 2, function(value)
    thirdPersonOffsetY = value
end)

-- Scale
local ScaleSection = TabVisuals:CreateAccordion("Player Scale")
ScaleSection:CreateToggle("Enable Player Scale", function(state)
    playersScaleEnabled = state
    if state then
        if hitboxEnabled then hitboxEnabled = false; resetHitboxes() end
        updateAllPlayersScale()
    else
        resetPlayersScale()
    end 
end)
ScaleSection:CreateSlider("Scale Value (1-20)", 1, 20, 5, function(value)
    playersScaleValue = value
    if playersScaleEnabled then updateAllPlayersScale() end
end)

local HitboxSection = TabVisuals:CreateAccordion("Hitbox Expander")
HitboxSection:CreateToggle("Enable Hitbox Expander", function(state)
    hitboxEnabled = state
    if state then
        if playersScaleEnabled then playersScaleEnabled = false; resetPlayersScale() end
        updateAllHitboxes()
    else
        resetHitboxes()
    end
end)
HitboxSection:CreateSlider("Hitbox Scale (1-10)", 1, 10, 3, function(value)
    hitboxScale = value
    if hitboxEnabled then updateAllHitboxes() end
end)

print("✅ Grape Remastered V2: Menu loaded successfully!")
print("✅ 3-е лицо работает с вращением камеры по ПКМ!")
