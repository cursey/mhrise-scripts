log.info("[monster_has_hp_bar.lua] loaded")

local cfg = json.load_file("monster_has_hp_bar.json")

if not cfg then
    cfg = {
        font_size = imgui.get_default_font_size() - 2,
        font_name = "Tahoma",
        is_top_bar = true,
    }
end

re.on_config_save(
    function()
        json.dump_file("monster_has_hp_bar.json", cfg)
    end
)

local status = ""
local hp_table = {}

local physical_param_field = sdk.find_type_definition("snow.enemy.EnemyCharacterBase"):get_field("<PhysicalParam>k__BackingField")
local get_vital_method = physical_param_field:get_type():get_method("getVital")
local vital_param_type = get_vital_method:get_return_type()
local get_current_hp_method = vital_param_type:get_method("get_Current")
local get_max_hp_method = vital_param_type:get_method("get_Max")
local enemy_type_field = sdk.find_type_definition("snow.enemy.EnemyCharacterBase"):get_field("<EnemyType>k__BackingField")
local message_manager_type = sdk.find_type_definition("snow.gui.MessageManager")
local get_enemy_message_method = message_manager_type:get_method("getEnemyNameMessage")
local em_boss_character_base_type = sdk.find_type_definition("snow.enemy.EmBossCharacterBase")


local msgman = nil
local tick_count = 0
local last_update_tick = 0
local recorded_monsters = {}
local updated_monsters = {}
local num_known_monsters = 0
local num_updated_monsters = 0
local tick_start = 0

-- run every tick to keep track of monsters
-- whenever we've updated enough monsters to surpass how many we've seen,
-- we reset and start over
-- this allows us to only update one monster per tick to save on performance
re.on_pre_application_entry("UpdateBehavior", function()
    tick_count = tick_count + 1
 
    if num_known_monsters ~= 0 and 
            num_updated_monsters >= num_known_monsters or 
            tick_count >= num_known_monsters * 2 
    then
        recorded_monsters = {}
        updated_monsters = {}
        last_update_tick = 0
        tick_count = 0
        num_known_monsters = 0
        num_updated_monsters = 0
    end
end)

function record_hp(args)
    local enemy = sdk.to_managed_object(args[2])
    if not enemy then return end

    if not recorded_monsters[enemy] then
        num_known_monsters = num_known_monsters + 1
        recorded_monsters[enemy] = true
    end

    -- only updates one monster per tick to increase performance
    if updated_monsters[enemy] or tick_count == last_update_tick then
        return
    end

    last_update_tick = tick_count
    num_updated_monsters = num_updated_monsters + 1
    updated_monsters[enemy] = true

    local physparam = physical_param_field:get_data(enemy)
    if not physparam then 
        status = "No physical param"
        return
    end

    local vitalparam = get_vital_method:call(physparam, 0, 0)
    if not vitalparam then
        status = "No vital param"
        return
    end

    local hp = get_current_hp_method:call(vitalparam)
    local max_hp = get_max_hp_method:call(vitalparam)
    local hp_entry = hp_table[enemy]

    --[[local vitals = physparam:get_field("_VitalList")
    if not vitals then
        status = "No vital list"
        return
    end

    local vital_items = vitals:get_field("mItems")
    if not vital_items then
        status = "No vital items"
        return
    end

    local num_vitals = #vital_items:get_elements()]]

    if not hp_entry then 
        -- Grab enemy name.
        if not msgman then
            status = "No message manager"
            return
        end

        local enemy_type = enemy_type_field:get_data(enemy)
        if not enemy_type then
            status = "No enemy type"
            return
        end

        hp_entry = {} 
        hp_table[enemy] = hp_entry

        local name = get_enemy_message_method:call(msgman, enemy_type)
        hp_entry.name = name
        hp_entry.parts = {}
    end

    hp_entry.hp = hp
    hp_entry.max_hp = max_hp
end

local typedef = sdk.find_type_definition("snow.enemy.EnemyCharacterBase")
local update_method = typedef:get_method("update")

sdk.hook(update_method, 
    record_hp,
    function(retval) end
)

re.on_draw_ui(
    function() 
        if not imgui.collapsing_header("Monster Has HP Bar") then return end

        local changed, value = imgui.input_text("Font Name", cfg.font_name)
        if changed then cfg.font_name = value end

        changed, value = imgui.slider_int("Font Size", cfg.font_size, 1, 100)
        if changed then cfg.font_size = value end

        changed, value = imgui.checkbox("Top Bar", cfg.is_top_bar)
        if changed then cfg.is_top_bar = value end

        if imgui.button("Save settings") then
            json.dump_file("monster_has_hp_bar.json", cfg)
        end

        if string.len(status) > 0 then
            imgui.text("Status: " .. status)
        end
    end
)

local font = nil

d2d.register(
    function()
        font = d2d.create_font(cfg.font_name, cfg.font_size, true)
    end, 
    function()
        msgman = sdk.get_managed_singleton("snow.gui.MessageManager")

        if not msgman then
            status = "No message manager"
            return
        end

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

        local screen_w, screen_h = d2d.surface_size()
        local x = 0
        local y = 0
        local w = screen_w
        local h = 20
        local hp_percent = hp_entry.hp / hp_entry.max_hp
        local hp_w = w * hp_percent 
        local missing_hp_w = w - hp_w 

        local str = hp_entry.name .. "    " .. math.floor(hp_percent * 100) .. "%    " .. math.floor(hp_entry.hp) .. "/" .. math.floor(hp_entry.max_hp)
        local text_w, text_h = d2d.measure_text(font, str)
        h = text_h

        if not cfg.is_top_bar then
            y = screen_h - h
        end

        d2d.fill_rect(x + hp_w, y, missing_hp_w, h, 0xAA000000)
        d2d.fill_rect(x, y, hp_w, h, 0xAA228B22)
        d2d.text(font, str, x, y, 0xFFFFFFFF)

        status = ""
    end
)
