-- 911 Dispatch Simulator | Auto Answer Call + Auto Select + Auto Send Unit
-- Game: [🚨] 911 Dispatch Simulator | PlaceId: 74226442246442
-- Potassium-compatible: loadstring(game:HttpGet("..."))()
-- ============================================================

local Players     = game:GetService("Players")
local RunService  = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local lp          = Players.LocalPlayer
local pg          = lp:WaitForChild("PlayerGui", 10)

-- ── CONFIG ──────────────────────────────────────────────────
local CFG = {
    PRIORITY        = "High",      -- Low | Medium | High | Critical
    SERVICES        = { Police=1, Fire=0, EMS=1 }, -- 1 = add one unit each
    AUTO_FILE       = true,        -- auto click FILE TO CAD
    AUTO_DISPATCH   = true,        -- auto click DISPATCH on map callouts + BestPick
    FILE_DELAY      = 0.35,        -- seconds between button clicks
    DISPATCH_DELAY  = 0.5,
    LOOP_HZ         = 2,           -- checks per second
}
-- ────────────────────────────────────────────────────────────

local function click(btn)
    if not btn then return end
    if not btn:IsA("GuiButton") then return end
    -- fire all MouseButton1Click connections
    local ok, err = pcall(function()
        btn.MouseButton1Click:Fire()
    end)
    if not ok then
        -- fallback: fire via VirtualInputManager if available
        pcall(function()
            local vim = game:GetService("VirtualInputManager")
            local abs = btn.AbsolutePosition
            vim:SendMouseButtonEvent(abs.X + btn.AbsoluteSize.X/2,
                                     abs.Y + btn.AbsoluteSize.Y/2,
                                     0, true, game, 1)
            task.wait(0.05)
            vim:SendMouseButtonEvent(abs.X + btn.AbsoluteSize.X/2,
                                     abs.Y + btn.AbsoluteSize.Y/2,
                                     0, false, game, 1)
        end)
    end
end

local function waitGui(name, timeout)
    timeout = timeout or 10
    local gui = pg:FindFirstChild(name)
    if gui then return gui end
    local t = 0
    while t < timeout do
        task.wait(0.1)
        t = t + 0.1
        gui = pg:FindFirstChild(name)
        if gui then return gui end
    end
    return nil
end

local function findFirst(parent, predicate, maxDepth)
    maxDepth = maxDepth or 8
    local function recurse(inst, depth)
        if depth > maxDepth then return nil end
        if predicate(inst) then return inst end
        for _, c in ipairs(inst:GetChildren()) do
            local r = recurse(c, depth+1)
            if r then return r end
        end
    end
    return recurse(parent, 0)
end

-- ── PART 1: Auto Answer Call (file to CAD) ──────────────────
local function handleCallFiling()
    local gui = pg:FindFirstChild("NineOneOneCallFilingGui")
    if not gui then return end
    local modal = gui:FindFirstChild("CallFilingModal")
    if not modal or not modal.Visible then return end
    local card  = modal:FindFirstChild("CallFilingCard")
    if not card then return end
    local body  = card:FindFirstChild("CardBody")
    if not body then return end

    -- already processing check (use attribute flag)
    if card:GetAttribute("_autoProcessing") then return end
    card:SetAttribute("_autoProcessing", true)

    task.spawn(function()
        -- 1. Select priority
        local pBtn = body:FindFirstChild("TutorialTarget_CallFilingPriority_"..CFG.PRIORITY)
        if pBtn then
            click(pBtn)
            task.wait(CFG.FILE_DELAY)
        end

        -- 2. Add services
        local serviceMap = {
            Police = "TutorialTarget_CallFilingService_Police",
            Fire   = "TutorialTarget_CallFilingService_Fire",
            EMS    = "TutorialTarget_CallFilingService_EMS",
        }
        for svc, count in pairs(CFG.SERVICES) do
            local btn = body:FindFirstChild(serviceMap[svc])
            if btn and count > 0 then
                for _ = 1, count do
                    click(btn)
                    task.wait(CFG.FILE_DELAY * 0.5)
                end
                task.wait(CFG.FILE_DELAY)
            end
        end

        -- 3. Submit
        if CFG.AUTO_FILE then
            local submitBtn = body:FindFirstChild("TutorialTarget_CallFilingSubmit")
            if submitBtn then
                task.wait(CFG.FILE_DELAY)
                click(submitBtn)
            end
        end

        task.wait(1)
        card:SetAttribute("_autoProcessing", false)
    end)
