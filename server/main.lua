local QBCore = exports["qb-core"]:GetCoreObject()
Farms = GlobalState.Farms or {}
local ox_inventory = exports.ox_inventory
Items = ox_inventory:Items()

local SELECT_DATA = "SELECT * FROM mri_qfarm"
local INSERT_DATA = "INSERT INTO mri_qfarm (farmName, farmConfig, farmGroup) VALUES (?, ?, ?)"
local UPDATE_DATA = "UPDATE mri_qfarm SET farmName = ?, farmConfig = ?, farmGroup = ? WHERE farmId = ?"
local DELETE_DATA = "DELETE FROM mri_qfarm WHERE farmId = ?"

local function itemAdd(source, item, amount)
    if (amount > 0) then
        ox_inventory:AddItem(source, item, amount)
    end
end

local function dispatchEvents(source, response)
    GlobalState:set("Farms", Farms, true)
    Wait(2000)
    TriggerClientEvent("mri_Qfarm:client:LoadFarms", -1)
    if response then
        lib.notify(source, response)
    end
end

local function locateFarm(id)
    for k, v in pairs(Farms) do
        if v.farmId == id then
            return k
        end
    end
end

local function cleanNullPoints(config)
    for name, value in pairs(config.items) do
        local newPoints = {}
        for k, v in pairs(value.points) do
            newPoints[#newPoints + 1] = v
        end
        config.items[name].points = newPoints
    end
    return config
end

lib.callback.register(
    "mri_Qfarm:server:UseItem",
    function(source, item)
        local toolItem = exports.ox_inventory:Search(source, "slots", item.collectItem.name)

        if toolItem then
            for k, v in pairs(toolItem) do
                if v.metadata.durability >= item.collectItem.durability then
                    toolItem = v
                    break
                end
            end
        else
            return
        end

        ox_inventory:SetDurability(source, toolItem.slot, toolItem.metadata.durability - item.collectItem.durability)
        return true
    end
)

lib.callback.register(
    "mri_Qfarm:server:GainStress",
    function(source,  item)
        local src = source
        local player = exports.qbx_core:GetPlayer(src)
        if not player.PlayerData.metadata.stress then
            player.PlayerData.metadata.stress = 0
        end
        if item.gainStress.max == 0 then
            return
        end
        local amount = math.random(item.gainStress.min, item.gainStress.max)
        local newStress = player.PlayerData.metadata.stress + amount
        if newStress <= 0 then
            newStress = 0
        elseif newStress > 100 then
            newStress = 100
        end
        player.Functions.SetMetaData("stress", newStress)
        TriggerClientEvent("hud:client:UpdateStress", src, newStress)
        exports.qbx_core:Notify(
            src,
            locale("notify.stress_gain"),
            "inform",
            3000,
            nil,
            nil,
            {"#141517", "#ffffff"},
            "brain",
            "#C53030"
        )
    end
)

lib.callback.register(
    "mri_Qfarm:server:getRewardItem",
    function(source, itemName, farmId)
        local src = source
        local cfg = nil

        for k, v in pairs(Farms) do
            if v.farmId == farmId then
                cfg = v
                break
            end
        end

        local msg = nil
        if not cfg then
            msg = locale("error.farm_not_found", farmId)
            print(msg)
            lib.notify(src, {type = "error", description = msg})
            return
        end

        if (not Items[itemName]) then
            msg = locale("error.item_not_found", itemName)
            print(msg)
            lib.notify(src, {type = "error", description = msg})
            return
        end

        local itemCfg = cfg.config.items[itemName]

        if (not itemCfg) then
            msg = locale("error.item_cfg_not_found", itemName)
            print(msg)
            lib.notify(src, {type = "error", description = msg})
            return
        end

        local qtd = math.random(itemCfg.min or 0, itemCfg.max or 1)
        itemAdd(src, itemName, qtd)
        if (itemCfg["extraItems"]) then
            for name, config in pairs(itemCfg.extraItems) do
                itemAdd(src, name, math.random(config.min, config.max))
            end
        end
        return true
    end
)

lib.callback.register(
    "mri_Qfarm:server:SaveFarm",
    function(source, farm)
        local source = source
        local response = {type = "success", description = locale("actions.saved")}
        if farm.farmId then
            local affectedRows =
                MySQL.Sync.execute(
                UPDATE_DATA,
                {farm.name, json.encode(farm.config), json.encode(farm.group), farm.farmId}
            )
            if affectedRows <= 0 then
                response.type = "error"
                response.description = locale("actions.not_saved")
            end
            Farms[locateFarm(farm.farmId)] = farm
            dispatchEvents(source, response)
        else
            local farmId =
                MySQL.Sync.insert(INSERT_DATA, {farm.name, json.encode(farm.config), json.encode(farm.group)})
            if farmId <= 0 then
                response.type = "error"
                response.description = locale("actions.not_saved")
            else
                farm.farmId = farmId
                Farms[#Farms + 1] = farm
            end
            dispatchEvents(source, response)
        end
        return true
    end
)

lib.callback.register(
    "mri_Qfarm:server:DeleteFarm",
    function(source, farmId)
        local source = source
        local response = {type = "success", description = locale("actions.deleted")}
        if not farmId then
            TriggerClientEvent("ox_lib:notify", source, response)
            return
        end
        local affectedRows = MySQL.Sync.execute(DELETE_DATA, {farmId})
        if affectedRows <= 0 then
            response.type = "error"
            response.description = locale("actions.delete_error", farmId)
        end
        Farms[locateFarm(farmId)] = nil
        dispatchEvents(source, response)
        return true
    end
)

AddEventHandler(
    "onResourceStart",
    function(resource)
        Wait(200)
        if resource == GetCurrentResourceName() then
            local result = MySQL.Sync.fetchAll(SELECT_DATA, {})
            local farms = {}
            if result and #result > 0 then
                for _, row in ipairs(result) do
                    local farm = {
                        farmId = row.farmId,
                        name = row.farmName,
                        config = cleanNullPoints(json.decode(row.farmConfig)),
                        group = json.decode(row.farmGroup)
                    }
                    farms[_] = farm
                end
            end
            Farms = farms
            dispatchEvents(source)
        end
    end
)

if GetResourceState("mri_Qbox") ~= "started" then
    lib.addCommand(
        "managefarms",
        {
            help = locale("creator.description_title"),
            restricted = "group.admin"
        },
        function(source, args, raw)
            lib.callback("mri_Qfarm:manageFarmsMenu", source)
        end
    )
end
