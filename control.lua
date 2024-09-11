-- exponent for determining brightness
local brightnessCurve = 1.6

indiscriminate = {
    physical = false,
    explosion = true,
    fire = true,
    acid = true,
    laser = false,
    electric = true,
    poison = true,
    impact = true
}

-- first number is # of lamps to reach 'full brightness' directly next to lamp
-- second number is # of lamps to reach FB at max lamp range
-- third number is lamp max range
-- numbers taken by measuring in game
lampCurves = {}
lampCurves["fire-flame"] = {1, 10, 5.0}
lampCurves["deadlock-floor-lamp"] = {2.5, 7.0, 25.0}
lampCurves["flashlight"] = {2.0, 6.0, 30.0}
lampCurves["deadlock-copper-lamp"] = {2.0, 5.0, 30.0}
lampCurves["small-lamp"] = {1.0, 4.5, 15.0}
lampCurves["deadlock-large-lamp"] = {1.0, 4.0, 30.0}
lampCurves["searchlight-assault-turtle"] = {1.0, 2.0, 5.0}
lampCurves["default"] = lampCurves["small-lamp"]
lampCurves["touch"] = {2.0, 10.0, 2.0}

function lampIntensityAtDistance(lamp, distance)
    if not lampCurves[lamp] then
        lamp = "default"
    end
    if distance >= lampCurves[lamp][3] then
        return 0.0
    end
    lerpAmount = math.min(1, math.max(0, ((distance-1)/lampCurves[lamp][3])^brightnessCurve))
    denominator = lampCurves[lamp][1] * (1 - lerpAmount) + lampCurves[lamp][2] * lerpAmount
    intensity = 1/denominator
    return intensity
end

function dist(a, b)
    distance = math.sqrt((a.x - b.x)^2 + (a.y - b.y)^2)
    return distance
end

function direction(a, b)
    bearing = {x = b.x - a.x, y = b.y - a.y}
    -- normalize
    distance = dist(a,b)
    bearing.x = bearing.x / distance
    bearing.y = bearing.y / distance
    return bearing
end

function modifyDamage(event)
    -- check if the damage is an indisciminate type (fire, acid, explosive, poison, etc)
    if indiscriminate[event.damage_type.name] then
        return
    end

    -- Nuclear weapons, as well as neutral effects like fire, have no cause so will apply in full.
    -- other than wanting to reduce rocket damage due to difficulty of 'direct hits', this is as intended
    if event.cause then
        -- biters ignore darkness
        if event.cause.force.name == "enemy" then
            return
        end

        -- artillery damage is still split into phys + explosive, but is generally an area affect, and should skip darkness
        if string.find(event.cause.type, "artillery") then
            return
        end
        
        -- TODO: find nightvision if player is in vehicle
        -- check nightvision
        if (event.cause.grid) then
            local nvg = event.cause.grid.find("night-vision-equipment")
            if nvg and nvg.energy > 0 then
                return
            end
        end
    end
    
    -- get current surface darkness
    local darkness = event.entity.surface.darkness

    -- find nearby lights!
    nearby = game.surfaces[event.entity.surface_index].find_entities_filtered{position = event.entity.position, radius = 30, limit = 20, type = "lamp"}
    for _,near in ipairs(nearby) do
        control = near.get_control_behavior()
        if near.energy < near.prototype.energy_usage then
            -- do nothing
        elseif control and control.disabled then
            -- do nothing
        else
            -- subtract 1 from distance as all lights are 1x1 - 2x2 in size (except turtle) and will be at least 0.7 to the corner
            -- this means the edge of the light should be between 0.5-1.4 away from it's center, so 1 is decent compromise
            distance = dist(near.position, event.entity.position) - 1
            lampIntensity = lampIntensityAtDistance(near.name, distance)
            darkness = darkness - lampIntensity
        end
    end

    -- support mods!
    mods = script.active_mods
    -- support burner lamps from Larger Lamps
    if mods["DeadlockLargerLamp"] then
        nearby = game.surfaces[event.entity.surface_index].find_entities_filtered{position = event.entity.position, radius = lampCurves["deadlock-copper-lamp"][3], limit = 20, name = "deadlock-copper-lamp"}
        for _,near in ipairs(nearby) do
            if near.burner and near.burner.remaining_burning_fuel > 0 then
                -- subtract 1 from distance as all lights are 1x1 - 2x2 in size (except turtle) and will be at least 0.7 to the corner
                -- this means the edge of the light should be between 0.5-1.4 away from it's center, so 1 is decent compromise
                distance = dist(near.position, event.entity.position) - 1
                lampIntensity = lampIntensityAtDistance(near.name, distance)
                darkness = darkness - lampIntensity
            end
        end
    end
    
    if mods["SearchlightAssault"] then
        nearby = game.surfaces[event.entity.surface_index].find_entities_filtered{position = event.entity.position, radius = lampCurves["searchlight-assault-turtle"][3], limit = 3, name = "searchlight-assault-turtle"}
        for _,near in ipairs(nearby) do
            -- determine if turtle/searchlight is active, SLA already sets turtle active based on power and state
            if near.active then
                lampIntensity = lampIntensityAtDistance(near.name, dist(near.position, event.entity.position))
                darkness = darkness - lampIntensity
            end
        end
    end

    -- adjust darkness based inaccuracy if target is within arm's reach of target to help realism
    -- i.e: it's hard to miss if the barrel is pressed to their chest
    lampIntensity = lampIntensityAtDistance("touch", dist(event.cause.position, event.entity.position))
    darkness = darkness - lampIntensity

    -- nearby fire should cast SOME light, but it's very dim in game.
    -- let's assume a general uncontrolled plume of flame should at least fully illuminate what it's on, but not cast much useable light very far
    nearby = game.surfaces[event.entity.surface_index].find_entities_filtered{position = event.entity.position, radius = lampCurves["fire-flame"][3], limit = 5, type = "fire"}
    for _,near in ipairs(nearby) do
        lampIntensity = lampIntensityAtDistance(near.name, dist(near.position, event.entity.position))
        darkness = darkness - lampIntensity
    end

    -- Check all flashlights!
    for _, player in pairs(game.players) do
        if player.surface == event.entity.surface and player.is_flashlight_enabled() then
            if dist(player.position, event.entity.position) <= lampCurves["flashlight"][3] then
                cardinal = ""
                bearing = direction(player.position, event.entity.position)
                if bearing.y > 0.4 then
                    cardinal = cardinal .. "south"
                elseif bearing.y < -0.4 then
                    cardinal = cardinal .. "north"
                end
                if bearing.x > 0.4 then
                    cardinal = cardinal .. "east"
                elseif bearing.x < -0.4 then
                    cardinal = cardinal .. "west"
                end
                -- TODO: Tank always points west??
                if defines.direction[cardinal] == player.walking_state.direction then
                    lampIntensity = lampIntensityAtDistance("flashlight", dist(player.position, event.entity.position))
                    darkness = darkness - lampIntensity
                end
            end
        end
    end

    -- TODO: ignoring non-player flashlights/headlight for now, add this in?

    darkness = math.max(0, darkness) -- can be 0 min darkness
    inaccuracy = math.min(1,math.max(0, darkness^brightnessCurve - 0.1))

    -- simulate a miss and remove the damage done if RNG doesn't beat inaccuracy
    if math.random() <= inaccuracy then
        event.entity.health = event.entity.health + event.final_damage_amount
    end
end

script.on_event(defines.events.on_entity_damaged, modifyDamage)
