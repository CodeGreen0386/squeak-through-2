local const = require("const") --[[@as Squeakthrough.const]]
local cmu = require("collision-mask-util")

local character_box = data.raw.character.character.collision_box --[[@as data.BoundingBox]]
character_box[1][1] = character_box[1][1] + 1/256
character_box[1][2] = character_box[1][2] + 1/256
character_box[2][1] = character_box[2][1] - 1/256
character_box[2][2] = character_box[2][2] - 1/256

---@type table<string, boolean>
local disabled_types = {}
for group, ptypes in pairs(const.groups) do
    for _, ptype in pairs(ptypes) do
        disabled_types[ptype] = settings.startup["sqt-disable-modify-" .. group].value --[[@as boolean]]
    end
end

---@return table<string, true>
local function parse_csv(setting)
    ---@cast setting string
    local values = {}
    for value in setting:gmatch("([^,]+)") do
        values[value:match("^%s*(.-)%s*$")] = true
    end
    return values
end

local blacklist_types = parse_csv(settings.startup["sqt-blacklist-types"].value)
local blacklist_names = parse_csv(settings.startup["sqt-blacklist-names"].value)

local remove_collision = settings.startup["sqt-remove-collision"].value
local remove_types = parse_csv(settings.startup["sqt-remove-collision-types"].value)
local remove_names = parse_csv(settings.startup["sqt-remove-collision-names"].value)

---@param prototype data.EntityPrototype
local function remove_player_collision(prototype)
    prototype.collision_mask = cmu.get_mask(prototype)
    cmu.remove_layer(prototype.collision_mask, "player-layer")
end

---@param n number
---@param override number?
local function trim(n, override)
    local max_trim = override or 0.3
    local sign = n >= 0 and 1 or -1
    n = n * sign
    local base = math.floor(n * 2) / 2
    local decimal = math.fmod(n, 0.5)
    local new_decimal = math.min(max_trim, decimal)
    return (base + new_decimal) * sign
end

local prototypes = cmu.collect_prototypes_colliding_with_mask(cmu.get_mask(data.raw.character.character))
---@cast prototypes data.EntityPrototype[]
for _, prototype in pairs(prototypes) do

    if remove_collision and remove_names[prototype.name] then
        remove_player_collision(prototype)
        goto continue
    end
    if blacklist_names[prototype.name] then goto continue end

    if remove_collision and remove_types[prototype.type] then
        remove_player_collision(prototype)
        goto continue
    end
    if blacklist_types[prototype.type] then goto continue end

    ---@diagnostic disable-next-line: undefined-field
    if prototype.sqeak_behaviour == false then goto continue end

    local is_disabled = disabled_types[prototype.type]
    if is_disabled ~= false then goto continue end

    local collision_box = prototype.collision_box
    if not collision_box then goto continue end

    local flags = prototype.flags
    if flags and prototype.type ~= "tree" then
        for _, flag in pairs(flags) do
            if flag == "placeable-off-grid" then goto continue end
        end
    end

    local lt, rb = collision_box[1], collision_box[2]
    local values = {
        ltx = lt.x or lt[1],
        lty = lt.y or lt[2],
        rbx = rb.x or rb[1],
        rby = rb.y or rb[2]
    }

    local override = const.overrides[prototype.type]
    local modified = false
    for name, value in pairs(values) do
        local new_value = trim(value, override)
        if new_value ~= value then
            values[name] = new_value
            modified = true
        end
    end

    if modified then
        prototype.map_generator_bounding_box = collision_box
        prototype.collision_box = {{values.ltx, values.lty}, {values.rbx, values.rby}}
    end

    ::continue::
end

require("compatibility")