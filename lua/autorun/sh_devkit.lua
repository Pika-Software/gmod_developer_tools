if (SERVER) then
    return
end

local addon_name = "Developer Tool Kit"
local vector_zero = Vector( 0, 0, 0 )
module( "dev_tools", package.seeall )

local oldhooks = dev_tools and dev_tools.GetHooks() or nil
local hooks = oldhooks or {}
function Hook( event, func )
    if (hooks[ event ] == nil) then
        hooks[ event ] = {}
    end

    local hook_name = addon_name .. " - " .. event .. "#" .. #hooks[ event ]
    table.insert( hooks[ event ], hook_name )
    hook.Add( event, hook_name, func )
end

function GetHooks()
    return hooks
end

function ClearHooks()
    for event, data in pairs( hooks ) do
        for num, name in ipairs( data ) do
            hook.Remove( event, name )
        end
    end

    hooks = {}
end

local round = math.Round
local light_grey = Color( 255, 255, 255 )

function ConsoleLine( key, value, color )
    MsgC( HSVToColor( math.random( 360 ) % 360, 0.6, 1 ), key, ": ", color or light_grey, value, "\n" )
end

function FormatVector( vec )
    if istable( vec ) then
        return "Color( " .. vec.r .. ", " .. vec.g .. ", " .. vec.b .. ", " .. (vec.a or 255) .. " )", vec
    end

    if isvector( vec ) then
        return "Vector( " .. round(vec[1], 2) .. ", " .. round(vec[2], 2) .. ", " .. round(vec[3], 2) .. " )"
    end

    if isangle( vec ) then
        return "Angle( " .. round(vec[1], 2) .. ", " .. round(vec[2], 2) .. ", " .. round(vec[3], 2) .. " )"
    end
end

function NotNil( var, func, ... )
    if (var == nil) then return end
    func( ... )
end

local new_axis = CreateClientConVar( "dev_axis_entity", "0", true, false, " - Enables new objet axis.", 0, 1 ):GetBool()
cvars.AddChangeCallback("dev_axis_entity", function( name, old, new ) new_axis = new == "1" end, addon_name)

local axis_helper = dev_tools and dev_tools.GetAxis and dev_tools.GetAxis() or nil
function GetAxis()
    return axis_helper
end

function CreateAxis()
    if IsValid( axis_helper ) then
        axis_helper:Remove()
    end

    axis_helper = ClientsideModel( "models/editor/axis_helper.mdl" )
    axis_helper:SetRenderMode( RENDERMODE_WORLDGLOW )
    axis_helper:SetNoDraw( true )
    return axis_helper
end

function Start()
    ClearHooks()

    local ply = LocalPlayer()
    if IsValid( ply ) then

        surface.CreateFont("DevKit_Font", {
            font = "Arial",
            extended = true,
            size = ScreenScale( 6 ),
        })

        if new_axis and not IsValid( CreateAxis() ) then return end

        local pos = nil
        local ang = nil
        local all_data = {}

        -- local mins, maxs = nil, nil
        local cmins, cmaxs = nil, nil
        local forward, left, up = nil, nil, nil
        local center = nil
        local color = nil

        local axis_len = ScreenScale( CreateClientConVar( "dev_axis_len", "3", true, false, " - Original axis length.", 0, 25 ):GetInt() )
        cvars.AddChangeCallback("dev_axis_len", function( name, old, new ) axis_len =  ScreenScale( tonumber( new ) or 3 ) end, addon_name)

        local alt_pressed = false
        Hook("PlayerButtonDown", function( ply, key )
            if (alt_pressed) then
                if (key == KEY_R) then
                    ply:ConCommand( "retry" )
                end
            else
                if (key == KEY_LALT) then
                    alt_pressed = true
                end
            end
        end)

        Hook("PlayerButtonUp", function( ply, key )
            if (alt_pressed) and (key == KEY_LALT) then
                alt_pressed = false
            end
        end)

        Hook( "Think", function()
            table.Empty( all_data )

            local ent = ply:GetEyeTrace().Entity
            if (ent ~= nil) then
                if ent.GetPos == nil then
                    pos = nil
                else
                    pos = ent:GetPos()
                    table.insert( all_data, { "Position", FormatVector( pos ) } )
                end

                if ent.GetAngles == nil then
                    ang = nil
                else
                    ang = ent:GetAngles()
                    table.insert( all_data, { "Angles", FormatVector( ang ) } )
                end

                if ent.GetColor == nil then
                    color = nil
                else
                    color = ent:GetColor()
                end

                if ent.GetCollisionBounds == nil then
                    cmins, cmaxs = nil, nil
                else
                    cmins, cmaxs = ent:GetCollisionBounds()
                end

                if ent.OBBCenter == nil then
                   center = nil
                else
                    center = ent:OBBCenter()
                    if center == nil then
                        center = vector_zero
                    end

                    center:Rotate( ang )
                    if ent.LocalToWorld == nil then
                        center = center + pos
                    else
                        center = ent:LocalToWorld( center )
                    end

                    if new_axis then
                        if IsValid( axis_helper ) then
                            axis_helper:SetPos( center )
                            axis_helper:SetAngles( ang )
                        else
                            CreateAxis()
                        end
                    elseif IsValid( new_axis ) then
                        new_axis:Remove()
                    end
                end

                if (new_axis) and (ang == nil) or (center == nil) then
                    forward = nil
                    left = nil
                    up = nil
                else
                    forward = center + axis_len * ang:Forward()
                    left = center + axis_len * -ang:Right()
                    up = center + axis_len * ang:Up()
                end
            end
        end )

        local red = Color( 255, 0, 0 )
        local green = Color( 0, 255, 0 )
        local blue = Color( 0, 0, 255 )
        local mat = Material( "editor/wireframe" )

        Hook( "HUDPaint", function()
            local counter = 0
            for num, data in ipairs( all_data ) do
                counter = counter + 1

                local text = data[1] .. ": " .. data[2]
                surface.SetFont( "DevKit_Font" )
                local tw, th = surface.GetTextSize( text )

                surface.DrawRect( 10, 10 + counter * th, tw, th )
                draw.DrawText( text, "DevKit_Font", 10, 10 + counter * th, color_white, TEXT_ALIGN_LEFT )

            end

            if (pos == nil) or (ang == nil) then return end
            cam.Start3D()
                if (cmins ~= nil) and (cmaxs ~= nil) then
                    render.DrawWireframeBox( pos, ang, cmins, cmaxs, color, true )
                end

                if (new_axis) then
                    if IsValid( axis_helper ) then
                        cam.IgnoreZ( true )
                            axis_helper:DrawModel()
                        cam.IgnoreZ( false )
                    end
                else
                    NotNil( forward, render.DrawLine, center, forward, red, false )
                    NotNil( left, render.DrawLine, center, left, green, false )
                    NotNil( up, render.DrawLine, center, up, blue, false )
                end

            cam.End3D()

        end )

    end

