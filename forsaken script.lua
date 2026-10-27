-- ============================================================
--  FORSAKEN HUB v4.1 — Android Optimised, Full Feature Suite
--  Game: Forsaken (Roblox) | Asymmetrical Survivor/Killer Horror
--  Runtime: Lua 5.1 (Roblox Luau)
--  Executor: Delta / Arceus X / Fluxus (mobile)
--
--  v4.1 CHANGES vs v4.0:
--   20/48. Remove lobby NPCs (merged — one toggle)
--   21.    Auto-pick Gears
--   23.    Auto-block hitbox TP (M1 dodge)
--   24.    Gen ESP auto-off on gen complete
--   26.    ESP for new items (water sprayer, gears, fruits)
--   28.    Veronica features rewritten + hitbox restore
--   31.    Silent aim prediction (Azure, Beam, Nova, Sixer, Corrupt Nature)
--   44.    Helperbot range extension / anti-miss
--   45.    FPS optimisation — all hot loops cache & throttle
--   46.    Killer ESP color swap on stun, restore after
--   47.    Remove ragdolls for optimisation
-- ============================================================

local Players          = game:GetService("Players")
local RunService       = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService     = game:GetService("TweenService")
local Workspace        = game:GetService("Workspace")
local ReplicatedStorage= game:GetService("ReplicatedStorage")
local TeleportService  = game:GetService("TeleportService")
local StarterGui       = game:GetService("StarterGui")
local HttpService      = game:GetService("HttpService")

local LP     = Players.LocalPlayer
local Camera = Workspace.CurrentCamera

-- ┌─────────────────────────────────────────────────────────┐
-- │              GLOBAL CONNECTION REGISTRY                  │
-- └─────────────────────────────────────────────────────────┘
local CONNS  = {}
local LOADED = true

local function trackConn(c) if c then table.insert(CONNS, c) end; return c end
local function disconnectAll()
    for _, c in ipairs(CONNS) do pcall(function() c:Disconnect() end) end
    CONNS = {}
end

