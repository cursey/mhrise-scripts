log.info("[weapon_stay_big.lua] loaded")

local identity3f = Vector3f.new(1, 1, 1)

re.on_application_entry("PrepareRendering", function()
    local playman = sdk.get_managed_singleton("snow.player.PlayerManager")
    if not playman then return end
    local me = playman:call("findMasterPlayer")
    if not me then return end

    -- Scale the main weapon back to 100%
    local weapon = me:get_field("_WeaponMain")
    if not weapon then return end
    local transform = weapon:call("get_Transform")
    if not transform then return end
    transform:call("set_LocalScale", identity3f)

    -- Scale the sub weapon (LS scabbard for instance) back to 100%
    weapon = me:get_field("_WeaponSub")
    if not weapon then return end
    transform = weapon:call("get_Transform")
    if not transform then return end
    transform:call("set_LocalScale", identity3f)
end)
