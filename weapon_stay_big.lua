log.info("[weapon_stay_big.lua] loaded")

local typedef = sdk.find_type_definition("snow.player.PlayerWeaponCtrl")
local start_method = typedef:get_method("start")

sdk.hook(start_method, function(args)
    local weapctrl = sdk.to_managed_object(args[2])
    weapctrl:set_field("_bodyConstScale", 1.0)
end, function(retval) end)