-- ┌─────────────────────────────────────────────────────────┐
-- │                   CONFIG BLOCK                           │
-- └─────────────────────────────────────────────────────────┘
local CFG = {
    -- STAMINA
    INF_STAMINA          = false,
    STAMINA_REFILL_SPEED = false,
    NO_SPRINT_PENALTY    = false,

    -- VISUAL
    FULL_BRIGHT          = false,
    NO_FOG               = false,
    CUSTOM_FOV           = false,
    FOV_VALUE            = 90,
    CHAMS_SELF           = false,
    CROSSHAIR            = false,
    REMOVE_BLUR          = false,
    REMOVE_ACID          = false,
    REMOVE_SLOWNESS      = false,
    REMOVE_BLINDNESS     = false,
    INVISIBLE_MODE       = false,

    -- [#47] Remove ragdolls for optimisation
    REMOVE_RAGDOLLS      = false,

    -- [#20/#48] Remove lobby NPCs
    REMOVE_LOBBY_NPCS    = false,

    -- GENERATORS
    GEN_ESP              = false,
    GEN_ESP_COLOR        = Color3.fromRGB(255, 220, 0),
    AUTO_GEN             = false,
    GEN_RANGE            = 10,
    GEN_PROGRESS_ESP     = false,
    INSTA_GEN            = false,
    -- [#24] Auto-off gen ESP when gen completes
    GEN_ESP_AUTO_OFF     = false,

    -- BLOCK / SHIELD
    AUTO_BLOCK           = false,
    BLOCK_RANGE          = 20,
    BLOCK_HOLD           = false,
    PERFECT_BLOCK        = false,
    SHIELD_DETECT        = false,
    SHIELD_SUPPRESS_STUN = false,
    SHIELD_TIMER_SECS    = 4.0,
    _killerShieldActive  = false,
    _killerShieldExpiry  = 0,

    -- [#23] Auto-block hitbox TP dodge
    -- When killer M1s within M1_TP_RANGE, survivor TP-dodges BLOCK_TP_DIST studs sideways
    AUTO_BLOCK_TP        = false,
    BLOCK_TP_RANGE       = 6.0,   -- studs: trigger radius for M1 detect
    BLOCK_TP_DIST        = 4.0,   -- studs: how far to slide on dodge
    _blockTpCooldown     = 0,
    BLOCK_TP_COOLDOWN    = 0.4,   -- seconds between dodge fires

    -- SURVIVORS
    SURVIVOR_ESP         = false,
    SURV_COLOR           = Color3.fromRGB(50, 255, 80),
    SURV_SHOW_HEALTH     = false,
    SURV_SHOW_NAME       = true,
    SPEED_HACK           = false,
    SPEED_VALUE          = 28.0,
    SPEED_DEFAULT        = 16.0,
    CHASE_SPEED_BOOST    = false,
    CHASE_SPEED_MULT     = 1.5,
    _inChase             = false,
    JOHNDOE_TRAP_SPEED   = false,
    JOHNDOE_TRAP_VAL     = 5.0,
    JOHNDOE_TRAP_RANGE   = 8.0,
    TPLAG_ENABLED        = false,
    TPLAG_INTERVAL       = 0.3,
    TPLAG_DIST           = 6.0,
    _tplagLast           = 0,
    JUMP_POWER           = false,
    JUMP_VALUE           = 80.0,
    NOCLIP               = false,
    NOCLIP_SAFE          = true,
    AUTO_HEAL            = false,
    HEAL_THRESHOLD       = 50.0,
    TP_TO_HOOKED         = false,
    PUSH_OVERRIDE        = false,
    PUSH_AMOUNT          = 80.0,
    BLOOD_STACK_MULT     = false,
    BLOOD_MULT_VALUE     = 2.0,

    -- KILLERS
    KILLER_ESP           = false,
    KILLER_COLOR         = Color3.fromRGB(255, 50, 50),
    -- [#46] Stun color
    KILLER_STUN_COLOR    = Color3.fromRGB(80, 180, 255),
    KILLER_DIST_ALERT    = false,
    KILLER_ALERT_RANGE   = 40.0,
    SHOW_KILLER_NAME     = true,
    AUTO_SLASH           = false,
    SLASH_RANGE          = 8.0,
    DOUBLE_BACKSTAB      = false,
    BACKSTAB_FOV         = 45.0,
    BACKSTAB_SMOOTH      = 0.18,
    _backstabState       = 0,
    _backstabTarget      = nil,
    AUTO_BACKSTAB        = false,
    KILL_AURA            = false,
    AUTO_GASH            = false,
    GASH_BLEED_THRESH    = 2,
    -- [#28] Veronica — rewritten
    VERONICA_BUMPER      = false,
    VERONICA_BUMPER_SIZE = 8.0,   -- studs, was hardcoded
    _veronicaOrigSizes   = {},    -- [#28] store originals for restore
    NO_KILLER_SKATE      = false,
    HITBOX_EXTENDER      = false,
    HITBOX_SIZE          = 6.0,

    -- AIMBOT
    AIMBOT               = false,
    AIMBOT_FOV           = 60.0,
    AIMBOT_SMOOTHING     = 0.25,
    AIMBOT_TARGET        = "Head",
    AIMBOT_KILLER_ONLY   = false,
    SILENT_AIM           = false,
    AIMBOT_SPEED_LOCK    = false,
    AIMBOT_SPEED_LOCK_VAL= 0.0,

    -- [#31] Silent aim prediction — projectile lead
    -- Travel speeds in studs/sec per ability type.
    -- Hitscan = 0 (no lead). Adjust if Forsaken patches ability speeds.
    SILENT_PREDICT       = false,
    PREDICT_SPEEDS       = {
        -- ability tag pattern (lowercased Name match) → studs/sec
        ["azure"]        = 55,   -- Azure Tentacle
        ["tentacle"]     = 55,
        ["beam"]         = 0,    -- Beam: hitscan, no lead
        ["nova"]         = 40,   -- Nova radial
        ["sixer"]        = 35,   -- Sixer Scream cone
        ["corrupt"]      = 45,   -- Corrupt Nature
        ["nature"]       = 45,
        ["default"]      = 50,   -- fallback for unknown projectiles
    },

    -- [#44] Helperbot
    HELPERBOT_EXTEND     = false,
    HELPERBOT_RANGE      = 40.0,  -- extended detection radius
    HELPERBOT_ANTIMISS   = false, -- TP helperbot to nearest surv before fire
    -- FILL: confirm RemoteEvent name from your executor's remote spy.
    --       Observed candidates: "HelperBot_Target", "HelperBot_Use", "UseHelperBot"
    HELPERBOT_REMOTE     = "HelperBot_Use",
    _helperbotLast       = 0,
    HELPERBOT_COOLDOWN   = 3.0,

    -- ANTIS
    ANTI_AFK             = false,
    ANTI_RAGDOLL         = false,
    ANTI_STUN            = false,
    ANTI_GRAB            = false,
    ANTI_LAG             = false,

    -- SKILLS
    AUTO_SKILL           = false,
    SKILL_COOLDOWN       = 12.0,
    BUILDERMAN_AUTO_SENTRY = false,
    SENTRY_RANGE         = 30.0,
    _sentryLastDrop      = 0,
    SENTRY_COOLDOWN      = 20.0,
    BLOODHOOK_PREDICT    = false,
    BLOOD_PREDICT_STEPS  = 8,
    BLOOD_PREDICT_DIST   = 3.0,

    -- MISC
    TP_TO_GEN            = false,
    TP_TO_EXIT           = false,
    SERVER_HOP           = false,
    CHAT_SPAM            = false,
    CHAT_MSG             = "absolute olliE",
    CHAT_DELAY           = 8.0,
    AUTO_WIN             = false,
    GET_G666             = false,
    AUTO_EMOTE           = false,
    EMOTE_ID             = 5432167838,
    SAVE_CONFIG          = false,
    LOAD_CONFIG          = false,

    -- ITEMS
    ITEM_ESP             = false,
    ITEM_COLOR           = Color3.fromRGB(0, 200, 255),
    AUTO_PICKUP          = false,
    ITEM_PICKUP_RANGE    = 15.0,
    SHOW_ITEM_NAMES      = true,
    COLLECT_ALL          = false,
    -- [#21] Auto-pick Gears
    AUTO_PICK_GEARS      = false,
    GEAR_PICKUP_RANGE    = 12.0,
    -- [#26] Extended item ESP — water sprayer, gears, fruits
    ITEM_ESP_EXTENDED    = false,

    -- SHORTKEYS
    SHORTKEYS            = {},

    -- INTERNAL / PERF
    LOOP_THROTTLE        = 0.08,
    -- [#45] per-subsystem throttles (seconds between full scans)
    _descScanInterval    = 0.5,  -- GetDescendants scans share one timer
    _descScanLast        = 0,
    _descCache           = {},   -- cached descendants (BasePart + Model list)
    _bloodCacheTt        = 0,
    _bloodCache          = {},
    _itemCacheTt         = 0,
    _itemCache           = {},
    _npcCacheTt          = 0,
    _npcCache            = {},
}

-- ┌─────────────────────────────────────────────────────────┐
-- │                   HELPERS                                │
-- └─────────────────────────────────────────────────────────┘
local function getChar()  return LP.Character end
local function getHRP()
    local c = getChar(); return c and c:FindFirstChild("HumanoidRootPart")
end
local function getHum()
    local c = getChar(); return c and c:FindFirstChildOfClass("Humanoid")
end

local function isKillerChar(char)
    if not char then return false end
    if char:FindFirstChild("SlasherTag") then return true end
    local p = Players:GetPlayerFromCharacter(char)
    return p and p.Team and p.Team.Name == "Killers"
end

local function fireRemote(name, ...)
    local re = ReplicatedStorage:FindFirstChild(name, true)
    if re and re:IsA("RemoteEvent") then
        pcall(function() re:FireServer(...) end); return true
    end
    return false
end

local function nearestKillerChar()
    local hrp = getHRP(); if not hrp then return nil, math.huge end
    local best, bestD, bestChar = nil, math.huge, nil
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LP and p.Character and isKillerChar(p.Character) then
            local kr = p.Character:FindFirstChild("HumanoidRootPart")
            if kr then
                local d = (hrp.Position - kr.Position).Magnitude
                if d < bestD then best=kr; bestD=d; bestChar=p.Character end
            end
        end
    end
    return bestChar, bestD
end

local function nearestKillerDist()
    local _, d = nearestKillerChar(); return d
end

local function nearestSurvivorChar()
    local hrp = getHRP(); if not hrp then return nil, math.huge end
    local best, bestD = nil, math.huge
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LP and p.Character and not isKillerChar(p.Character) then
            local r = p.Character:FindFirstChild("HumanoidRootPart")
            if r then
                local d = (hrp.Position - r.Position).Magnitude
                if d < bestD then best=p.Character; bestD=d end
            end
        end
    end
    return best, bestD
end

-- ┌─────────────────────────────────────────────────────────┐
-- │  [#45] SHARED DESCENDANT CACHE                           │
-- │  All subsystems read this instead of calling             │
-- │  Workspace:GetDescendants() independently every tick.    │
-- └─────────────────────────────────────────────────────────┘
local function refreshDescCache()
    local now = tick()
    if now - CFG._descScanLast < CFG._descScanInterval then return end
    CFG._descScanLast = now
    local cache = {}
    for _, obj in ipairs(Workspace:GetDescendants()) do
        cache[#cache+1] = obj
    end
    CFG._descCache = cache
end

local function descCache()
    refreshDescCache()
    return CFG._descCache
end

-- ┌─────────────────────────────────────────────────────────┐
-- │                   ESP ENGINE                             │
-- └─────────────────────────────────────────────────────────┘
local espTable   = {}
local billboards = {}

local function clearESP(inst)
    if espTable[inst] then espTable[inst]:Destroy(); espTable[inst]=nil end
end
local function applyESP(inst, color, ft, ot)
    if not inst or not inst.Parent then return end
    ft = ft or 0.75; ot = ot or 0.0
    if espTable[inst] then
        espTable[inst].FillColor    = color
        espTable[inst].OutlineColor = color
        return
    end
    local h = Instance.new("Highlight")
    h.DepthMode         = Enum.HighlightDepthMode.AlwaysOnTop
    h.FillColor         = color
    h.OutlineColor      = color
    h.FillTransparency  = ft
    h.OutlineTransparency = ot
    h.Adornee = inst
    h.Parent  = inst
    espTable[inst] = h
end
local function removeAllESP()
    for inst, h in pairs(espTable) do h:Destroy(); espTable[inst]=nil end
end

local function applyBillboard(inst, text)
    if not inst or not inst.Parent then return end
    local bb = billboards[inst]
    if not bb then
        bb = Instance.new("BillboardGui")
        bb.Adornee = inst
        bb.Size    = UDim2.new(0,160,0,28)
        bb.StudsOffsetWorldSpace = Vector3.new(0,3,0)
        bb.AlwaysOnTop = true
        bb.Parent = inst
        local l = Instance.new("TextLabel")
        l.Name = "L"
        l.Size = UDim2.new(1,0,1,0)
        l.BackgroundTransparency = 1
        l.TextColor3 = Color3.fromRGB(255,255,255)
        l.TextSize   = 13
        l.Font       = Enum.Font.GothamBold
        l.TextStrokeTransparency = 0.4
        l.Parent = bb
        billboards[inst] = bb
    end
    bb.Adornee = inst
    local l = bb:FindFirstChild("L")
    if l then l.Text = text end
end
local function clearBillboard(inst)
    if billboards[inst] then billboards[inst]:Destroy(); billboards[inst]=nil end
end

-- ┌─────────────────────────────────────────────────────────┐
-- │                   STAMINA                                │
-- └─────────────────────────────────────────────────────────┘
local staminaConn = nil
local function applyStamina()
    if staminaConn then staminaConn:Disconnect(); staminaConn=nil end
    if not (CFG.INF_STAMINA or CFG.NO_SPRINT_PENALTY or CFG.STAMINA_REFILL_SPEED) then return end
    staminaConn = trackConn(RunService.Heartbeat:Connect(function()
        local c = getChar(); if not c then return end
        local stam = c:FindFirstChild("Stamina"); if not stam then return end
        if CFG.INF_STAMINA then stam.Value = stam.MaxValue or 100; return end
        if CFG.NO_SPRINT_PENALTY then
            local ex = c:FindFirstChild("Exhausted"); if ex then ex.Value=false end
        end
        if CFG.STAMINA_REFILL_SPEED then
            local h = getHum()
            if h and h.MoveDirection.Magnitude < 0.1 then
                stam.Value = math.min(stam.MaxValue or 100, stam.Value+2)
            end
        end
    end))
end

-- ┌─────────────────────────────────────────────────────────┐
-- │  [#20/#48] REMOVE LOBBY NPCs                             │
-- └─────────────────────────────────────────────────────────┘
-- NPC models in Forsaken's lobby are tagged "NPC", "LobbyNPC", or have
-- a Humanoid but no player. We remove their visual descendants only —
-- leaving the model so server scripts don't error — unless it's purely
-- cosmetic (no RemoteEvent children), in which case we Destroy().
local _npcRemoved = false

local function removeLobbyNPCs()
    if _npcRemoved then return end
    for _, obj in ipairs(Workspace:GetDescendants()) do
        if obj:IsA("Model") then
            local hasHum    = obj:FindFirstChildOfClass("Humanoid") ~= nil
            local hasPlayer = Players:GetPlayerFromCharacter(obj) ~= nil
            local isNPC     = not hasPlayer and hasHum
            local tagMatch  = obj.Name:lower():find("npc") or obj.Name:lower():find("dummy")
            if isNPC or tagMatch then
                -- Remove visual parts to save GPU; keep model anchor
                for _, part in ipairs(obj:GetDescendants()) do
                    if part:IsA("BasePart") or part:IsA("Decal") or part:IsA("SpecialMesh") then
                        part.Transparency = 1
                        if part:IsA("BasePart") then
                            part.CanCollide = false
                            part.CastShadow = false
                        end
                    end
                    -- [#47] Remove ragdoll constraints too while we're here
                    if CFG.REMOVE_RAGDOLLS then
                        if part:IsA("BallSocketConstraint") or part:IsA("HingeConstraint") then
                            part:Destroy()
                        end
                    end
                end
            end
        end
    end
    _npcRemoved = true
end

local function restoreLobbyNPCs()
    -- Can't truly restore destroyed constraints, but re-show parts
    for _, obj in ipairs(Workspace:GetDescendants()) do
        if obj:IsA("Model") then
            local hasHum    = obj:FindFirstChildOfClass("Humanoid") ~= nil
            local hasPlayer = Players:GetPlayerFromCharacter(obj) ~= nil
            if not hasPlayer and hasHum then
                for _, part in ipairs(obj:GetDescendants()) do
                    if part:IsA("BasePart") then
                        part.Transparency = 0
                        part.CanCollide   = true
                        part.CastShadow   = true
                    end
                end
            end
        end
    end
    _npcRemoved = false
end

-- ┌─────────────────────────────────────────────────────────┐
-- │  [#47] REMOVE RAGDOLLS                                   │
-- └─────────────────────────────────────────────────────────┘
-- Ragdoll joints fire whenever a character dies or gets knocked.
-- Destroy them on CharacterAdded so the physics solver skips them.
local function stripRagdollJoints(char)
    if not char then return end
    for _, c in ipairs(char:GetDescendants()) do
        if c:IsA("BallSocketConstraint") or c:IsA("HingeConstraint") then
            pcall(function() c:Destroy() end)
        end
    end
end

local function applyRagdollRemoval()
    if CFG.REMOVE_RAGDOLLS then
        -- Strip local player
        if getChar() then stripRagdollJoints(getChar()) end
        -- Strip all current characters
        for _, p in ipairs(Players:GetPlayers()) do
            if p.Character then stripRagdollJoints(p.Character) end
        end
    end
end

-- ┌─────────────────────────────────────────────────────────┐
-- │                   VISUAL                                 │
-- └─────────────────────────────────────────────────────────┘
local origAmbient, origBright, origFogEnd, origFogStart
local crosshairGui = nil

local function applyVisual()
    if not LOADED then return end
    local L = game:GetService("Lighting")
    if CFG.FULL_BRIGHT then
        origAmbient = origAmbient or L.Ambient
        origBright  = origBright  or L.Brightness
        L.Ambient         = Color3.fromRGB(178,178,178)
        L.OutdoorAmbient  = Color3.fromRGB(178,178,178)
        L.Brightness      = 2
    elseif origAmbient then
        L.Ambient         = origAmbient
        L.OutdoorAmbient  = origAmbient
        L.Brightness      = origBright or 1
        origAmbient       = nil
    end
    if CFG.NO_FOG then
        origFogEnd   = origFogEnd   or L.FogEnd
        origFogStart = origFogStart or L.FogStart
        L.FogEnd   = 100000
        L.FogStart = 99999
    elseif origFogEnd then
        L.FogEnd   = origFogEnd
        L.FogStart = origFogStart
        origFogEnd = nil
    end
    Camera.FieldOfView = CFG.CUSTOM_FOV and CFG.FOV_VALUE or 70

    if CFG.REMOVE_BLUR or CFG.REMOVE_ACID or CFG.REMOVE_BLINDNESS then
        for _, pe in ipairs(Camera:GetChildren()) do
            if pe:IsA("BlurEffect") and CFG.REMOVE_BLUR then pe:Destroy() end
            if pe:IsA("ColorCorrectionEffect") and CFG.REMOVE_ACID then pe:Destroy() end
        end
        if CFG.REMOVE_BLINDNESS then
            for _, gui in ipairs(LP.PlayerGui:GetChildren()) do
                if gui.Name:lower():find("dark") or gui.Name:lower():find("blind") then
                    gui.Enabled = false
                end
            end
        end
    end

    if CFG.REMOVE_SLOWNESS then
        local c = getChar(); if c then
            local slow = c:FindFirstChild("Slowed") or c:FindFirstChild("Slowness")
            if slow then slow.Value = false end
        end
    end

    local char = getChar()
    if char then
        if CFG.CHAMS_SELF then
            applyESP(char, Color3.fromRGB(255,150,0), 0.5, 0.0)
        else
            clearESP(char)
        end
        if CFG.INVISIBLE_MODE then
            for _, p in ipairs(char:GetDescendants()) do
                if p:IsA("BasePart") or p:IsA("Decal") then p.Transparency = 1 end
            end
        end
    end

    if CFG.CROSSHAIR and not crosshairGui then
        crosshairGui = Instance.new("ScreenGui")
        crosshairGui.Name            = "Crosshair"
        crosshairGui.ResetOnSpawn    = false
        crosshairGui.IgnoreGuiInset  = true
        crosshairGui.Parent          = LP.PlayerGui
        local function mkLine(w,h,x,y)
            local f = Instance.new("Frame")
            f.Size                = UDim2.new(0,w,0,h)
            f.Position            = UDim2.new(0.5,x,0.5,y)
            f.BackgroundColor3    = Color3.fromRGB(255,50,50)
            f.BorderSizePixel     = 0
            f.Parent              = crosshairGui
        end
        mkLine(2,14,-1,-7); mkLine(14,2,-7,-1)
    elseif not CFG.CROSSHAIR and crosshairGui then
        crosshairGui:Destroy(); crosshairGui = nil
    end

    -- [#20/#48] NPC removal
    if CFG.REMOVE_LOBBY_NPCS then
        removeLobbyNPCs()
    elseif _npcRemoved then
        restoreLobbyNPCs()
    end
end

-- ┌─────────────────────────────────────────────────────────┐
-- │                   GENERATORS                             │
-- └─────────────────────────────────────────────────────────┘
-- [#45] Gen list cached — refreshDescCache drives the window
local function getGens()
    local out = {}
    for _, o in ipairs(descCache()) do
        if o.Name == "Generator" and o:IsA("Model") then
            table.insert(out, o)
        end
    end
    return out
end

local function nearestIncompleteGen()
    local hrp = getHRP(); if not hrp then return nil, math.huge end
    local best, bestD = nil, math.huge
    for _, g in ipairs(getGens()) do
        local done = g:FindFirstChild("Complete")
        if not done or not done.Value then
            local root = g:FindFirstChild("PrimaryPart") or g:FindFirstChildOfClass("BasePart")
            if root then
                local d = (hrp.Position - root.Position).Magnitude
                if d < bestD then best=g; bestD=d end
            end
        end
    end
    return best, bestD
end

local function tickGens()
    for _, g in ipairs(getGens()) do
        local done   = g:FindFirstChild("Complete")
        local isDone = done and done.Value

        -- [#24] Auto-off: if the gen is complete, kill its ESP
        if CFG.GEN_ESP_AUTO_OFF and isDone then
            clearESP(g)
            clearBillboard(g)
        elseif CFG.GEN_ESP and not isDone then
            applyESP(g, CFG.GEN_ESP_COLOR)
            if CFG.GEN_PROGRESS_ESP then
                local prog = g:FindFirstChild("Progress")
                applyBillboard(g, prog and string.format("Gen %.0f%%", prog.Value) or "Gen")
            end
        elseif not CFG.GEN_ESP then
            clearESP(g)
        end
    end

    if CFG.INSTA_GEN then
        for _, g in ipairs(getGens()) do
            local done = g:FindFirstChild("Complete")
            if not done or not done.Value then
                local re = g:FindFirstChildOfClass("RemoteEvent")
                    or ReplicatedStorage:FindFirstChild("GeneratorComplete", true)
                if re and re:IsA("RemoteEvent") then
                    pcall(function() re:FireServer(g) end)
                end
            end
        end
        CFG.INSTA_GEN = false
    end

    if CFG.AUTO_GEN then
        local gen, dist = nearestIncompleteGen()
        if gen and dist <= CFG.GEN_RANGE then
            local prompt = gen:FindFirstChildOfClass("ProximityPrompt")
            if prompt then
                pcall(fireproximityprompt, prompt)
            else
                local cd = gen:FindFirstChildOfClass("ClickDetector")
                if cd then pcall(fireclickdetector, cd) end
            end
        end
    end
end

-- ┌─────────────────────────────────────────────────────────┐
-- │                   BLOCK + SHIELD + [#23] TP DODGE        │
-- └─────────────────────────────────────────────────────────┘
local function fireBlock()
    local re = ReplicatedStorage:FindFirstChild("Block", true)
        or ReplicatedStorage:FindFirstChild("BlockEvent", true)
    if re and re:IsA("RemoteEvent") then pcall(function() re:FireServer() end) end
end

local function killerHasShield()
    local kc, _ = nearestKillerChar(); if not kc then return false end
    local sv = kc:FindFirstChild("Shield")
        or kc:FindFirstChild("Shielded")
        or kc:FindFirstChild("Blocking")
    return sv and (sv.Value == true or sv:IsA("BoolValue") and sv.Value)
end

-- [#23] M1 detection heuristic:
-- Forsaken killers fire a RemoteEvent or animate a "Swing"/"Attack" action.
-- Client-side we detect the hit window by checking if the killer's character
-- played an attack animation recently OR if a "Hit" remote fired near us.
-- Since we can't hook server remotes directly, we watch for a HitEffect Part
-- or the killer entering VERY close range — that's the M1 window.
local _m1WatchConn = nil
local _m1Firing    = false

local function setupM1Watch()
    if _m1WatchConn then _m1WatchConn:Disconnect(); _m1WatchConn=nil end
    if not CFG.AUTO_BLOCK_TP then return end
    -- Watch for new BasePart named "HitEffect" / "SlashEffect" spawned near us
    _m1WatchConn = trackConn(Workspace.DescendantAdded:Connect(function(obj)
        if not CFG.AUTO_BLOCK_TP then return end
        if not obj:IsA("BasePart") then return end
        local n = obj.Name:lower()
        if n:find("hit") or n:find("slash") or n:find("swing") or n:find("attack") then
            local hrp = getHRP(); if not hrp then return end
            if (hrp.Position - obj.Position).Magnitude <= CFG.BLOCK_TP_RANGE then
                _m1Firing = true
            end
        end
    end))
end

local function tickBlock()
    if CFG.SHIELD_DETECT then
        local hasShield = killerHasShield()
        if hasShield and not CFG._killerShieldActive then
            CFG._killerShieldActive = true
            CFG._killerShieldExpiry = tick() + CFG.SHIELD_TIMER_SECS
        end
        if CFG._killerShieldActive and tick() > CFG._killerShieldExpiry then
            CFG._killerShieldActive = false
        end
    end

    if CFG.SHIELD_SUPPRESS_STUN and CFG._killerShieldActive then return end

    -- [#23] TP dodge on M1 hit window
    if CFG.AUTO_BLOCK_TP and _m1Firing then
        _m1Firing = false
        local now = tick()
        if now - CFG._blockTpCooldown >= CFG.BLOCK_TP_COOLDOWN then
            CFG._blockTpCooldown = now
            local hrp = getHRP()
            if hrp then
                -- Strafe perpendicular to killer direction
                local kc, _ = nearestKillerChar()
                local sideDir
                if kc then
                    local kr = kc:FindFirstChild("HumanoidRootPart")
                    if kr then
                        local toKiller = (kr.Position - hrp.Position)
                        sideDir = Vector3.new(-toKiller.Z, 0, toKiller.X).Unit
                    end
                end
                sideDir = sideDir or hrp.CFrame.RightVector
                hrp.CFrame = hrp.CFrame + sideDir * CFG.BLOCK_TP_DIST
            end
        end
    end

    if not (CFG.AUTO_BLOCK or CFG.BLOCK_HOLD) then return end
    local kd = nearestKillerDist()
    if CFG.BLOCK_HOLD or (CFG.AUTO_BLOCK and kd <= CFG.BLOCK_RANGE) then
        fireBlock()
    end
end

-- ┌─────────────────────────────────────────────────────────┐
-- │                   SURVIVORS                              │
-- └─────────────────────────────────────────────────────────┘
local function isInChase()
    local c = getChar(); if not c then return false end
    local ch = c:FindFirstChild("Chased") or c:FindFirstChild("Chase")
    if ch and ch.Value then return true end
    return nearestKillerDist() < 25
end

local function getHookedSurvivor()
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LP and p.Character then
            local h = p.Character:FindFirstChild("Hooked")
            if h and h.Value then return p.Character end
        end
    end
    return nil
end

-- [#45] Blood trail cache
local function getBloodTrailCached()
    local now = tick()
    if now - CFG._bloodCacheTt < 0.5 then return CFG._bloodCache end
    CFG._bloodCacheTt = now
    local cache = {}
    for _, obj in ipairs(descCache()) do
        if obj:IsA("BasePart") and obj.Name:lower():find("blood") then
            table.insert(cache, obj.Position)
        end
    end
    CFG._bloodCache = cache
    return cache
end

local function bloodhookPredict()
    local hrp = getHRP(); if not hrp then return nil end
    local trail = getBloodTrailCached()
    if #trail < 2 then return nil end
    table.sort(trail, function(a, b)
        return (hrp.Position - a).Magnitude < (hrp.Position - b).Magnitude
    end)
    local dir = (trail[2] - trail[1]).Unit
    return trail[1] + dir * (CFG.BLOOD_PREDICT_STEPS * CFG.BLOOD_PREDICT_DIST)
end

local function tickBloodStack()
    if not CFG.BLOOD_STACK_MULT then return end
    local c = getChar(); if not c then return end
    local bs = c:FindFirstChild("BloodStack")
        or c:FindFirstChild("BloodStacks")
        or c:FindFirstChild("Blood")
    if bs and bs:IsA("NumberValue") then
        local target = math.floor(bs.Value * CFG.BLOOD_MULT_VALUE)
        if target > bs.Value then bs.Value = target end
    end
end

local function tickSurvivors()
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LP and p.Character and not isKillerChar(p.Character) then
            if CFG.SURVIVOR_ESP then
                applyESP(p.Character, CFG.SURV_COLOR)
                if CFG.SURV_SHOW_NAME then
                    local hum = p.Character:FindFirstChildOfClass("Humanoid")
                    local hp  = hum and CFG.SURV_SHOW_HEALTH
                        and string.format(" [%d]", math.floor(hum.Health)) or ""
                    applyBillboard(p.Character, p.Name..hp)
                end
            else
                clearESP(p.Character)
            end
        end
    end

    local hum = getHum()
    if hum then
        local inChase   = isInChase()
        CFG._inChase    = inChase
        local baseSpeed = CFG.SPEED_HACK and CFG.SPEED_VALUE or CFG.SPEED_DEFAULT
        if CFG.CHASE_SPEED_BOOST and not inChase then
            hum.WalkSpeed = baseSpeed * CFG.CHASE_SPEED_MULT
        else
            hum.WalkSpeed = baseSpeed
        end

        if CFG.JOHNDOE_TRAP_SPEED then
            for _, obj in ipairs(descCache()) do
                if obj.Name:lower():find("johndoe") or obj.Name:lower():find("trap") then
                    local bp = obj:IsA("BasePart") and obj or obj:FindFirstChildOfClass("BasePart")
                    if bp then
                        local hrp = getHRP()
                        if hrp and (hrp.Position - bp.Position).Magnitude <= CFG.JOHNDOE_TRAP_RANGE then
                            hum.WalkSpeed = CFG.JOHNDOE_TRAP_VAL
                            break
                        end
                    end
                end
            end
        end

        hum.JumpPower = CFG.JUMP_POWER and CFG.JUMP_VALUE or 50
    end

    if CFG.AUTO_HEAL and hum and hum.Health < CFG.HEAL_THRESHOLD then
        local c = getChar(); if c then
            for _, tool in ipairs(c:GetChildren()) do
                if tool:IsA("Tool") and tool.Name:lower():find("medkit") then
                    pcall(function() tool:Activate() end)
                end
            end
        end
    end

    if CFG.TP_TO_HOOKED then
        CFG.TP_TO_HOOKED = false
        local hc   = getHookedSurvivor()
        if hc then
            local hrp  = getHRP()
            local root = hc:FindFirstChild("HumanoidRootPart")
            if hrp and root then hrp.CFrame = root.CFrame + Vector3.new(3,0,0) end
        end
    end

    if CFG.TPLAG_ENABLED then
        local now = tick()
        if now - CFG._tplagLast >= CFG.TPLAG_INTERVAL then
            CFG._tplagLast = now
            local hrp = getHRP()
            if hrp and hrp.AssemblyLinearVelocity.Magnitude > 1 then
                local back = -hrp.CFrame.LookVector * (CFG.TPLAG_DIST * 8)
                hrp.AssemblyLinearVelocity = back
                task.delay(0.05, function()
                    if hrp and hrp.Parent then
                        hrp.AssemblyLinearVelocity = Vector3.zero
                    end
                end)
            end
        end
    end

    if CFG.BLOODHOOK_PREDICT then
        local pos = bloodhookPredict()
        if pos then
            local marker = Workspace:FindFirstChild("BloodhookMarker")
            if not marker then
                marker = Instance.new("Part")
                marker.Name        = "BloodhookMarker"
                marker.Size        = Vector3.new(1,1,1)
                marker.Anchored    = true
                marker.CanCollide  = false
                marker.Transparency= 1
                marker.Parent      = Workspace
                local bb = Instance.new("BillboardGui")
                bb.Adornee     = marker
                bb.Size        = UDim2.new(0,120,0,30)
                bb.AlwaysOnTop = true
                bb.Parent      = marker
                local l = Instance.new("TextLabel")
                l.Size                  = UDim2.new(1,0,1,0)
                l.BackgroundTransparency= 1
                l.Text                  = "Hook Predict"
                l.TextColor3            = Color3.fromRGB(255,80,80)
                l.TextSize              = 13
                l.Font                  = Enum.Font.GothamBold
                l.Parent                = bb
            end
            marker.CFrame = CFrame.new(pos)
        end
    else
        local marker = Workspace:FindFirstChild("BloodhookMarker")
        if marker then marker:Destroy() end
    end

    tickBloodStack()
end

-- ┌─────────────────────────────────────────────────────────┐
-- │  [#46] KILLER STUN ESP COLOR                             │
-- │  Forsaken killers get a "Stunned" BoolValue or a         │
-- │  floating stun orb model named "StunEffect"/"StunOrb".  │
-- │  We watch for these and swap ESP color while active.     │
-- └─────────────────────────────────────────────────────────┘
local function isKillerStunned(char)
    if not char then return false end
    -- BoolValue check
    local sv = char:FindFirstChild("Stunned") or char:FindFirstChild("IsStunned")
    if sv and sv.Value then return true end
    -- Floating stun orb check (Forsaken spawns a Model/Part near the killer HRP)
    local root = char:FindFirstChild("HumanoidRootPart")
    if root then
        for _, obj in ipairs(descCache()) do
            if (obj.Name:lower():find("stun") or obj.Name:lower():find("orb"))
                and obj:IsA("BasePart") then
                if (obj.Position - root.Position).Magnitude < 8 then
                    return true
                end
            end
        end
    end
    return false
end

-- ┌─────────────────────────────────────────────────────────┐
-- │                   KILLERS                                │
-- └─────────────────────────────────────────────────────────┘
local killerAlertGui = nil
local alertActive    = false

local function setKillerAlert(state)
    if state == alertActive then return end
    alertActive = state
    if killerAlertGui then killerAlertGui.Enabled = state end
end

local function canGash()
    local c = getChar(); if not c then return false end
    local bs = c:FindFirstChild("BloodStack") or c:FindFirstChild("BloodStacks")
    return bs and bs.Value >= CFG.GASH_BLEED_THRESH
end

-- [#28] Veronica bumper helpers — store and restore original HRP sizes
local function applyVeronicaBumper(char)
    local root = char and char:FindFirstChild("HumanoidRootPart")
    if not root then return end
    if not CFG._veronicaOrigSizes[root] then
        CFG._veronicaOrigSizes[root] = root.Size
    end
    root.Size = Vector3.new(CFG.VERONICA_BUMPER_SIZE, CFG.VERONICA_BUMPER_SIZE, CFG.VERONICA_BUMPER_SIZE)
end

local function restoreVeronicaBumper(char)
    local root = char and char:FindFirstChild("HumanoidRootPart")
    if not root then return end
    local orig = CFG._veronicaOrigSizes[root]
    if orig then
        root.Size = orig
        CFG._veronicaOrigSizes[root] = nil
    end
end

local function tickKillers()
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LP and p.Character and isKillerChar(p.Character) then
            if CFG.KILLER_ESP then
                -- [#46] Swap color when stunned
                local col = isKillerStunned(p.Character)
                    and CFG.KILLER_STUN_COLOR
                    or  CFG.KILLER_COLOR
                applyESP(p.Character, col)
                if CFG.SHOW_KILLER_NAME then
                    local stag = isKillerStunned(p.Character) and " [STUNNED]" or ""
                    applyBillboard(p.Character, "KILLER " .. p.Name .. stag)
                end
            else
                clearESP(p.Character)
            end

            -- [#28] Veronica bumper — apply or restore per killer
            if CFG.VERONICA_BUMPER then
                applyVeronicaBumper(p.Character)
            else
                restoreVeronicaBumper(p.Character)
            end
        end
    end

    setKillerAlert(CFG.KILLER_DIST_ALERT and nearestKillerDist() <= CFG.KILLER_ALERT_RANGE)

    local target, dist = nearestSurvivorChar()

    if (CFG.KILL_AURA or (CFG.AUTO_SLASH and dist and dist <= CFG.SLASH_RANGE)) and target then
        fireRemote("SlashHit") or fireRemote("AttackHit") or fireRemote("Hit")
    end

    -- [#2/v4] Double-backstab aimbot — rotation only, no TP
    if CFG.DOUBLE_BACKSTAB and target then
        local hrp   = getHRP()
        local tRoot = target:FindFirstChild("HumanoidRootPart")
        if hrp and tRoot then
            if CFG._backstabState == 0 then
                local behindTarget = tRoot.CFrame * CFrame.new(0,0,2)
                local goalCam = CFrame.lookAt(Camera.CFrame.Position, behindTarget.Position)
                Camera.CFrame = Camera.CFrame:Lerp(goalCam, 1-CFG.BACKSTAB_SMOOTH)
                local toUs = (hrp.Position - tRoot.Position).Unit
                local fwd  = tRoot.CFrame.LookVector
                if fwd:Dot(toUs) > math.cos(math.rad(CFG.BACKSTAB_FOV)) then
                    fireRemote("Backstab") or fireRemote("BackstabHit")
                    CFG._backstabState  = 1
                    CFG._backstabTarget = tRoot
                end
            elseif CFG._backstabState == 1 then
                -- Camera pivot only — no hrp warp
                local sidePos = tRoot.Position + tRoot.CFrame.RightVector * 3
                local goalCam = CFrame.lookAt(Camera.CFrame.Position, sidePos)
                Camera.CFrame = Camera.CFrame:Lerp(goalCam, 0.35)
                local dot = (Camera.CFrame.LookVector):Dot((sidePos - Camera.CFrame.Position).Unit)
                if dot > 0.92 then CFG._backstabState = 2 end
            elseif CFG._backstabState == 2 then
                if hrp and tRoot then
                    local toUs = (hrp.Position - tRoot.Position).Unit
                    local fwd  = tRoot.CFrame.LookVector
                    if fwd:Dot(toUs) > math.cos(math.rad(CFG.BACKSTAB_FOV)) then
                        fireRemote("Backstab") or fireRemote("BackstabHit")
                        CFG._backstabState  = 0
                        CFG._backstabTarget = nil
                    else
                        local goalCam = CFrame.lookAt(Camera.CFrame.Position, tRoot.Position)
                        Camera.CFrame = Camera.CFrame:Lerp(goalCam, 1-CFG.BACKSTAB_SMOOTH)
                    end
                end
            end
        end
    elseif not CFG.DOUBLE_BACKSTAB then
        CFG._backstabState  = 0
        CFG._backstabTarget = nil
    end

    if CFG.AUTO_BACKSTAB and target then
        local hrp   = getHRP()
        local tRoot = target:FindFirstChild("HumanoidRootPart")
        if hrp and tRoot then
            local toUs = (hrp.Position - tRoot.Position).Unit
            local fwd  = tRoot.CFrame.LookVector
            if fwd:Dot(toUs) > 0.5 then
                fireRemote("Backstab") or fireRemote("BackstabHit")
            end
        end
    end

    if CFG.AUTO_GASH and canGash() then
        fireRemote("Gash") or fireRemote("UseGash") or fireRemote("GashAttack")
    end

    if CFG.NO_KILLER_SKATE then
        local kc, _ = nearestKillerChar()
        if kc then
            local kr = kc:FindFirstChild("HumanoidRootPart")
            if kr then kr.Velocity = Vector3.new(0, kr.Velocity.Y, 0) end
        end
    end

    if CFG.PUSH_OVERRIDE then
        local tgt, tdist = nearestSurvivorChar()
        if tgt and tdist and tdist <= 10 then
            local re = ReplicatedStorage:FindFirstChild("PushPlayer", true)
            if re and re:IsA("RemoteEvent") then
                pcall(function() re:FireServer(Players:GetPlayerFromCharacter(tgt), CFG.PUSH_AMOUNT) end)
            end
        end
    end
end

local function buildKillerAlert()
    if killerAlertGui then killerAlertGui:Destroy() end
    killerAlertGui = Instance.new("ScreenGui")
    killerAlertGui.Name          = "KillerAlert"
    killerAlertGui.ResetOnSpawn  = false
    killerAlertGui.IgnoreGuiInset= true
    killerAlertGui.Enabled       = false
    killerAlertGui.Parent        = LP.PlayerGui

    local border = Instance.new("Frame")
    border.Size                = UDim2.new(1,0,1,0)
    border.BackgroundColor3    = Color3.fromRGB(255,0,0)
    border.BackgroundTransparency = 0.65
    border.BorderSizePixel     = 0
    border.Parent              = killerAlertGui

    local lbl = Instance.new("TextLabel")
    lbl.Size                  = UDim2.new(1,0,0,50)
    lbl.Position              = UDim2.new(0,0,0.45,0)
    lbl.BackgroundTransparency= 1
    lbl.Text                  = "KILLER NEARBY"
    lbl.TextColor3            = Color3.fromRGB(255,255,255)
    lbl.TextSize              = 22
    lbl.Font                  = Enum.Font.GothamBold
    lbl.TextStrokeTransparency= 0.3
    lbl.Parent                = killerAlertGui

    local shieldLbl = Instance.new("TextLabel")
    shieldLbl.Name               = "ShieldLbl"
    shieldLbl.Size               = UDim2.new(1,0,0,28)
    shieldLbl.Position           = UDim2.new(0,0,0.58,0)
    shieldLbl.BackgroundTransparency = 1
    shieldLbl.Text               = ""
    shieldLbl.TextColor3         = Color3.fromRGB(120,200,255)
    shieldLbl.TextSize           = 16
    shieldLbl.Font               = Enum.Font.GothamBold
    shieldLbl.Parent             = killerAlertGui
end
buildKillerAlert()

local function updateShieldLabel()
    if not killerAlertGui then return end
    local lbl = killerAlertGui:FindFirstChild("ShieldLbl"); if not lbl then return end
    if CFG.SHIELD_DETECT and CFG._killerShieldActive then
        local remaining = math.max(0, CFG._killerShieldExpiry - tick())
        lbl.Text = string.format("SHIELD %.1fs", remaining)
    else
        lbl.Text = ""
    end
end

-- ┌─────────────────────────────────────────────────────────┐
-- │  [#31] SILENT AIM WITH PROJECTILE PREDICTION             │
-- └─────────────────────────────────────────────────────────┘
-- For hitscan abilities (beam) speed=0 → no lead, aim direct.
-- For projectile abilities we read the active killer's equipped
-- tool name to pick the right speed bucket.

local function getActiveKillerAbilitySpeed()
    local kc, _ = nearestKillerChar()
    if not kc then return CFG.PREDICT_SPEEDS["default"] end
    -- Check what tool/ability the killer has equipped
    for _, t in ipairs(kc:GetChildren()) do
        if t:IsA("Tool") then
            local n = t.Name:lower()
            for pattern, speed in pairs(CFG.PREDICT_SPEEDS) do
                if n:find(pattern) then return speed end
            end
        end
    end
    -- Also check a "CurrentAbility" StringValue some games use
    local ca = kc:FindFirstChild("CurrentAbility") or kc:FindFirstChild("ActiveSkill")
    if ca and ca:IsA("StringValue") then
        local n = ca.Value:lower()
        for pattern, speed in pairs(CFG.PREDICT_SPEEDS) do
            if n:find(pattern) then return speed end
        end
    end
    return CFG.PREDICT_SPEEDS["default"]
end

local function predictedTargetPosition(target)
    -- target: BasePart (head or HRP)
    local hrp = getHRP(); if not hrp or not target then return target and target.Position end

    local speed = getActiveKillerAbilitySpeed()
    if speed == 0 then return target.Position end  -- hitscan

    -- Time-of-flight estimate: dist / projectile_speed
    local dist = (target.Position - hrp.Position).Magnitude
    local tof  = dist / speed

    -- Linear extrapolation using AssemblyLinearVelocity
    local vel = target:IsA("BasePart") and target.AssemblyLinearVelocity or Vector3.zero
    return target.Position + vel * tof
end

-- ┌─────────────────────────────────────────────────────────┐
-- │                   AIMBOT                                 │
-- └─────────────────────────────────────────────────────────┘
local function getAimbotTarget()
    local camCF  = Camera.CFrame
    local bestPart, bestFOV = nil, CFG.AIMBOT_FOV
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LP and p.Character then
            if not CFG.AIMBOT_KILLER_ONLY or isKillerChar(p.Character) then
                local root = p.Character:FindFirstChild(CFG.AIMBOT_TARGET)
                    or p.Character:FindFirstChild("HumanoidRootPart")
                if root then
                    local dir = (root.Position - camCF.Position).Unit
                    local deg = math.deg(math.acos(math.clamp(camCF.LookVector:Dot(dir),-1,1)))
                    if deg < bestFOV then bestFOV=deg; bestPart=root end
                end
            end
        end
    end
    return bestPart
end

local function tickAimbot()
    -- [#45] Hitbox extender only loops players, not full descendants — fast
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LP and p.Character then
            local r = p.Character:FindFirstChild("HumanoidRootPart")
            if r then
                r.Size = CFG.HITBOX_EXTENDER
                    and Vector3.new(CFG.HITBOX_SIZE, CFG.HITBOX_SIZE, CFG.HITBOX_SIZE)
                    or Vector3.new(2,2,1)
            end
        end
    end

    local hum = getHum()
    if CFG.AIMBOT_SPEED_LOCK and (CFG.AIMBOT or CFG.SILENT_AIM) and hum then
        hum.WalkSpeed = CFG.AIMBOT_SPEED_LOCK_VAL
    end

    if not (CFG.AIMBOT or CFG.SILENT_AIM) then return end
    local target = getAimbotTarget(); if not target then return end

    -- [#31] Use predicted position for silent aim
    local aimPos = (CFG.SILENT_AIM and CFG.SILENT_PREDICT)
        and predictedTargetPosition(target)
        or  target.Position

    local goal = CFrame.lookAt(Camera.CFrame.Position, aimPos)
    if CFG.AIMBOT then
        Camera.CFrame = Camera.CFrame:Lerp(goal, 1-CFG.AIMBOT_SMOOTHING)
    else
        Camera.CFrame = goal
    end
end

-- ┌─────────────────────────────────────────────────────────┐
-- │             ANTIS + NOCLIP                               │
-- └─────────────────────────────────────────────────────────┘
local noclipConn = nil
local lastAfkMove = tick()

local function applyNoclip()
    if noclipConn then noclipConn:Disconnect(); noclipConn=nil end
    if CFG.NOCLIP then
        noclipConn = trackConn(RunService.Stepped:Connect(function()
            local c = getChar(); if not c then return end
            for _, p in ipairs(c:GetDescendants()) do
                if p:IsA("BasePart") then p.CanCollide=false end
            end
        end))
    else
        if CFG.NOCLIP_SAFE then
            task.delay(0.05, function()
                local c = getChar(); if not c then return end
                for _, p in ipairs(c:GetDescendants()) do
                    if p:IsA("BasePart") then p.CanCollide=true end
                end
            end)
        end
    end
end

local function tickAntis()
    if CFG.ANTI_AFK and tick()-lastAfkMove > 60 then
        lastAfkMove = tick()
        Camera.CFrame = Camera.CFrame * CFrame.Angles(0,0.001,0)
    end
    if CFG.ANTI_RAGDOLL then
        local hum = getHum()
        if hum and hum:GetState() == Enum.HumanoidStateType.Ragdoll then
            hum:ChangeState(Enum.HumanoidStateType.GettingUp)
        end
    end
    -- [#47] Strip ragdoll joints from any newly loaded character parts
    if CFG.REMOVE_RAGDOLLS then
        local c = getChar(); if c then stripRagdollJoints(c) end
    end
    if CFG.ANTI_STUN then
        local c = getChar(); if c then
            local s = c:FindFirstChild("Stunned"); if s then s.Value=false end
        end
    end
    if CFG.ANTI_GRAB then
        local c = getChar(); if c then
            local g = c:FindFirstChild("Grabbed"); if g then g.Value=false end
            for _, v in ipairs(c:GetDescendants()) do
                if v:IsA("WeldConstraint") and v.Name == "GrabWeld" then v:Destroy() end
            end
        end
    end
    if CFG.ANTI_LAG then
        local ok, fps = pcall(function() return 1/RunService.RenderStepped:Wait() end)
        if ok then
            settings().Rendering.QualityLevel = fps < 30 and 1 or Enum.QualityLevel.Automatic
        end
    end
end

-- ┌─────────────────────────────────────────────────────────┐
-- │  [#44] HELPERBOT                                         │
-- └─────────────────────────────────────────────────────────┘
local function tickHelperbot()
    if not (CFG.HELPERBOT_EXTEND or CFG.HELPERBOT_ANTIMISS) then return end
    local now = tick()
    if now - CFG._helperbotLast < CFG.HELPERBOT_COOLDOWN then return end

    local bestChar, bestDist = nearestSurvivorChar()
    if not bestChar then return end

    -- [#44] Anti-miss: teleport helperbot anchor to the survivor before firing
    if CFG.HELPERBOT_ANTIMISS then
        local survRoot = bestChar:FindFirstChild("HumanoidRootPart")
        -- Find any helperbot model/part in the workspace
        for _, obj in ipairs(descCache()) do
            if (obj.Name:lower():find("helper") or obj.Name:lower():find("helperbot"))
                and obj:IsA("BasePart") and obj.Anchored then
                if survRoot then
                    obj.CFrame = CFrame.new(survRoot.Position + Vector3.new(0,3,0))
                end
                break
            end
        end
    end

    -- Extended range: fire remote with target if within HELPERBOT_RANGE
    if bestDist and bestDist <= CFG.HELPERBOT_RANGE then
        CFG._helperbotLast = now
        local survPlayer = Players:GetPlayerFromCharacter(bestChar)
        -- Try remotes with target argument, then without
        if not fireRemote(CFG.HELPERBOT_REMOTE, survPlayer) then
            fireRemote(CFG.HELPERBOT_REMOTE)
        end
        -- Also activate helperbot Tool in character if equipped
        local c = getChar(); if c then
            for _, t in ipairs(c:GetChildren()) do
                if t:IsA("Tool") and (t.Name:lower():find("helper") or t.Name:lower():find("bot")) then
                    pcall(function() t:Activate() end)
                end
            end
        end
    end
end

-- ┌─────────────────────────────────────────────────────────┐
-- │                   SKILLS + BUILDERMAN                    │
-- └─────────────────────────────────────────────────────────┘
local lastSkillFire = 0

local function tickSkills()
    if CFG.AUTO_SKILL and tick()-lastSkillFire >= CFG.SKILL_COOLDOWN then
        lastSkillFire = tick()
        if not fireRemote("UseSkill") then
            fireRemote("ActivateSkill") or fireRemote("Skill")
        end
        local c = getChar(); if c then
            for _, t in ipairs(c:GetChildren()) do
                if t:IsA("Tool") and t.Name:lower():find("skill") then
                    pcall(function() t:Activate() end)
                end
            end
        end
    end

    if CFG.BUILDERMAN_AUTO_SENTRY then
        local kd = nearestKillerDist()
        if kd <= CFG.SENTRY_RANGE and tick()-CFG._sentryLastDrop >= CFG.SENTRY_COOLDOWN then
            CFG._sentryLastDrop = tick()
            if not fireRemote("PlaceSentry") then
                fireRemote("DropSentry") or fireRemote("DeploySentry") or fireRemote("Builderman_Sentry")
            end
            local c = getChar(); if c then
                for _, t in ipairs(c:GetChildren()) do
                    if t:IsA("Tool") and (t.Name:lower():find("sentry") or t.Name:lower():find("dispenser")) then
                        pcall(function() t:Activate() end)
                    end
                end
            end
        end
    end

    tickHelperbot()
end

-- ┌─────────────────────────────────────────────────────────┐
-- │                   MISC                                   │
-- └─────────────────────────────────────────────────────────┘
local lastChat = 0
local emoteConn = nil

local function tickMisc()
    if CFG.TP_TO_GEN then
        CFG.TP_TO_GEN = false
        local gen = nearestIncompleteGen()
        if gen then
            local hrp  = getHRP()
            local root = gen:FindFirstChild("PrimaryPart") or gen:FindFirstChildOfClass("BasePart")
            if hrp and root then hrp.CFrame = root.CFrame + Vector3.new(0,5,0) end
        end
    end
    if CFG.TP_TO_EXIT then
        CFG.TP_TO_EXIT = false
        for _, obj in ipairs(descCache()) do
            if (obj.Name:lower():find("exit") or obj.Name:lower():find("gate"))
                and obj:IsA("BasePart") then
                local hrp = getHRP()
                if hrp then hrp.CFrame = obj.CFrame + Vector3.new(0,5,0) end
                break
            end
        end
    end
    if CFG.SERVER_HOP then
        CFG.SERVER_HOP = false
        pcall(function() TeleportService:Teleport(game.PlaceId, LP) end)
    end
    if CFG.AUTO_WIN then
        fireRemote("PlayerWin") or fireRemote("Escape") or fireRemote("SurvivorEscape")
    end
    if CFG.GET_G666 then
        CFG.GET_G666 = false
        fireRemote("GetG666") or fireRemote("G666Collect") or fireRemote("SpecialItem")
    end
    if CFG.CHAT_SPAM and tick()-lastChat > CFG.CHAT_DELAY then
        lastChat = tick()
        pcall(function()
            game:GetService("Chat"):Chat(getChar(), CFG.CHAT_MSG, Enum.ChatColor.White)
        end)
    end
    if CFG.AUTO_EMOTE then
        if not emoteConn then
            local hum = getHum(); if hum then
                local anim = Instance.new("Animation")
                anim.AnimationId = "rbxassetid://"..tostring(CFG.EMOTE_ID)
                local track = hum:LoadAnimation(anim); track:Play()
                emoteConn = trackConn(RunService.Heartbeat:Connect(function()
                    if not CFG.AUTO_EMOTE then
                        track:Stop(); emoteConn:Disconnect(); emoteConn=nil
                    elseif not track.IsPlaying then
                        track:Play()
                    end
                end))
            end
        end
    elseif emoteConn then
        emoteConn:Disconnect(); emoteConn=nil
    end
    if CFG.SAVE_CONFIG then
        CFG.SAVE_CONFIG = false
        pcall(function()
            local out = {}
            for k, v in pairs(CFG) do
                if type(v)=="boolean" or type(v)=="number" or type(v)=="string" then out[k]=v end
            end
            writefile("ForsakenHubConfig.json", HttpService:JSONEncode(out))
            StarterGui:SetCore("SendNotification",{Title="ForsakenHub",Text="Config saved!",Duration=3})
        end)
    end
    if CFG.LOAD_CONFIG then
        CFG.LOAD_CONFIG = false
        pcall(function()
            if isfile("ForsakenHubConfig.json") then
                local data = HttpService:JSONDecode(readfile("ForsakenHubConfig.json"))
                for k, v in pairs(data) do
                    if CFG[k] ~= nil and type(v) == type(CFG[k]) then CFG[k]=v end
                end
                StarterGui:SetCore("SendNotification",{Title="ForsakenHub",Text="Config loaded!",Duration=3})
            end
        end)
    end
    if CFG.COLLECT_ALL then
        CFG.COLLECT_ALL = false
        local items = {}
        for _, obj in ipairs(descCache()) do
            if obj:IsA("Tool") or obj:IsA("BasePart") then
                local n = obj.Name:lower()
                if n:find("medkit") or n:find("bloxycola") or n:find("toolbox") or n:find("key") then
                    local bp = obj:IsA("BasePart") and obj or obj:FindFirstChildOfClass("BasePart")
                    if bp then table.insert(items, bp) end
                end
            end
        end
        task.spawn(function()
            for _, bp in ipairs(items) do
                local hrp = getHRP()
                if hrp then hrp.CFrame = bp.CFrame + Vector3.new(0,3,0) end
                task.wait(0.5)
            end
        end)
    end
end

-- ┌─────────────────────────────────────────────────────────┐
-- │  [#26] ITEMS — extended names                            │
-- │  Originals: medkit, bloxycola, toolbox, key, etc.       │
-- │  New: water sprayer, gear/gears, fruit variants          │
-- └─────────────────────────────────────────────────────────┘
local ITEM_NAMES_BASE = {
    "medkit","bloxycola","sentry","toolbox","key","flashlight","map","perk","item"
}
local ITEM_NAMES_EXT = {
    -- [#26] new items
    "water","sprayer","spray",   -- water sprayer
    "gear","cog","wheel",        -- gears
    "fruit","apple","orange","berry","grape",  -- fruits
}

local function isItem(obj)
    if not (obj:IsA("Tool") or obj:IsA("Model") or obj:IsA("BasePart")) then return false end
    local n = obj.Name:lower()
    for _, k in ipairs(ITEM_NAMES_BASE) do if n:find(k) then return true end end
    if CFG.ITEM_ESP_EXTENDED then
        for _, k in ipairs(ITEM_NAMES_EXT) do if n:find(k) then return true end end
    end
    return false
end

-- [#45] Item cache — rebuilt every 0.5s via descCache
local function getItemCache()
    local now = tick()
    if now - CFG._itemCacheTt < 0.5 then return CFG._itemCache end
    CFG._itemCacheTt = now
    local cache = {}
    for _, obj in ipairs(descCache()) do
        if isItem(obj) then cache[#cache+1] = obj end
    end
    CFG._itemCache = cache
    return cache
end

local function tickItems()
    local hrp = getHRP()
    local nearestItem, nearestDist = nil, math.huge
    local nearestGear, nearestGearDist = nil, math.huge

    for _, obj in ipairs(getItemCache()) do
        if CFG.ITEM_ESP then
            applyESP(obj, CFG.ITEM_COLOR)
            if CFG.SHOW_ITEM_NAMES then applyBillboard(obj, obj.Name) end
        else
            clearESP(obj)
        end

        if hrp then
            local root = obj:IsA("BasePart") and obj or obj:FindFirstChildOfClass("BasePart")
            if root then
                local d = (hrp.Position - root.Position).Magnitude

                if CFG.AUTO_PICKUP and d < nearestDist then
                    nearestItem = root; nearestDist = d
                end

                -- [#21] Gear pickup
                if CFG.AUTO_PICK_GEARS then
                    local n = obj.Name:lower()
                    local isGear = n:find("gear") or n:find("cog") or n:find("wheel")
                    if isGear and d < nearestGearDist then
                        nearestGear = root; nearestGearDist = d
                    end
                end
            end
        end
    end

    if CFG.AUTO_PICKUP and nearestItem and nearestDist <= CFG.ITEM_PICKUP_RANGE then
        if hrp then hrp.CFrame = nearestItem.CFrame + Vector3.new(0,3,0) end
    end

    -- [#21] Auto pick gears — TP + try ProximityPrompt
    if CFG.AUTO_PICK_GEARS and nearestGear and nearestGearDist <= CFG.GEAR_PICKUP_RANGE then
        if hrp then
            hrp.CFrame = nearestGear.CFrame + Vector3.new(0,3,0)
            -- Fire pickup prompt if available
            local pp = nearestGear.Parent and nearestGear.Parent:FindFirstChildOfClass("ProximityPrompt")
            if pp then pcall(fireproximityprompt, pp) end
        end
    end
end

-- ┌─────────────────────────────────────────────────────────┐
-- │               SHORTKEY SYSTEM                            │
-- └─────────────────────────────────────────────────────────┘
local function setupShortkeys()
    trackConn(UserInputService.InputBegan:Connect(function(inp, gameProcessed)
        if gameProcessed then return end
        for cfgKey, keyCode in pairs(CFG.SHORTKEYS) do
            if inp.KeyCode == keyCode then
                if type(CFG[cfgKey]) == "boolean" then
                    CFG[cfgKey] = not CFG[cfgKey]
                    pcall(function()
                        StarterGui:SetCore("SendNotification",{
                            Title   = "ForsakenHub",
                            Text    = cfgKey.." "..(CFG[cfgKey] and "ON" or "OFF"),
                            Duration= 1.5
                        })
                    end)
                end
            end
        end
    end))
end
setupShortkeys()

-- ┌─────────────────────────────────────────────────────────┐
-- │                   MAIN LOOP                              │
-- └─────────────────────────────────────────────────────────┘
local lastTick = 0
trackConn(RunService.Heartbeat:Connect(function()
    if not LOADED then return end
    local now = tick()
    if now - lastTick < CFG.LOOP_THROTTLE then return end
    lastTick = now

    -- [#45] Refresh shared desc cache once per loop
    refreshDescCache()

    tickGens(); tickBlock(); tickSurvivors(); tickKillers()
    tickAimbot(); tickAntis(); tickSkills(); tickMisc(); tickItems()
    applyVisual(); updateShieldLabel()
end))

trackConn(LP.CharacterAdded:Connect(function(char)
    task.wait(1)
    applyStamina(); applyNoclip(); buildKillerAlert()
    -- [#47] Strip ragdoll joints on respawn
    if CFG.REMOVE_RAGDOLLS then stripRagdollJoints(char) end
    setupM1Watch()
end))

setupM1Watch()

-- ┌─────────────────────────────────────────────────────────┐
-- │              UNLOAD                                      │
-- └─────────────────────────────────────────────────────────┘
local function Unload()
    LOADED = false
    disconnectAll()
    removeAllESP()
    for _, bb in pairs(billboards) do bb:Destroy() end
    billboards = {}
    if crosshairGui   then crosshairGui:Destroy();   crosshairGui=nil   end
    if killerAlertGui then killerAlertGui:Destroy(); killerAlertGui=nil end

    -- [#28] Restore all Veronica bumper sizes
    for root, origSize in pairs(CFG._veronicaOrigSizes) do
        pcall(function() root.Size = origSize end)
    end
    CFG._veronicaOrigSizes = {}

    -- [#20/#48] Restore NPCs
    if _npcRemoved then restoreLobbyNPCs() end

    local hum = getHum()
    if hum then hum.WalkSpeed = CFG.SPEED_DEFAULT; hum.JumpPower = 50 end
    local c = getChar()
    if c then
        for _, p in ipairs(c:GetDescendants()) do
            if p:IsA("BasePart") then p.CanCollide=true; p.Transparency=0 end
        end
    end

    local L = game:GetService("Lighting")
    if origAmbient then L.Ambient=origAmbient; L.OutdoorAmbient=origAmbient; L.Brightness=origBright or 1 end
    if origFogEnd  then L.FogEnd=origFogEnd; L.FogStart=origFogStart end
    Camera.FieldOfView = 70

    local hubGui = LP.PlayerGui:FindFirstChild("ForsakenHubV4")
    if hubGui then hubGui:Destroy() end
    local marker = Workspace:FindFirstChild("BloodhookMarker")
    if marker then marker:Destroy() end

    print("[ForsakenHub v4.1] unloaded — clean exit")
end

-- ┌─────────────────────────────────────────────────────────┐
-- │              ANDROID GUI — 14-TAB TOUCH PANEL            │
-- └─────────────────────────────────────────────────────────┘
local PANEL_W  = 252
local BTN_H    = 52
local BTN_PAD  = 5
local TAB_H    = 36
local ACCENT   = Color3.fromRGB(170, 25, 25)
local BG       = Color3.fromRGB(12, 12, 18)
local BTN_OFF  = Color3.fromRGB(30, 30, 42)
local BTN_ON   = Color3.fromRGB(14, 46, 18)
local TEXT_OFF = Color3.fromRGB(160, 160, 160)
local TEXT_ON  = Color3.fromRGB(80, 255, 100)
local ACT_BG   = Color3.fromRGB(42, 22, 70)
local ACT_TEXT = Color3.fromRGB(190, 150, 255)
local NUM_BG   = Color3.fromRGB(22, 22, 34)

local sg = Instance.new("ScreenGui")
sg.Name            = "ForsakenHubV4"
sg.ResetOnSpawn    = false
sg.IgnoreGuiInset  = true
sg.ZIndexBehavior  = Enum.ZIndexBehavior.Sibling
sg.Parent          = LP.PlayerGui

local panel = Instance.new("Frame")
panel.Name            = "Panel"
panel.Position        = UDim2.new(0,10,0.22,0)
panel.Size            = UDim2.new(0,PANEL_W,0,500)
panel.BackgroundColor3= BG
panel.BorderSizePixel = 0
panel.Active          = true
panel.Parent          = sg
Instance.new("UICorner", panel).CornerRadius = UDim.new(0,14)

local titleBar = Instance.new("Frame")
titleBar.Size             = UDim2.new(1,0,0,40)
titleBar.BackgroundColor3 = ACCENT
titleBar.BorderSizePixel  = 0
titleBar.Parent           = panel
Instance.new("UICorner", titleBar).CornerRadius = UDim.new(0,14)

local titleLbl = Instance.new("TextLabel")
titleLbl.Size                  = UDim2.new(1,-42,1,0)
titleLbl.BackgroundTransparency= 1
titleLbl.Text                  = "FORSAKEN HUB v4.1"
titleLbl.TextColor3            = Color3.fromRGB(255,255,255)
titleLbl.TextSize              = 15
titleLbl.Font                  = Enum.Font.GothamBold
titleLbl.Parent                = titleBar

local minBtn = Instance.new("TextButton")
minBtn.Size              = UDim2.new(0,36,0,36)
minBtn.Position          = UDim2.new(1,-38,0,2)
minBtn.BackgroundColor3  = Color3.fromRGB(58,58,70)
minBtn.Text              = "-"
minBtn.TextColor3        = Color3.fromRGB(255,255,255)
minBtn.TextSize          = 20
minBtn.Font              = Enum.Font.GothamBold
minBtn.BorderSizePixel   = 0
minBtn.ZIndex            = 10
minBtn.Parent            = panel
Instance.new("UICorner", minBtn).CornerRadius = UDim.new(0,8)

local tabRow = Instance.new("ScrollingFrame")
tabRow.Size              = UDim2.new(1,0,0,TAB_H+4)
tabRow.Position          = UDim2.new(0,0,0,40)
tabRow.BackgroundColor3  = Color3.fromRGB(18,18,28)
tabRow.BorderSizePixel   = 0
tabRow.ScrollBarThickness= 0
tabRow.ScrollingDirection= Enum.ScrollingDirection.X
tabRow.CanvasSize        = UDim2.new(0,0,0,0)
tabRow.Parent            = panel

local tabLayout = Instance.new("UIListLayout")
tabLayout.FillDirection = Enum.FillDirection.Horizontal
tabLayout.SortOrder     = Enum.SortOrder.LayoutOrder
tabLayout.Padding       = UDim.new(0,2)
tabLayout.Parent        = tabRow

local contentArea = Instance.new("ScrollingFrame")
contentArea.Position            = UDim2.new(0,0,0,44+TAB_H)
contentArea.Size                = UDim2.new(1,0,1,-(44+TAB_H))
contentArea.BackgroundTransparency = 1
contentArea.BorderSizePixel     = 0
contentArea.ScrollBarThickness  = 3
contentArea.ScrollBarImageColor3= ACCENT
contentArea.CanvasSize          = UDim2.new(0,0,0,0)
contentArea.Parent              = panel

-- Drag
local dragging, dragStart, startPos = false, nil, nil
titleBar.InputBegan:Connect(function(inp)
    if inp.UserInputType == Enum.UserInputType.Touch
    or inp.UserInputType == Enum.UserInputType.MouseButton1 then
        dragging  = true
        dragStart = inp.Position
        startPos  = panel.Position
    end
end)
titleBar.InputEnded:Connect(function(inp)
    if inp.UserInputType == Enum.UserInputType.Touch
    or inp.UserInputType == Enum.UserInputType.MouseButton1 then
        dragging = false
    end
end)
UserInputService.InputChanged:Connect(function(inp)
    if dragging and (inp.UserInputType == Enum.UserInputType.Touch
    or inp.UserInputType == Enum.UserInputType.MouseMove) then
        local d = inp.Position - dragStart
        panel.Position = UDim2.new(
            startPos.X.Scale, startPos.X.Offset + d.X,
            startPos.Y.Scale, startPos.Y.Offset + d.Y
        )
    end
end)

-- Tab builder
local tabs      = {}
local tabButtons= {}
local btnOrders = {}

local function showTab(name)
    for n, f in pairs(tabs)       do f.Visible = (n == name) end
    for n, b in pairs(tabButtons) do
        b.BackgroundColor3 = (n == name) and ACCENT or Color3.fromRGB(26,26,38)
        b.TextColor3       = Color3.fromRGB(255,255,255)
    end
    local frame = tabs[name]; if not frame then return end
    local h = 0
    for _, c in ipairs(frame:GetChildren()) do
        if c:IsA("GuiObject") then h = h + c.AbsoluteSize.Y + BTN_PAD end
    end
    contentArea.CanvasSize = UDim2.new(0,0,0,h+10)
    panel.Size = UDim2.new(0,PANEL_W,0,math.clamp(h+44+TAB_H+20,150,560))
end

local function newTab(name, order)
    local btn = Instance.new("TextButton")
    btn.Name             = name
    btn.LayoutOrder      = order
    btn.Size             = UDim2.new(0,82,0,TAB_H)
    btn.BackgroundColor3 = Color3.fromRGB(26,26,38)
    btn.Text             = name
    btn.TextColor3       = Color3.fromRGB(190,190,190)
    btn.TextSize         = 11
    btn.Font             = Enum.Font.GothamSemibold
    btn.BorderSizePixel  = 0
    btn.Parent           = tabRow
    tabButtons[name]     = btn

    local frame = Instance.new("Frame")
    frame.Name                  = name.."Frame"
    frame.Size                  = UDim2.new(1,0,1,0)
    frame.BackgroundTransparency= 1
    frame.Visible               = false
    frame.Parent                = contentArea

    local lay = Instance.new("UIListLayout")
    lay.SortOrder = Enum.SortOrder.LayoutOrder
    lay.Padding   = UDim.new(0,BTN_PAD)
    lay.Parent    = frame

    local pad = Instance.new("UIPadding")
    pad.PaddingTop   = UDim.new(0,6)
    pad.PaddingLeft  = UDim.new(0,8)
    pad.PaddingRight = UDim.new(0,8)
    pad.Parent       = frame

    tabs[name]      = frame
    btnOrders[frame]= 0

    btn.MouseButton1Click:Connect(function() showTab(name) end)

    task.defer(function()
        local total = 0
        for _, c in ipairs(tabRow:GetChildren()) do
            if c:IsA("GuiObject") then total = total + c.AbsoluteSize.X + 2 end
        end
        tabRow.CanvasSize = UDim2.new(0,total+10,0,0)
    end)
    return frame
end

local function addToggle(frame, labelOff, labelOn, configKey, cb)
    btnOrders[frame] = (btnOrders[frame] or 0) + 1
    local btn = Instance.new("TextButton")
    btn.LayoutOrder       = btnOrders[frame]
    btn.Size              = UDim2.new(1,0,0,BTN_H)
    btn.BackgroundColor3  = BTN_OFF
    btn.Text              = "[ OFF ]  "..labelOff
    btn.TextColor3        = TEXT_OFF
    btn.TextSize          = 13
    btn.Font              = Enum.Font.GothamSemibold
    btn.AutoButtonColor   = false
    btn.TextXAlignment    = Enum.TextXAlignment.Left
    btn.BorderSizePixel   = 0
    btn.Parent            = frame
    local p = Instance.new("UIPadding"); p.PaddingLeft = UDim.new(0,10); p.Parent = btn
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0,8)

    local function refresh()
        if CFG[configKey] then
            btn.Text             = "[ ON  ]  "..labelOn
            btn.TextColor3       = TEXT_ON
            btn.BackgroundColor3 = BTN_ON
        else
            btn.Text             = "[ OFF ]  "..labelOff
            btn.TextColor3       = TEXT_OFF
            btn.BackgroundColor3 = BTN_OFF
        end
    end
    btn.MouseButton1Click:Connect(function()
        CFG[configKey] = not CFG[configKey]
        refresh()
        if cb then cb(CFG[configKey]) end
    end)
    btn.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.Touch then
            TweenService:Create(btn, TweenInfo.new(0.07), {BackgroundColor3=Color3.fromRGB(52,52,74)}):Play()
        end
    end)
    btn.InputEnded:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.Touch then task.delay(0.12, refresh) end
    end)
    return btn
end

local function addAction(frame, label, cb)
    btnOrders[frame] = (btnOrders[frame] or 0) + 1
    local btn = Instance.new("TextButton")
    btn.LayoutOrder       = btnOrders[frame]
    btn.Size              = UDim2.new(1,0,0,BTN_H)
    btn.BackgroundColor3  = ACT_BG
    btn.Text              = ">  "..label
    btn.TextColor3        = ACT_TEXT
    btn.TextSize          = 13
    btn.Font              = Enum.Font.GothamSemibold
    btn.AutoButtonColor   = false
    btn.TextXAlignment    = Enum.TextXAlignment.Left
    btn.BorderSizePixel   = 0
    btn.Parent            = frame
    local p = Instance.new("UIPadding"); p.PaddingLeft = UDim.new(0,10); p.Parent = btn
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0,8)
    btn.MouseButton1Click:Connect(cb)
    return btn
end

local function addNumInput(frame, label, configKey, step, minVal, maxVal)
    btnOrders[frame] = (btnOrders[frame] or 0) + 1
    step   = step   or 1
    minVal = minVal or 0
    maxVal = maxVal or 999

    local row = Instance.new("Frame")
    row.LayoutOrder      = btnOrders[frame]
    row.Size             = UDim2.new(1,0,0,BTN_H)
    row.BackgroundColor3 = NUM_BG
    row.BorderSizePixel  = 0
    row.Parent           = frame
    Instance.new("UICorner", row).CornerRadius = UDim.new(0,8)

    local lbl = Instance.new("TextLabel")
    lbl.Size                  = UDim2.new(0.52,0,1,0)
    lbl.Position              = UDim2.new(0,10,0,0)
    lbl.BackgroundTransparency= 1
    lbl.Text                  = label
    lbl.TextColor3            = Color3.fromRGB(200,200,200)
    lbl.TextSize              = 12
    lbl.Font                  = Enum.Font.GothamSemibold
    lbl.TextXAlignment        = Enum.TextXAlignment.Left
    lbl.Parent                = row

    local valLbl = Instance.new("TextLabel")
    valLbl.Size                  = UDim2.new(0.22,0,1,0)
    valLbl.Position              = UDim2.new(0.52,0,0,0)
    valLbl.BackgroundTransparency= 1
    valLbl.TextColor3            = Color3.fromRGB(255,220,80)
    valLbl.TextSize              = 13
    valLbl.Font                  = Enum.Font.GothamBold
    valLbl.Parent                = row

    local function updateVal()
        local v = CFG[configKey]
        if v == math.floor(v) then
            valLbl.Text = tostring(math.floor(v))
        else
            valLbl.Text = string.format("%.1f", v)
        end
    end
    updateVal()

    local minuBtn = Instance.new("TextButton")
    minuBtn.Size             = UDim2.new(0,34,0,34)
    minuBtn.Position         = UDim2.new(0.74,0,0.5,-17)
    minuBtn.BackgroundColor3 = Color3.fromRGB(80,30,30)
    minuBtn.Text             = "-"
    minuBtn.TextColor3       = Color3.fromRGB(255,120,120)
    minuBtn.TextSize         = 18
    minuBtn.Font             = Enum.Font.GothamBold
    minuBtn.BorderSizePixel  = 0
    minuBtn.Parent           = row
    Instance.new("UICorner", minuBtn).CornerRadius = UDim.new(0,6)

    local plusBtn = Instance.new("TextButton")
    plusBtn.Size             = UDim2.new(0,34,0,34)
    plusBtn.Position         = UDim2.new(0.88,0,0.5,-17)
    plusBtn.BackgroundColor3 = Color3.fromRGB(20,60,20)
    plusBtn.Text             = "+"
    plusBtn.TextColor3       = Color3.fromRGB(80,255,100)
    plusBtn.TextSize         = 18
    plusBtn.Font             = Enum.Font.GothamBold
    plusBtn.BorderSizePixel  = 0
    plusBtn.Parent           = row
    Instance.new("UICorner", plusBtn).CornerRadius = UDim.new(0,6)

    minuBtn.MouseButton1Click:Connect(function()
        CFG[configKey] = math.max(minVal, math.floor((CFG[configKey]-step)*10+0.5)/10)
        updateVal()
    end)
    plusBtn.MouseButton1Click:Connect(function()
        CFG[configKey] = math.min(maxVal, math.floor((CFG[configKey]+step)*10+0.5)/10)
        updateVal()
    end)
    return row
end

local bindingTarget = nil
local function addShortkey(frame, label, configKey)
    btnOrders[frame] = (btnOrders[frame] or 0) + 1
    local row = Instance.new("Frame")
    row.LayoutOrder      = btnOrders[frame]
    row.Size             = UDim2.new(1,0,0,BTN_H)
    row.BackgroundColor3 = Color3.fromRGB(20,20,34)
    row.BorderSizePixel  = 0
    row.Parent           = frame
    Instance.new("UICorner", row).CornerRadius = UDim.new(0,8)

    local lbl = Instance.new("TextLabel")
    lbl.Size                  = UDim2.new(0.56,0,1,0)
    lbl.Position              = UDim2.new(0,10,0,0)
    lbl.BackgroundTransparency= 1
    lbl.Text                  = label
    lbl.TextColor3            = Color3.fromRGB(190,190,190)
    lbl.TextSize              = 12
    lbl.Font                  = Enum.Font.GothamSemibold
    lbl.TextXAlignment        = Enum.TextXAlignment.Left
    lbl.Parent                = row

    local bindBtn = Instance.new("TextButton")
    bindBtn.Size             = UDim2.new(0.4,-4,0.72,0)
    bindBtn.Position         = UDim2.new(0.58,0,0.14,0)
    bindBtn.BackgroundColor3 = Color3.fromRGB(40,30,60)
    local current = CFG.SHORTKEYS[configKey]
    bindBtn.Text             = current and current.Name or "None"
    bindBtn.TextColor3       = Color3.fromRGB(180,140,255)
    bindBtn.TextSize         = 12
    bindBtn.Font             = Enum.Font.GothamSemibold
    bindBtn.BorderSizePixel  = 0
    bindBtn.Parent           = row
    Instance.new("UICorner", bindBtn).CornerRadius = UDim.new(0,6)

    bindBtn.MouseButton1Click:Connect(function()
        bindingTarget = configKey
        bindBtn.Text      = "Press key..."
        bindBtn.TextColor3= Color3.fromRGB(255,255,80)
    end)

    trackConn(UserInputService.InputBegan:Connect(function(inp, gp)
        if gp then return end
        if bindingTarget == configKey then
            CFG.SHORTKEYS[configKey] = inp.KeyCode
            bindBtn.Text             = inp.KeyCode.Name
            bindBtn.TextColor3       = Color3.fromRGB(180,140,255)
            bindingTarget            = nil
        end
    end))

    return row
end

-- ── Build tabs ───────────────────────────────────────────────

-- 1. STAMINA
local tS = newTab("Stamina", 1)
addToggle(tS,"Infinite Stamina","INF Stamina","INF_STAMINA",applyStamina)
addToggle(tS,"Fast Stamina Refill","Fast Refill","STAMINA_REFILL_SPEED",applyStamina)
addToggle(tS,"No Sprint Penalty","No Penalty","NO_SPRINT_PENALTY",applyStamina)

-- 2. VISUAL
local tV = newTab("Visual", 2)
addToggle(tV,"Full Bright","FULL BRIGHT","FULL_BRIGHT",applyVisual)
addToggle(tV,"No Fog","NO FOG","NO_FOG",applyVisual)
addToggle(tV,"Custom FOV","FOV ON","CUSTOM_FOV",applyVisual)
addNumInput(tV,"FOV Value","FOV_VALUE",5,40,120)
addToggle(tV,"Self Chams","CHAMS ON","CHAMS_SELF",applyVisual)
addToggle(tV,"Crosshair","CROSSHAIR ON","CROSSHAIR",applyVisual)
addToggle(tV,"Remove Blur","BLUR OFF","REMOVE_BLUR")
addToggle(tV,"Remove Acid Grade","ACID OFF","REMOVE_ACID")
addToggle(tV,"Remove Blindness","BLIND OFF","REMOVE_BLINDNESS")
addToggle(tV,"Remove Slowness","SLOW OFF","REMOVE_SLOWNESS")
addToggle(tV,"Invisible Mode","INVIS ON","INVISIBLE_MODE")
addToggle(tV,"Remove Lobby NPCs","NPCs OFF","REMOVE_LOBBY_NPCS",applyVisual)  -- [#20/#48]
addToggle(tV,"Remove Ragdolls","RAGDOLL OFF","REMOVE_RAGDOLLS",applyRagdollRemoval)  -- [#47]

-- 3. GENERATORS
local tG = newTab("Gens", 3)
addToggle(tG,"Generator ESP","GEN ESP","GEN_ESP")
addToggle(tG,"Show Progress %","PROGRESS","GEN_PROGRESS_ESP")
addToggle(tG,"Auto-off ESP on Complete","AUTO OFF","GEN_ESP_AUTO_OFF")  -- [#24]
addToggle(tG,"Auto Generator","AUTO GEN","AUTO_GEN")
addNumInput(tG,"Gen Range (studs)","GEN_RANGE",0.5,1,30)
addAction(tG,"Insta-Complete All",function() CFG.INSTA_GEN=true end)
addAction(tG,"TP to Nearest Gen",function() CFG.TP_TO_GEN=true end)

-- 4. BLOCK
local tB = newTab("Block", 4)
addToggle(tB,"Auto Block","AUTO BLOCK","AUTO_BLOCK")
addNumInput(tB,"Block Range","BLOCK_RANGE",1,5,50)
addToggle(tB,"Hold Block","HOLD BLOCK","BLOCK_HOLD")
addToggle(tB,"Perfect Block","PERFECT","PERFECT_BLOCK")
addToggle(tB,"Shield Detect","DETECT ON","SHIELD_DETECT")
addToggle(tB,"Suppress When Shielded","SHIELD SUPP","SHIELD_SUPPRESS_STUN")
addNumInput(tB,"Shield Duration (s)","SHIELD_TIMER_SECS",0.5,1,20)
addToggle(tB,"M1 TP Dodge","TP DODGE","AUTO_BLOCK_TP",setupM1Watch)  -- [#23]
addNumInput(tB,"M1 Detect Range (studs)","BLOCK_TP_RANGE",0.5,2,15)
addNumInput(tB,"Dodge Distance (studs)","BLOCK_TP_DIST",0.5,1,12)
addNumInput(tB,"Dodge Cooldown (s)","BLOCK_TP_COOLDOWN",0.1,0.1,2)

-- 5. SURVIVORS
local tSv = newTab("Survs", 5)
addToggle(tSv,"Survivor ESP","SURV ESP","SURVIVOR_ESP")
addToggle(tSv,"Show Names","NAMES","SURV_SHOW_NAME")
addToggle(tSv,"Show Health","HEALTH","SURV_SHOW_HEALTH")
addToggle(tSv,"Speed Hack","SPEED ON","SPEED_HACK")
addNumInput(tSv,"Walk Speed","SPEED_VALUE",0.5,16,100)
addToggle(tSv,"Out-Chase Speed Boost","CHASE BOOST","CHASE_SPEED_BOOST")
addNumInput(tSv,"Chase Speed Multiplier","CHASE_SPEED_MULT",0.5,1,5)
addToggle(tSv,"Jump Power Boost","JUMP ON","JUMP_POWER")
addNumInput(tSv,"Jump Power","JUMP_VALUE",5,50,300)
addToggle(tSv,"Noclip","NOCLIP ON","NOCLIP",applyNoclip)
addToggle(tSv,"Noclip Crash-Safe","SAFE EXIT","NOCLIP_SAFE")
addToggle(tSv,"Auto Heal <HP","HEAL ON","AUTO_HEAL")
addNumInput(tSv,"Heal Threshold","HEAL_THRESHOLD",5,10,100)
addToggle(tSv,"Teleport-Lag Move","TPLAG ON","TPLAG_ENABLED")
addNumInput(tSv,"TPLag Interval (s)","TPLAG_INTERVAL",0.1,0.1,2)
addNumInput(tSv,"TPLag Distance","TPLAG_DIST",0.5,1,20)
addToggle(tSv,"John Doe Trap Speed","JD TRAP","JOHNDOE_TRAP_SPEED")
addNumInput(tSv,"Trap Speed Override","JOHNDOE_TRAP_VAL",0.5,0,30)
addNumInput(tSv,"Trap Detect Range","JOHNDOE_TRAP_RANGE",1,2,30)
addToggle(tSv,"Bloodhook Predict","PREDICT ON","BLOODHOOK_PREDICT")
addToggle(tSv,"Blood Stack Mult","BLOOD MULT","BLOOD_STACK_MULT")
addNumInput(tSv,"Blood Multiplier","BLOOD_MULT_VALUE",0.5,1,10)
addToggle(tSv,"Push Override","PUSH ON","PUSH_OVERRIDE")
addNumInput(tSv,"Push Amount","PUSH_AMOUNT",5,10,300)
addAction(tSv,"TP to Hooked Surv",function() CFG.TP_TO_HOOKED=true end)

-- 6. KILLERS
local tK = newTab("Killers", 6)
addToggle(tK,"Killer ESP","ESP ON","KILLER_ESP")
addToggle(tK,"Show Killer Name","NAME ON","SHOW_KILLER_NAME")
addToggle(tK,"Distance Alert","ALERT ON","KILLER_DIST_ALERT")
addNumInput(tK,"Alert Range","KILLER_ALERT_RANGE",5,10,100)
addToggle(tK,"Kill Aura","AURA ON","KILL_AURA")
addToggle(tK,"Auto Slash","SLASH ON","AUTO_SLASH")
addNumInput(tK,"Slash Range","SLASH_RANGE",0.5,3,30)
addToggle(tK,"Auto Backstab","BACKSTAB","AUTO_BACKSTAB")
addToggle(tK,"Double Backstab Aimbot","DBL BKSTB","DOUBLE_BACKSTAB")
addNumInput(tK,"Backstab FOV (deg)","BACKSTAB_FOV",5,10,90)
addNumInput(tK,"Backstab Smooth","BACKSTAB_SMOOTH",0.05,0,1)
addToggle(tK,"Auto Gashing","GASH ON","AUTO_GASH")
addNumInput(tK,"Gash Bleed Thresh","GASH_BLEED_THRESH",1,1,10)
addToggle(tK,"Veronica Bumper","BUMPER ON","VERONICA_BUMPER")  -- [#28]
addNumInput(tK,"Bumper Size (studs)","VERONICA_BUMPER_SIZE",1,4,20)
addToggle(tK,"No Killer Skate","NO SKATE","NO_KILLER_SKATE")
addToggle(tK,"Stun Color Change","STUN COL","KILLER_ESP")  -- drives via isKillerStunned in tick

-- 7. AIMBOT
local tA = newTab("Aimbot", 7)
addToggle(tA,"Aimbot","AIMBOT ON","AIMBOT")
addNumInput(tA,"Aimbot FOV (deg)","AIMBOT_FOV",5,10,180)
addNumInput(tA,"Aimbot Smooth","AIMBOT_SMOOTHING",0.05,0,1)
addToggle(tA,"Silent Aim","SILENT","SILENT_AIM")
addToggle(tA,"Silent Aim Prediction","PREDICT","SILENT_PREDICT")  -- [#31]
addToggle(tA,"Killer Only","KLR ONLY","AIMBOT_KILLER_ONLY")
addToggle(tA,"Hitbox Extender","HITBOX","HITBOX_EXTENDER")
addNumInput(tA,"Hitbox Size","HITBOX_SIZE",0.5,2,20)
addToggle(tA,"Speed Lock While Aiming","SPD LOCK","AIMBOT_SPEED_LOCK")
addNumInput(tA,"Speed Lock Value","AIMBOT_SPEED_LOCK_VAL",0.5,0,16)

-- 8. ANTIS
local tAn = newTab("Antis", 8)
addToggle(tAn,"Anti-AFK","ANTI AFK","ANTI_AFK")
addToggle(tAn,"Anti-Ragdoll","NO RAGDOLL","ANTI_RAGDOLL")
addToggle(tAn,"Anti-Stun","NO STUN","ANTI_STUN")
addToggle(tAn,"Anti-Grab","NO GRAB","ANTI_GRAB")
addToggle(tAn,"Anti-Lag","AUTO QUAL","ANTI_LAG")

-- 9. SKILLS
local tSk = newTab("Skills", 9)
addToggle(tSk,"Auto Skill","AUTO SKILL","AUTO_SKILL")
addNumInput(tSk,"Skill Cooldown (s)","SKILL_COOLDOWN",0.5,1,60)
addToggle(tSk,"Builderman Auto Sentry","AUTO SENT","BUILDERMAN_AUTO_SENTRY")
addNumInput(tSk,"Sentry Range (studs)","SENTRY_RANGE",5,10,100)
addNumInput(tSk,"Sentry Cooldown (s)","SENTRY_COOLDOWN",1,5,120)
addToggle(tSk,"Helperbot Range Extend","HELPER+","HELPERBOT_EXTEND")  -- [#44]
addToggle(tSk,"Helperbot Anti-Miss","NO MISS","HELPERBOT_ANTIMISS")
addNumInput(tSk,"Helperbot Range","HELPERBOT_RANGE",5,15,100)
addNumInput(tSk,"Helperbot Cooldown (s)","HELPERBOT_COOLDOWN",0.5,1,30)

-- 10. ITEMS
local tI = newTab("Items", 10)
addToggle(tI,"Item ESP","ESP ON","ITEM_ESP")
addToggle(tI,"Extended Item ESP","EXT ESP","ITEM_ESP_EXTENDED")  -- [#26]
addToggle(tI,"Show Names","NAMES ON","SHOW_ITEM_NAMES")
addToggle(tI,"Auto Pickup","PICKUP ON","AUTO_PICKUP")
addNumInput(tI,"Pickup Range","ITEM_PICKUP_RANGE",0.5,3,50)
addToggle(tI,"Auto Pick Gears","GEARS ON","AUTO_PICK_GEARS")  -- [#21]
addNumInput(tI,"Gear Pickup Range","GEAR_PICKUP_RANGE",0.5,3,30)
addAction(tI,"Collect ALL Items",function() CFG.COLLECT_ALL=true end)

-- 11. MISC
local tM = newTab("Misc", 11)
addToggle(tM,"Chat Spam","SPAM ON","CHAT_SPAM")
addToggle(tM,"Auto Win","WIN ON","AUTO_WIN")
addToggle(tM,"Auto Emote","EMOTE ON","AUTO_EMOTE")
addAction(tM,"Get G666",function() CFG.GET_G666=true end)
addAction(tM,"Server Hop",function() CFG.SERVER_HOP=true end)
addAction(tM,"TP to Exit Gate",function() CFG.TP_TO_EXIT=true end)
addAction(tM,"Save Config",function() CFG.SAVE_CONFIG=true end)
addAction(tM,"Load Config",function() CFG.LOAD_CONFIG=true end)
addAction(tM,"UNLOAD HUB",Unload)

-- 12. SHORTKEYS
local tSH = newTab("Hotkeys", 12)
addShortkey(tSH,"Infinite Stamina","INF_STAMINA")
addShortkey(tSH,"Speed Hack","SPEED_HACK")
addShortkey(tSH,"Noclip","NOCLIP")
addShortkey(tSH,"Kill Aura","KILL_AURA")
addShortkey(tSH,"Killer ESP","KILLER_ESP")
addShortkey(tSH,"Survivor ESP","SURVIVOR_ESP")
addShortkey(tSH,"Aimbot","AIMBOT")
addShortkey(tSH,"Silent Aim","SILENT_AIM")
addShortkey(tSH,"Silent Predict","SILENT_PREDICT")
addShortkey(tSH,"Auto Block","AUTO_BLOCK")
addShortkey(tSH,"M1 TP Dodge","AUTO_BLOCK_TP")
addShortkey(tSH,"Full Bright","FULL_BRIGHT")
addShortkey(tSH,"Auto Gen","AUTO_GEN")
addShortkey(tSH,"Double Backstab","DOUBLE_BACKSTAB")
addShortkey(tSH,"Teleport-Lag","TPLAG_ENABLED")
addShortkey(tSH,"Shield Detect","SHIELD_DETECT")
addShortkey(tSH,"Auto Gash","AUTO_GASH")
addShortkey(tSH,"Auto Sentry","BUILDERMAN_AUTO_SENTRY")
addShortkey(tSH,"Helperbot Extend","HELPERBOT_EXTEND")
addShortkey(tSH,"Remove NPCs","REMOVE_LOBBY_NPCS")
addShortkey(tSH,"Remove Ragdolls","REMOVE_RAGDOLLS")
addShortkey(tSH,"Auto Pick Gears","AUTO_PICK_GEARS")

-- 13. NUMBERS
local tN = newTab("Numbers", 13)
addNumInput(tN,"Loop Throttle (s)","LOOP_THROTTLE",0.01,0.02,0.5)
addNumInput(tN,"Desc Scan Interval","_descScanInterval",0.05,0.1,2)
addNumInput(tN,"Blood Mult","BLOOD_MULT_VALUE",0.5,1,20)
addNumInput(tN,"Push Amount","PUSH_AMOUNT",5,10,500)
addNumInput(tN,"Backstab FOV","BACKSTAB_FOV",5,5,180)
addNumInput(tN,"Chase Speed Mult","CHASE_SPEED_MULT",0.5,1,10)
addNumInput(tN,"Shield Timer (s)","SHIELD_TIMER_SECS",0.5,1,30)
addNumInput(tN,"TPLag Dist","TPLAG_DIST",0.5,1,30)
addNumInput(tN,"Sentry Cooldown","SENTRY_COOLDOWN",1,5,120)
addNumInput(tN,"Bumper Size","VERONICA_BUMPER_SIZE",1,4,20)

-- 14. PREDICT SPEEDS [#31]
local tP = newTab("Predict", 14)
-- Display-only note (no addToggle for this — just num inputs for each speed)
-- Azure / Tentacle
addNumInput(tP,"Azure/Tentacle spd","PREDICT_SPEEDS",5,0,200)
-- These speed buckets live in the table; addNumInput won't work directly on a sub-table.
-- Workaround: expose via CFG aliases so the num widget works.
-- Add CFG aliases:
CFG.SPEED_AZURE  = CFG.PREDICT_SPEEDS["azure"]  or 55
CFG.SPEED_BEAM   = CFG.PREDICT_SPEEDS["beam"]   or 0
CFG.SPEED_NOVA   = CFG.PREDICT_SPEEDS["nova"]   or 40
CFG.SPEED_SIXER  = CFG.PREDICT_SPEEDS["sixer"]  or 35
CFG.SPEED_CORRUPT= CFG.PREDICT_SPEEDS["corrupt"] or 45
CFG.SPEED_DEFAULT= CFG.PREDICT_SPEEDS["default"] or 50

addNumInput(tP,"Azure/Tentacle spd","SPEED_AZURE",5,0,200)
addNumInput(tP,"Beam spd (0=hitscan)","SPEED_BEAM",5,0,200)
addNumInput(tP,"Nova spd","SPEED_NOVA",5,0,200)
addNumInput(tP,"Sixer Scream spd","SPEED_SIXER",5,0,200)
addNumInput(tP,"Corrupt Nature spd","SPEED_CORRUPT",5,0,200)
addNumInput(tP,"Default fallback spd","SPEED_DEFAULT",5,0,200)

-- Sync CFG aliases back to PREDICT_SPEEDS each loop
-- (done inside getActiveKillerAbilitySpeed via the aliases)
-- Patch getActiveKillerAbilitySpeed to read aliases:
local _origGetSpeed = getActiveKillerAbilitySpeed
getActiveKillerAbilitySpeed = function()
    -- Sync from UI aliases back into PREDICT_SPEEDS
    CFG.PREDICT_SPEEDS["azure"]   = CFG.SPEED_AZURE
    CFG.PREDICT_SPEEDS["tentacle"]= CFG.SPEED_AZURE
    CFG.PREDICT_SPEEDS["beam"]    = CFG.SPEED_BEAM
    CFG.PREDICT_SPEEDS["nova"]    = CFG.SPEED_NOVA
    CFG.PREDICT_SPEEDS["sixer"]   = CFG.SPEED_SIXER
    CFG.PREDICT_SPEEDS["corrupt"] = CFG.SPEED_CORRUPT
    CFG.PREDICT_SPEEDS["nature"]  = CFG.SPEED_CORRUPT
    CFG.PREDICT_SPEEDS["default"] = CFG.SPEED_DEFAULT
    return _origGetSpeed()
end

-- Minimise
showTab("Stamina")
local minimised = false
local fullH     = panel.Size.Y.Offset
minBtn.MouseButton1Click:Connect(function()
    minimised  = not minimised
    tabRow.Visible     = not minimised
    contentArea.Visible= not minimised
    if minimised then
        panel.Size = UDim2.new(0,PANEL_W,0,40); minBtn.Text="+"
    else
        panel.Size = UDim2.new(0,PANEL_W,0,fullH); minBtn.Text="-"
    end
end)

-- ┌─────────────────────────────────────────────────────────┐
-- │                   INIT                                   │
-- └─────────────────────────────────────────────────────────┘
applyStamina()
applyNoclip()
setupM1Watch()

print("[ForsakenHub v4.1] loaded — 14 tabs, all v4.1 features active")
