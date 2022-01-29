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

    local vitals = physparam:get_field("_VitalList")
    if not vitals then
        status = "No vital list"
        return
    end

    local vital_items = vitals:get_field("mItems")
    if not vital_items then
        status = "No vital items"
        return
    end

    local num_vitals = #vital_items:get_elements()

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
        hp_entry.parts = {}
    end

    hp_entry.hp = hp
    hp_entry.max_hp = max_hp
end

local typedef = sdk.find_type_definition("snow.enemy.EnemyCharacterBase")
local update_method = typedef:get_method("update")

sdk.hook(update_method, 
    function(args) 
        record_hp(sdk.to_managed_object(args[2]))
    end, 
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