end

-- ── PART 2: Auto Send Unit (dispatch from map callouts) ──────
local _dispatchedIncidents = {}

local function handleDispatch()
    local mainGui = pg:FindFirstChild("NineOneOneGui")
    if not mainGui then return end

    -- find CAD callout layer
    local cadHost = mainGui:FindFirstChildWhichIsA("ScreenGui")
    -- walk to callout layer
    local calloutLayer = nil
    pcall(function()
        calloutLayer = mainGui.Root.Content.Page.Body.DashboardLower
            .DashboardCADMapPanel["NineOneOne_DashboardCADMapHost"]
            .Root.CADPanel.MapFrame.MapContent.CalloutLayer
    end)
    if not calloutLayer then return end

    for _, incident in ipairs(calloutLayer:GetChildren()) do
        if incident.Name:find("IncidentCallout_") then
            local incId = incident.Name
            if _dispatchedIncidents[incId] then continue end

            -- find visible DISPATCH callout button
            local actionBtn = incident:FindFirstChild("CalloutActionButton")
            if actionBtn and actionBtn.Visible and actionBtn.Text == "DISPATCH" then
                _dispatchedIncidents[incId] = true

                task.spawn(function()
                    click(actionBtn)
                    task.wait(CFG.DISPATCH_DELAY)

                    -- after clicking, the DashboardDispatchUnitSelection should populate
                    -- find BestPick and DispatchButton in the main gui
                    local unitSel = nil
                    pcall(function()
                        unitSel = mainGui.Root.Content.Page.Body.DashboardLower
                            .DashboardCADMapPanel.DashboardDispatchUnitSelection
                    end)

                    if not unitSel then return end

                    -- wait for BestPick to appear
                    local bestPick = nil
                    local t = 0
                    while t < 3 do
                        bestPick = findFirst(unitSel, function(v)
                            return v:IsA("TextButton") and
                                (v.Name == "TutorialTarget_BestPick" or
                                 v.Text == "BEST PICK")
                        end)
                        if bestPick then break end
                        task.wait(0.2)
                        t = t + 0.2
                    end

                    if bestPick then
                        click(bestPick)
                        task.wait(CFG.DISPATCH_DELAY)
                    end

                    -- click DISPATCH button
                    local dispBtn = findFirst(unitSel, function(v)
                        return v:IsA("TextButton") and
                            (v.Name == "TutorialTarget_DispatchButton" or
                             v.Text == "DISPATCH")
                    end)
                    if dispBtn then
                        click(dispBtn)
                    end
                end)
            end
        end
    end
end

-- ── PART 3: Wire incoming call BindableEvent ─────────────────
local function wireCallEvent()
    local be = pg:FindFirstChild("NineOneOne_OpenIncidentDispatchRequest")
    if not be then return end
    -- fired when a new call comes in and the filing GUI opens
    be.Event:Connect(function()
        task.wait(0.3) -- let GUI render
        handleCallFiling()
    end)
end

-- ── MAIN LOOP ────────────────────────────────────────────────
wireCallEvent()

-- also poll in case the event already fired before we connected
local _loopConn
_loopConn = RunService.Heartbeat:Connect(function()
    -- throttle to CFG.LOOP_HZ
end)

local _ticker = 0
RunService.Heartbeat:Connect(function(dt)
    _ticker = _ticker + dt
    if _ticker < (1 / CFG.LOOP_HZ) then return end
    _ticker = 0

    -- check if call filing is open but we missed the event
    handleCallFiling()

    -- auto dispatch any pending incidents
    if CFG.AUTO_DISPATCH then
        handleDispatch()
    end
end)

print("[911 Auto] loaded — priority="..CFG.PRIORITY.." auto_file="..tostring(CFG.AUTO_FILE).." auto_dispatch="..tostring(CFG.AUTO_DISPATCH))