end

function Stop()
    ClearHooks()
end

hook.Add("RenderScene", addon_name, function()
    hook.Remove("RenderScene", addon_name)
    if CreateConVar( "dev_tools", "0", FCVAR_ARCHIVE, "", 0, 1 ):GetBool() then Start() else Stop() end
    cvars.AddChangeCallback( "dev_tools", function( name, old, new ) if tobool( new ) then Start() else Stop() end end)
end)

concommand.Add("dev_entity", function( ply )
    local ent = ply:GetEyeTrace().Entity
    MsgN( "<---------------------------------" )
    ConsoleLine( "Index", ent:EntIndex() )

    local class = ent:GetClass()
    ConsoleLine( "Class", class )
    ConsoleLine( "Model", ent:GetModel() )
    ConsoleLine( "Position", FormatVector( ent:GetPos() ) )
    ConsoleLine( "Angles", FormatVector( ent:GetAngles() ) )
    ConsoleLine( "Color", FormatVector( ent:GetColor() ) )
    MsgN()

    ConsoleLine( "Language", ent:IsScripted() and "gLua" or "C++" )
    MsgN()

    ConsoleLine( "Valid", ent:IsValid() )
    ConsoleLine( "NoDraw", ent:GetNoDraw() )
    ConsoleLine( "Ragdoll", ent:IsRagdoll() )

    local isVehicle = ent:IsVehicle()
    ConsoleLine( "Vehicle", isVehicle )

    local isNPC = ent:IsNPC()
    ConsoleLine( "NPC", isNPC )

    if isVehicle then
        local vehicle_class = ent:GetVehicleClass()
        ConsoleLine( "\nVehicle Class", vehicle_class )

        local data = list.Get( "Vehicles" )[ vehicle_class ]
        ConsoleLine( "Vehicle Model", data.Model )
        ConsoleLine( "Name", language.GetPhrase( data.Name ) )
        ConsoleLine( "Information", language.GetPhrase( data.Information ) )
        ConsoleLine( "Author", data.Author )
    elseif isNPC then
        local data = list.Get( "NPC" )[ class ]
        ConsoleLine( "\nName", language.GetPhrase( data.Name ) )

        local wep = ent:GetActiveWeapon()
        if IsValid( wep ) then
            ConsoleLine( "Weapon", language.GetPhrase( wep:GetPrintName() or wep.PrintName or "Scripted Weapon" ) )
        else
            ConsoleLine( "Weapon", "false" )
        end
    elseif ent:IsWeapon() then
        ConsoleLine( "\nPrintName", language.GetPhrase( ent:GetPrintName() or ent.PrintName ) )
        ConsoleLine( "HoldType", ent:GetHoldType() )
        ConsoleLine( "Clip1", ent:Clip1() .. "/" .. ent:GetMaxClip1() .. " - " .. language.GetPhrase( game.GetAmmoName( ent:GetPrimaryAmmoType() ) or "none" ) )
        ConsoleLine( "Clip2", ent:Clip2() .. "/" .. ent:GetMaxClip2() .. " - " .. language.GetPhrase( game.GetAmmoName( ent:GetSecondaryAmmoType() ) or "none" ) )
        ConsoleLine( "SlotPos", ent:GetSlotPos() )
        ConsoleLine( "Slot", ent:GetSlot() )
    elseif (ent.PrintName ~= nil) then
        ConsoleLine( "\nPrintName", language.GetPhrase( ent.PrintName ) )
    end

    if (ent.GetFlexNum ~= nil) then
        local count = ent:GetFlexNum()
        if (count > 0) then
            local flexes = "{\n"
            for id = 0, count do
                flexes = flexes .. "\t[" .. id .. '] = "' .. language.GetPhrase( ent:GetFlexName( id ) or "" ) .. '",\n'
            end

            ConsoleLine( "\nFlexes", flexes .. "}" )
        end
    end

    if (ent.GetBodyGroups ~= nil) then
        local tbl = ent:GetBodyGroups()
        if (#tbl > 0) then
            local bodygroups = "{\n"
            for num, data in ipairs( tbl ) do
                bodygroups = bodygroups .. '\t["' .. data.name .. '"] = {\n\t\t["ID"] = ' .. data.id .. ',\n\t\t["Amount subgroups"] = ' .. data.num .. ",\n\t},\n"
            end

            ConsoleLine( "\nBodygroups", bodygroups .. "}" )
        end
    end

    MsgN( "--------------------------------->" )
end)