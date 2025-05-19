local MINIMAP_SIZE = 256 -- Taille en pixels de la minimap
local CAMERA_HEIGHT = 1000 -- Hauteur de la caméra au-dessus du joueur
local MINIMAP_SCALE = 0.5 -- Échelle de la carte (plus petit = vue plus large)
local MINIMAP_POSITION = {x = 20, y = 20} -- Position sur l'écran
local MAX_TRACE_DISTANCE = 1000

local SMOOTHING = 0.01

local DEBUG = false

function CalculateCeilingHeight(ply)
    if !IsValid(ply) then return 0 end
    
    local startPos = ply:EyePos()
    
    local traceData = {
        start = startPos,
        endpos = startPos + Vector(0, 0, MAX_TRACE_DISTANCE),
        filter = ply
    }
    
    local trace = util.TraceLine(traceData)
    
    if trace.Hit then
        local ceilingHeight = trace.HitPos:Distance(startPos)
        lastCeilingHeight = ceilingHeight
        return ceilingHeight
    else
        lastCeilingHeight = MAX_TRACE_DISTANCE
        return MAX_TRACE_DISTANCE
    end
end

function AdjustCameraHeight(ply)
    local ceilingHeight = CalculateCeilingHeight(ply)
    
    local idealHeight = math.min(ceilingHeight * 2, MAX_TRACE_DISTANCE)
    idealHeight = math.max(idealHeight, 150)
    
    CAMERA_HEIGHT = CAMERA_HEIGHT * 0.9 + idealHeight * 0.1
    
    return ceilingHeight
end

local minimapRT = nil
local minimapMat = nil
local lastCeilingHeight = 0

hook.Add("Initialize", "MinimapInit", function()
    minimapRT = GetRenderTarget("MinimapRT", MINIMAP_SIZE, MINIMAP_SIZE, false)
    minimapMat = CreateMaterial("MinimapMaterial", "UnlitGeneric", {
        ["$basetexture"] = minimapRT:GetName(),
        ["$translucent"] = 1,
        ["$vertexalpha"] = 1,
        ["$vertexcolor"] = 1
    })
end)

local function DrawMinimapView(ply)
    if !IsValid(ply) then return end
    
    if CAMERA_HEIGHT < lastCeilingHeight then
        CAMERA_HEIGHT = CAMERA_HEIGHT + SMOOTHING
    end

    local camPos = ply:GetPos() + Vector(0, 0, CAMERA_HEIGHT)
    local camAngle = Angle(90, ply:EyeAngles().y, 0)
    
    render.PushRenderTarget(minimapRT)
    render.Clear(0, 0, 0, 0)
    
    local oldRT = render.GetRenderTarget()
    
    render.RenderView({
        origin = camPos,
        angles = camAngle,
        x = 0, y = 0,
        w = MINIMAP_SIZE, h = MINIMAP_SIZE,
        fov = 50 / MINIMAP_SCALE,
        drawviewmodel = false,
        drawhud = false,
        drawmonitors = false,
        drawentities = true
    })
    
    cam.Start2D()
        surface.SetDrawColor(255, 0, 0, 255)
        surface.DrawRect(MINIMAP_SIZE/2 - 3, MINIMAP_SIZE/2 - 3, 6, 6)
    cam.End2D()
    
    render.PopRenderTarget()
end

hook.Add("RenderScene", "UpdateMinimap", function()
    local ply = LocalPlayer()
    if IsValid(ply) then
        AdjustCameraHeight(ply)
        DrawMinimapView(ply)
    end
end)

hook.Add("HUDPaint", "DrawMinimap", function()
    if !minimapMat then return end
    
    surface.SetDrawColor(0, 0, 0, 200)
    surface.DrawRect(MINIMAP_POSITION.x - 5, MINIMAP_POSITION.y - 5, MINIMAP_SIZE + 10, MINIMAP_SIZE + 10)
    
    surface.SetDrawColor(255, 255, 255, 255)
    surface.SetMaterial(minimapMat)
    surface.DrawTexturedRect(MINIMAP_POSITION.x, MINIMAP_POSITION.y, MINIMAP_SIZE, MINIMAP_SIZE)
    
    surface.SetDrawColor(255, 255, 255, 100)
    surface.DrawOutlinedRect(MINIMAP_POSITION.x, MINIMAP_POSITION.y, MINIMAP_SIZE, MINIMAP_SIZE)
    
    if DEBUG then
        draw.SimpleText("Hauteur plafond: " .. math.Round(lastCeilingHeight) .. " unités", "DermaDefault", 
            MINIMAP_POSITION.x + 5, MINIMAP_POSITION.y + MINIMAP_SIZE + 5, Color(255, 255, 255, 255))
    
        draw.SimpleText("Hauteur caméra: " .. math.Round(CAMERA_HEIGHT) .. " unités", "DermaDefault", 
            MINIMAP_POSITION.x + 5, MINIMAP_POSITION.y + MINIMAP_SIZE + 20, Color(200, 200, 255, 255))
    end
end)

hook.Add("OnGamemodeLoaded", "MinimapGamemodeConfig", function()
    hook.Add("HUDShouldDraw", "MinimapHideInMenus", function(name)
        if name == "CHudGMod" and (gui.IsGameUIVisible() or gui.IsConsoleVisible()) then
            return false
        end
    end)
end)