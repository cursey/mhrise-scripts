log.info("[monster_has_hp_bar.lua] loaded")

local status = ""
local hp_table = {}

local sceneman = sdk.get_native_singleton("via.SceneManager")
if not sceneman then 
    log.error("[monster_has_hp_bar.lua] No scene manager")
    return
end

local sceneview = sdk.call_native_func(sceneman, sdk.find_type_definition("via.SceneManager"), "get_MainView")
if not sceneview then
    log.error("[monster_has_hp_bar.lua] No main view")
    return
end

local size = sceneview:call("get_Size")
if not size then
    log.error("[monster_has_hp_bar.lua] No sceneview size")
    return
end

local screen_w = size:get_field("w")
if not screen_w then
    log.error("[monster_has_hp_bar.lua] No screen width")
    return
end

function record_hp(enemy)
    if not enemy then return end

    local physparam = enemy:get_field("<PhysicalParam>k__BackingField")
    if not physparam then 
        status = "No physical param"
        return
    end

    local vitalparam = physparam:call("getVital", 0, 0)
    if not vitalparam then
        status = "No vital param"
        return
    end

    local hp = vitalparam:call("get_Current")
    local max_hp = vitalparam:call("get_Max")
    local hp_entry = hp_table[enemy]

    if not hp_entry then 
        hp_entry = {} 
        hp_table[enemy] = hp_entry

        -- Grab enemy name.
        local msgman = sdk.get_managed_singleton("snow.gui.MessageManager")
        if not msgman then
            status = "No message manager"
            return
        end

        local enemy_type = enemy:get_field("<EnemyType>k__BackingField")
        if not enemy_type then
            status = "No enemy type"
            return
        end

        local name = msgman:call("getEnemyNameMessage", enemy_type)
        hp_entry.name = name
    end

    hp_entry.hp = hp
    hp_entry.max_hp = max_hp
end

local typedef = sdk.find_type_definition("snow.enemy.EnemyCharacterBase")
local update_method = typedef:get_method("update")

sdk.hook(update_method, function(args) 
    record_hp(sdk.to_managed_object(args[2]))
end, function(retval) end)

re.on_draw_ui(function() 
    if string.len(status) > 0 then
        imgui.text("[monster_has_hp_bar.lua] Status: " .. status)
    end
end)

re.on_frame(function()
    local playman = sdk.get_managed_singleton("snow.player.PlayerManager")
    if not playman then 
        status = "No player manager"
        return
    end

    local me = playman:call("findMasterPlayer")
    if not me then 
        status = "No local player"
        return
    end

    local gameobj = me:call("get_GameObject")
    if not gameobj then
        status = "No local player game object"
        return
    end

    local transform = gameobj:call("get_Transform")
    if not transform then
        status = "No local player transform"
        return
    end

    local me_pos = transform:call("get_Position")
    if not me_pos then 
        status = "No local player position"
        return
    end

    local enemyman = sdk.get_managed_singleton("snow.enemy.EnemyManager")
    if not enemyman then 
        status = "No enemy manager"
        return 
    end

    local closest_enemy = nil
    local closest_dist = 999999

    for i = 0, 4 do
        local enemy = enemyman:call("getBossEnemy", i)
        if not enemy then 
            break
        end

        local hp_entry = hp_table[enemy]
        if not hp_entry then 
            status = "No hp entry"
            break 
        end

        local gameobj = enemy:call("get_GameObject")
        if not gameobj then
            status = "No game object"
            break
        end

        local transform = gameobj:call("get_Transform")
        if not transform then
            status = "No transform"
            break 
        end

        local enemy_pos = transform:call("get_Position")
        if not enemy_pos then 
            status = "No position"
            break 
        end

        local distance = (me_pos - enemy_pos):length()

        if distance < closest_dist then
            closest_dist = distance
            closest_enemy = enemy
        end
    end

    if not closest_enemy then
        hp_table = {}
        status = "No enemy"
        return
    end

    local hp_entry = hp_table[closest_enemy]
    if not hp_entry then 
        status = "No hp entry"
        return
    end

    local x = 0
    local y = 0
    local w = screen_w
    local h = 20
    local hp_percent = hp_entry.hp / hp_entry.max_hp
    local hp_w = w * hp_percent 
    local missing_hp_w = w - hp_w 

    draw.filled_rect(x + hp_w, y, missing_hp_w, h, 0xAA000000)
    draw.filled_rect(x, y, hp_w, h, 0xAA228B22)
    draw.text(hp_entry.name .. "\t" .. math.floor(hp_percent * 100) .. "%\t" .. hp_entry.hp .. "/" .. hp_entry.max_hp, x + 5, y + 2, 0xFFFFFFFF)
    status = ""
end)
