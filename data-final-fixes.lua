local base_triv_smoke = {
    type = "trivial-smoke",
    name = "", -- placeholder
    animation = {
        filename = "__factorio_after_dark__/graphics/empty_pixel.png",
        width = 1,
        height = 1,
        draw_as_light = true,
        x = 0.0,
        y = 0.0
    },
    duration = 1,
    cyclic = true,
    color = {r=1.0, g=1.0, b=1.0, a=1.0}, -- using as color, defaulting to white
    start_scale = 0.0, -- using for intensity
    end_scale = 0.0, -- using for radius/size
}

-- encode all lights as trivial smoke protos for retrieval at runtime

-- find all light settings
for lamp_name, lamp_proto in pairs(data.raw["lamp"]) do
    local entry = table.deepcopy(base_triv_smoke)
    entry.name = "fad-lamp-" .. lamp_name
    local light = lamp_proto.light ~= nil and lamp_proto.light or (lamp_proto.light_when_colored ~= nil and lamp_proto.light_when_colored or nil)
    if light then
        entry.color = lamp_proto.light.color
        entry.start_scale = lamp_proto.light.intensity
        entry.end_scale = lamp_proto.light.size
        data:extend({entry})
    end
end

-- mod support
-- Searchlight Assault
if mods["SearchlightAssault"] then
    sla_spot_radius_setting = settings.startup["searchlight-assault-setting-light-radius"].value
    local splotlight = table.deepcopy(base_triv_smoke)
    splotlight.name = "fad-lamp-sla-spotlight"
    splotlight.start_scale = 1.0 -- direct spot is full illumination
    splotlight.end_scale = sla_spot_radius_setting
    data:extend({splotlight})
end

-- Deadlock Large Lamps
if mods["DeadlockLargerLamp"] then
    deadlock_burner_lamp_proto = data.raw["assembling-machine"]["deadlock-copper-lamp"]
    local burner_lamp = table.deepcopy(base_triv_smoke)
    burner_lamp.name = "fad-lamp-deadlock-copper-lamp"
    local burner_light = deadlock_burner_lamp_proto.working_visualisations[1].light
    burner_lamp.color = burner_light.color
    burner_lamp.start_scale = burner_light.intensity
    burner_lamp.end_scale = burner_light.size
    data:extend({burner_lamp})
end
