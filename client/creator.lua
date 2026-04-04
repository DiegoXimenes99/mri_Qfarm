local Utils = lib.require("client/utils")
local cache = _G.cache or { ped = PlayerPedId() }
local isCreatorOpen = false
local currentEditingFarm = nil
local currentEditingItem = nil
local newFarm = {
    name = nil,
    config = {
        start = {
            location = nil,
            width = nil,
            length = nil
        },
        items = {}
    },
    group = {
        name = nil,
        grade = 0
    }
}

local newItem = {
    min = nil,
    max = nil,
    randomRoute = false,
    unlimited = false,
    points = {},
    animation = Utils.GetDefaultAnim(Config.UseEmoteMenu),
    collectTime = DefaultCollectTime,
    collectItem = {
        name = nil,
        durability = 0
    },
    collectVehicle = nil
}

local function ifThen(condition, ifTrue, ifFalse)
    if condition then
        return ifTrue
    end
    return ifFalse
end

local function delete(caption, tableObj, key)
    if Utils.ConfirmationDialog(caption) == "confirm" then
        if type(key) == "number" then
            table.remove(tableObj, key)
        else
            tableObj[key] = nil
        end
        return true
    end
end

local function deleteFarm(args)
    local farm = Farms[args.farmKey]
    local result =
        delete(
        locale("actions.confirmation_description", locale("actions.farm"), Farms[args.farmKey].name),
        Farms,
        args.farmKey
    )
    if result then
        lib.callback.await("mri_Qfarm:server:DeleteFarm", false, farm.farmId)
        args.callback()
    else
        args.callbackCancel(args.farmKey)
    end
end

local function deleteItem(args)
    local itemLabel = args.itemKey
    if Items[args.itemKey] then
        itemLabel = Items[args.itemKey].label
    end
    local result =
        delete(
        locale("actions.confirmation_description", locale("actions.item"), itemLabel),
        Farms[args.farmKey].config.items,
        args.itemKey
    )
    if result then
        args.callback(
            {
                farmKey = args.farmKey
            }
        )
    else
        args.callbackCancel(
            {
                farmKey = args.farmKey,
                itemKey = args.itemKey
            }
        )
    end
end

local creatorCheckpoints = {}

local function clearCreatorCheckpoints()
    for _, cp in pairs(creatorCheckpoints) do
        DeleteCheckpoint(cp or -1)
    end
    creatorCheckpoints = {}
end

local function refreshCreatorCheckpoints()
    clearCreatorCheckpoints()
    if not isCreatorOpen or not currentEditingFarm or not currentEditingItem then return end
    
    local farmKey = tonumber(currentEditingFarm)
    local farm = Farms[farmKey]
    if not farm or not farm.config.items[currentEditingItem] then return end
    
    local points = Utils.EnsureSequence(farm.config.items[currentEditingItem].points)
    if #points <= 0 then return end
    
    for i = 1, #points do
        local p = points[i]
        if type(p) == "table" and p.x and p.y and p.z then
            -- Create a static cylinder checkpoint (type 42) 
            local cp = CreateCheckpoint(42, p.x, p.y, p.z, p.x, p.y, p.z, 0.8, 0, 155, 255, 150, 0)
            SetCheckpointCylinderHeight(cp, 2.0, 2.0, 1.0)
            creatorCheckpoints[#creatorCheckpoints + 1] = cp
        end
    end
end

local function deletePoint(args)
    local result =
        delete(
        locale("actions.confirmation_description", locale("actions.point"), args.name),
        Farms[args.farmKey].config.items[args.itemKey].points,
        args.pointKey
    )
    if result then
        lib.callback.await("mri_Qfarm:server:SaveFarm", false, Farms[args.farmKey])
        args.callback(args.farmKey, "points", args.itemKey)
    end
end

local function deleteExtraItem(args)
    local result =
        delete(
        locale("actions.confirmation_description", locale("actions.extra_item"), Items[args.extraItemKey].label),
        Farms[args.farmKey].config.items[args.itemKey].extraItems,
        args.extraItemKey
    )
    args.callback(
        {
            farmKey = args.farmKey,
            itemKey = args.itemKey
        }
    )
end

local function exportFarm(args)
    lib.setClipboard(
        json.encode(
            Farms[args.farmKey],
            {
                indent = true
            }
        )
    )
    lib.notify(
        {
            type = "success",
            description = locale("misc.exported")
        }
    )
    args.callback(args.farmKey)
end

local function changeFarmLocation(args)
    local location = nil
    local result = Utils.GetPedCoords()
    if result.result == "choose" then
        location = result.coords
    end
    if location then
        Farms[args.farmKey].config.start = {
            location = location,
            width = Config.FarmBoxWidth,
            length = Config.FarmBoxLength
        }
        lib.notify(
            {
                type = "success",
                description = locale("notify.updated")
            }
        )
    end
    args.callback(args.farmKey)
end

local function changePointLocation(args)
    local location = nil
    local result = Utils.GetPedCoords()
    if result.result == "choose" then
        location = result.coords
    end
    if location then
        Farms[args.farmKey].config.items[args.itemKey].points[args.pointKey] = location
        lib.callback.await("mri_Qfarm:server:SaveFarm", false, Farms[args.farmKey])
        lib.notify(
            {
                type = "success",
                description = locale("notify.updated")
            }
        )
    end
    args.callback(args.farmKey, "points", args.itemKey)
end

local function setFarmName(args)
    local key = nil
    if args and args.farmKey then
        key = args.farmKey
    end
    local farm = {}
    if key then
        farm = Farms[key]
    else
        table.clone(newFarm, farm)
    end
    local input =
        lib.inputDialog(
        title,
        {
            {
                type = "input",
                label = locale("creator.name"),
                description = locale("creator.description_name"),
                placeholder = locale("creator.placeholder_name"),
                default = farm.name,
                required = true
            }
        }
    )
    if input then
        farm.name = input[1]
        if not key then
            key = #Farms + 1
            Farms[key] = farm
        end
        Farms[key] = farm
    end
    args.callback(key)
end

local function setFarmGroup(args)
    local key = args.farmKey
    local farm = Farms[key]
    local input =
        lib.inputDialog(
        title,
        {
            {
                type = "multi-select",
                label = locale("creator.groups"),
                description = string.sub(locale("creator.description_group"), 1, -4),
                options = Utils.GetBaseGroups(),
                default = farm.group["name"],
                required = false,
                searchable = true
            }
        }
    )
    if input then
        farm.group["name"] = input[1]
        Farms[key] = farm
    end
    args.callback(key)
end

local function teleportToFarm(args)
    Utils.TpToLoc(Farms[args.farmKey].config.start.location)
    args.callback(args.farmKey)
end

local function teleportToPoint(args)
    Utils.TpToLoc(Farms[args.farmKey].config.items[args.itemKey].points[args.pointKey])
    args.callback(
        {
            farmKey = args.farmKey,
            itemKey = args.itemKey,
            pointKey = args.pointKey
        }
    )
end

local function setFarmGrade(args)
    local key = args.farmKey
    local farm = Farms[key]
    local input =
        lib.inputDialog(
        title,
        {
            {
                type = "number",
                label = locale("creator.grade"),
                description = locale("creator.description_grade"),
                default = farm.group["grade"] or 0,
                required = true,
                searchable = true,
                min = 0
            }
        }
    )
    if input then
        farm.group["grade"] = tostring(input[1])
        Farms[key] = farm
    end
    args.callback(key)
end

local function selItemInput(args, extra)
    return lib.inputDialog(
        locale("actions.item.select"),
        {
            {
                type = "select",
                label = locale("items.name"),
                description = locale("items.description_name"),
                default = (extra and (args["extraItemKey"] or "")) or args["itemKey"],
                options = Utils.GetBaseItems(),
                required = true,
                searchable = true,
                clearable = true
            }
        }
    )
end

local function setItem(args)
    local farm = Farms[args.farmKey]
    local input = selItemInput(args)
    if input then
        if input[1] ~= args.itemKey then
            local temp = {}
            table.clone(farm.config.items[args.itemKey] or newItem, temp)
            if farm.config.items[args.itemKey] then
                farm.config.items[args.itemKey] = nil
            end
            farm.config.items[input[1]] = temp
            Farms[args.farmKey] = farm
        end
    end
    args.callback(
        {
            farmKey = args.farmKey
        }
    )
end

local function selMinMaxInput(args)
    local input =
        lib.inputDialog(
        args.item.label,
        {
            {
                type = "number",
                label = locale("items.min"),
                description = locale("items.description_min"),
                default = args.item.min or 0,
                required = true,
                min = args.min,
                max = args.max
            },
            {
                type = "number",
                label = locale("items.max"),
                description = locale("items.description_max"),
                default = args.item.max or 1,
                required = true,
                min = args.min,
                max = args.max
            },
            {
                type = "textarea",
                min = 5,
                default = args.example,
                disabled = true
            }
        }
    )
    if input then
        if input[2] < input[1] then
            lib.notify(
                {
                    type = "error",
                    description = locale("error.invalid_range")
                }
            )
            input = selMinMaxInput(args)
        end
        return input
    end
end

local function setName(args)
    local item = Farms[args.farmKey].config.items[args.itemKey]
    local input =
        lib.inputDialog(
        locale("route.setname"),
        {
            {
                type = "input",
                label = locale("route.name"),
                description = locale("route.description"),
                default = item["customName"] or Items[args.itemKey].label,
                min = 5,
                max = 30
            }
        }
    )
    if input then
        item["customName"] = input[1]
        Farms[args.farmKey].config.items[args.itemKey] = item
    end
    args.callback(
        {
            farmKey = args.farmKey,
            itemKey = args.itemKey
        }
    )
end

local function setMinMax(args)
    local item = Farms[args.farmKey].config.items[args.itemKey]
    local input =
        selMinMaxInput(
        {
            min = 0,
            max = 99999,
            example = locale("items.example_minmax"),
            item = {
                label = Items[args.itemKey].label,
                item.min,
                item.max
            }
        }
    )
    if input then
        item.min = tonumber(input[1])
        item.max = tonumber(input[2])
        Farms[args.farmKey].config.items[args.itemKey] = item
    end
    args.callback(
        {
            farmKey = args.farmKey,
            itemKey = args.itemKey
        }
    )
end

local function setCollectTime(args)
    local item = Farms[args.farmKey].config.items[args.itemKey]
    local input =
        lib.inputDialog(
        locale("actions.item.collect_time"),
        {
            {
                type = "number",
                label = locale("items.collect_time"),
                description = locale("items.description_collect_time"),
                default = item.collectTime or DefaultCollectTime,
                required = true,
                min = 0
            }
        }
    )

    if input then
        item.collectTime = input[1] or DefaultCollectTime
        Farms[args.farmKey].config.items[args.itemKey] = item
    end
    args.callback(
        {
            farmKey = args.farmKey,
            itemKey = args.itemKey
        }
    )
end

local function setCollectItem(args)
    local item = Farms[args.farmKey].config.items[args.itemKey]
    local collectItem = item["collectItem"] or {}
    local collectItemName = collectItem["name"]
    local input =
        lib.inputDialog(
        locale("actions.item.collect_item"),
        {
            {
                type = "select",
                label = locale("items.name"),
                description = locale("items.description_collect_item"),
                default = collectItemName or "",
                options = Utils.GetBaseItems(),
                searchable = true,
                clearable = true
            }
        }
    )

    if input then
        if input[1] then
            collectItem["name"] = input[1]
            item["collectItem"] = collectItem
        else
            item["collectItem"] = nil
        end
        Farms[args.farmKey].config.items[args.itemKey] = item
    end
    args.callback(
        {
            farmKey = args.farmKey,
            itemKey = args.itemKey
        }
    )
end

function setItemDurability(args)
    local item = Farms[args.farmKey].config.items[args.itemKey]
    local input =
        lib.inputDialog(
        locale("actions.item.item_durability"),
        {
            {
                type = "number",
                label = locale("items.durability"),
                description = locale("items.description_item_durability"),
                default = item["collectItem"]["durability"] or 0,
                required = true,
                min = 0,
                max = 100
            }
        }
    )

    if input then
        if input[1] then
            item["collectItem"]["durability"] = input[1]
        else
            item["collectItem"]["durability"] = nil
        end
        Farms[args.farmKey].config.items[args.itemKey] = item
    end
    args.callback(
        {
            farmKey = args.farmKey,
            itemKey = args.itemKey
        }
    )
end

function setGainStress(args)
    local item = Farms[args.farmKey].config.items[args.itemKey]
    local gainStress = item["gainStress"] or {min = 0, max = 1}
    local input =
        selMinMaxInput(
        {
            min = 0,
            max = 99999,
            example = locale("items.example_stress"),
            item = {
                label = locale("creator.stress"),
                item.min,
                item.max
            }
        }
    )
    if input then
        gainStress["min"] = tonumber(input[1]) or 0
        gainStress["max"] = tonumber(input[2]) or 0
        item["gainStress"] = gainStress
        Farms[args.farmKey].config.items[args.itemKey] = item
    end
    args.callback(
        {
            farmKey = args.farmKey,
            itemKey = args.itemKey
        }
    )
end

local function setRandom(args)
    local item = Farms[args.farmKey].config.items[args.itemKey]
    local input =
        lib.inputDialog(
        locale("actions.item.random"),
        {
            {
                type = "checkbox",
                label = locale("actions.item.random"),
                description = locale("actions.item.description_random"),
                checked = item.randomRoute
            }
        }
    )
    if input then
        item.randomRoute = input[1] or false
        Farms[args.farmKey].config.items[args.itemKey] = item
    end
    args.callback(
        {
            farmKey = args.farmKey,
            itemKey = args.itemKey
        }
    )
end

local function setUnlimited(args)
    local item = Farms[args.farmKey].config.items[args.itemKey]
    local input =
        lib.inputDialog(
        locale("actions.item.unlimited"),
        {
            {
                type = "checkbox",
                label = locale("actions.item.unlimited"),
                description = locale("actions.item.description_unlimited"),
                checked = item.unlimited
            }
        }
    )
    if input then
        item.unlimited = input[1] or false
        Farms[args.farmKey].config.items[args.itemKey] = item
    end
    args.callback(
        {
            farmKey = args.farmKey,
            itemKey = args.itemKey
        }
    )
end

local function setAnimation(args)
    local item = Farms[args.farmKey].config.items[args.itemKey]
    if Config.UseEmoteMenu then
        local input =
            lib.inputDialog(
            locale("actions.item.animation"),
            {
                {
                    type = "input",
                    label = locale("actions.item.animation"),
                    description = locale("actions.item.description_anim_name"),
                    default = type(item.animation) ~= "table" and item.animation or "",
                    required = true
                }
            }
        )
        if input then
            item.animation = input[1]
            Farms[args.farmKey].config.items[args.itemKey] = item
        end
    else
        local input =
            lib.inputDialog(
            locale("items.animation"),
            {
                {
                    type = "input",
                    label = locale("anim.dict"),
                    default = item.animation.dict or "amb@prop_human_bum_bin@idle_a",
                    required = true
                },
                {
                    type = "input",
                    label = locale("anim.anim"),
                    default = item.animation.anim or "idle_a",
                    required = true
                },
                {
                    type = "number",
                    label = locale("anim.inspeed"),
                    default = item.animation.inSpeed or 6.0,
                    required = true
                },
                {
                    type = "number",
                    label = locale("anim.outspeed"),
                    default = item.animation.outSpeed or -6.0,
                    required = true
                },
                {
                    type = "number",
                    label = locale("anim.duration"),
                    default = item.animation.duration or -1,
                    required = true
                },
                {
                    type = "number",
                    label = locale("anim.flag"),
                    default = item.animation.flag or 47,
                    required = true
                },
                {
                    type = "number",
                    label = locale("anim.rate"),
                    default = item.animation.rate or 0,
                    required = true
                },
                {
                    type = "number",
                    label = locale("anim.x"),
                    default = item.animation.x or 0,
                    required = true
                },
                {
                    type = "number",
                    label = locale("anim.y"),
                    default = item.animation.y or 0,
                    required = true
                },
                {
                    type = "number",
                    label = locale("anim.z"),
                    default = item.animation.z or 0,
                    required = true
                }
            }
        )
        if input then
            local _anim = item.animation or {}
            if type(item.animation) == "string" then
                _anim = {}
            end
            _anim['dict'] = input[1]
            _anim['anim'] = input[2]
            _anim['inSpeed'] = input[3]
            _anim['outSpeed'] = input[4]
            _anim['duration'] = input[5]
            _anim['flag'] = input[6]
            _anim['rate'] = input[7]
            _anim['x'] = input[8]
            _anim['y'] = input[9]
            _anim['z'] = input[10]
            item.animation = _anim
            Farms[args.farmKey].config.items[args.itemKey] = item
        end
    end
    args.callback(
        {
            farmKey = args.farmKey,
            itemKey = args.itemKey
        }
    )
end

local function pointMenu(args)
    local ctx = {
        id = "point_item",
        menu = "list_points",
        title = args.name,
        options = {
            {
                title = locale("actions.point.change_location"),
                description = locale("actions.point.description_change_location"),
                icon = "location-dot",
                iconAnimation = Config.IconAnimation,
                onSelect = changePointLocation,
                args = {
                    farmKey = args.farmKey,
                    itemKey = args.itemKey,
                    pointKey = args.pointKey,
                    callback = pointMenu
                }
            },
            {
                title = locale("actions.teleport"),
                description = locale("actions.description_teleport"),
                icon = "location-dot",
                iconAnimation = Config.IconAnimation,
                onSelect = teleportToPoint,
                args = {
                    farmKey = args.farmKey,
                    itemKey = args.itemKey,
                    pointKey = args.pointKey,
                    callback = pointMenu
                }
            },
            {
                title = locale("actions.delete"),
                description = locale("actions.description_delete", locale("actions.point")),
                icon = "trash",
                iconAnimation = Config.IconAnimation,
                iconColor = ColorScheme.danger,
                onSelect = deletePoint,
                args = {
                    farmKey = args.farmKey,
                    itemKey = args.itemKey,
                    pointKey = args.pointKey,
                    name = args.name,
                    callback = listPoints
                }
            }
        }
    }
    lib.registerContext(ctx)
    lib.showContext(ctx.id)
end

local function addPoints(args)
    local keepLoop = true
    local farm = Farms[args.farmKey]
    local item = farm.config.items[args.itemKey]
    while keepLoop do
        Wait(0)
        local result = Utils.GetPedCoords()
        keepLoop = result.result == "choose"
        if keepLoop then
            local pos = result.coords
            -- Explicit conversion to table for JSON safety
            item.points[#item.points + 1] = { x = pos.x, y = pos.y, z = pos.z }
            Farms[args.farmKey].config.items[args.itemKey] = item
            refreshCreatorCheckpoints()
            lib.notify(
                {
                    type = "success",
                    description = locale("actions.point.add")
                }
            )
        end
    end
    local updatedFarm = lib.callback.await("mri_Qfarm:server:SaveFarm", false, Farms[args.farmKey])
    if updatedFarm then Farms[args.farmKey] = updatedFarm end
    refreshCreatorCheckpoints()
    args.callback(args.farmKey, "points", args.itemKey)
end

function listPoints(args)
    local ctx = {
        id = "list_points",
        menu = "action_item",
        title = locale("menus.points", Items[args.itemKey].label),
        options = {
            {
                title = locale("actions.add_point"),
                description = locale("actions.description_add_point"),
                icon = "square-plus",
                iconAnimation = Config.IconAnimation,
                onSelect = addPoints,
                args = {
                    farmKey = args.farmKey,
                    itemKey = args.itemKey,
                    callback = listPoints
                }
            }
        }
    }
    local farm = Farms[args.farmKey]
    local item = farm.config.items[args.itemKey]
    for k, v in pairs(item.points) do
        ctx.options[#ctx.options + 1] = {
            title = Utils.GetLocationFormatted(v, k),
            description = string.format("X: %.2f, Y: %.2f, Z: %.2f", v.x, v.y, v.z),
            icon = "map-pin",
            iconAnimation = Config.IconAnimation,
            arrow = true,
            onSelect = pointMenu,
            args = {
                farmKey = args.farmKey,
                itemKey = args.itemKey,
                pointKey = k,
                name = Utils.GetLocationFormatted(v, k)
            }
        }
    end
    lib.registerContext(ctx)
    lib.showContext(ctx.id)
end

local function addExtraItem(args)
    local farm = Farms[args.farmKey]
    local item = farm.config.items[args.itemKey]
    local extraItems = item["extraItems"] or {}
    local input = selItemInput(args, true)
    if input then
        extraItems[input[1]] = {
            min = 0,
            max = 1
        }
        item["extraItems"] = extraItems
        farm.config.items[args.itemKey] = item
        Farms[args.farmKey] = farm
    else
        listExtraItems(args)
        return
    end
    args.callback(
        {
            farmKey = args.farmKey,
            itemKey = args.itemKey,
            extraItemKey = input[1]
        }
    )
end

local function setMinMaxExtraItem(args)
    local farm = Farms[args.farmKey]
    local item = farm.config.items[args.itemKey]
    local extraItems = item["extraItems"] or {}
    local extraItem = extraItems[args.extraItemKey]
    local input =
        selMinMaxInput(
        {
            min = 0,
            max = 99999,
            example = locale("items.example_minmax"),
            item = {
                label = Items[args.extraItemKey].label,
                extraItem.min,
                extraItem.max
            }
        }
    )
    if input then
        extraItems[args.extraItemKey].min = input[1] or 0
        extraItems[args.extraItemKey].max = input[2] or 1
        item["extraItems"] = extraItems
        farm.config.items[args.itemKey] = item
        Farms[args.farmKey] = farm
    end
    args.callback(
        {
            farmKey = args.farmKey,
            itemKey = args.itemKey,
            extraItemKey = args.extraItemKey
        }
    )
end

local function extraItemActionMenu(args)
    local farm = Farms[args.farmKey]
    local item = farm.config.items[args.itemKey]
    local extraItem = item["extraItems"][args.extraItemKey]
    local ctx = {
        id = "extra_item_action",
        menu = "list_extra_items",
        title = locale("menus.extra_items", Items[args.extraItemKey].label),
        description = locale("menu.description_extra_items", extraItem.min, extraItem.max),
        options = {
            {
                title = locale("actions.item.select"),
                icon = "box-open",
                iconAnimation = Config.IconAnimation,
                onSelect = addExtraItem,
                args = {
                    farmKey = args.farmKey,
                    itemKey = args.itemKey,
                    callback = extraItemActionMenu
                }
            },
            {
                title = locale("actions.item.minmax"),
                description = locale("actions.item.description_minmax", extraItem.min, extraItem.max),
                icon = "up-down",
                iconAnimation = Config.IconAnimation,
                onSelect = setMinMaxExtraItem,
                args = {
                    farmKey = args.farmKey,
                    itemKey = args.itemKey,
                    extraItemKey = args.extraItemKey,
                    callback = extraItemActionMenu
                }
            },
            {
                title = locale("actions.delete"),
                description = locale("actions.description_delete", locale("actions.item")),
                icon = "trash",
                iconAnimation = Config.IconAnimation,
                iconColor = ColorScheme.danger,
                onSelect = deleteExtraItem,
                args = {
                    farmKey = args.farmKey,
                    itemKey = args.itemKey,
                    extraItemKey = args.extraItemKey,
                    callback = listExtraItems
                }
            }
        }
    }
    lib.registerContext(ctx)
    lib.showContext(ctx.id)
end

function listExtraItems(args)
    local farm = Farms[args.farmKey]
    local item = farm.config.items[args.itemKey]
    local ctx = {
        id = "list_extra_items",
        menu = "config_item",
        title = locale("menus.extra_items", Items[args.itemKey].label),
        options = {}
    }
    ctx.options[#ctx.options + 1] = {
        title = locale("actions.item.add_extra_item"),
        description = locale("actions.item.description_add_extra_item"),
        icon = "square-plus",
        iconAnimation = Config.IconAnimation,
        onSelect = addExtraItem,
        args = {
            farmKey = args.farmKey,
            itemKey = args.itemKey,
            callback = listExtraItems
        }
    }
    for k, v in pairs(item.extraItems or {}) do
        ctx.options[#ctx.options + 1] = {
            title = Items[k].label,
            description = locale("items.extra_description", v.min, v.max),
            icon = string.format("%s/%s.png", ImageURL, Items[k].name),
            iconAnimation = Config.IconAnimation,
            onSelect = extraItemActionMenu,
            args = {
                farmKey = args.farmKey,
                itemKey = args.itemKey,
                extraItemKey = k,
                callback = listExtraItems
            }
        }
    end
    lib.registerContext(ctx)
    lib.showContext(ctx.id)
end

local function configMenu(args)
    local item = Farms[args.farmKey].config.items[args.itemKey]
    local ctx = {
        id = "config_item",
        menu = "action_item",
        title = Items[args.itemKey].label,
        description = Items[args.itemKey].description,
        options = {
            {
                title = locale("actions.item.collect_time"),
                description = locale("actions.item.description_collect_time", item.collectTime or DefaultCollectTime),
                icon = "clock",
                iconAnimation = Config.IconAnimation,
                onSelect = setCollectTime,
                args = {
                    farmKey = args.farmKey,
                    itemKey = args.itemKey,
                    callback = configMenu
                }
            },
            {
                title = locale("actions.item.collect_item"),
                description = locale(
                    "actions.item.description_collect_item",
                    item["collectItem"] and item["collectItem"]["name"] and Items[item["collectItem"]["name"]].label or
                        locale("misc.none")
                ),
                icon = "screwdriver-wrench",
                iconAnimation = Config.IconAnimation,
                onSelect = setCollectItem,
                args = {
                    farmKey = args.farmKey,
                    itemKey = args.itemKey,
                    callback = configMenu
                }
            },
            {
                title = locale("actions.item.item_durability"),
                description = locale(
                    "actions.item.description_item_durability",
                    item["collectItem"] and item["collectItem"]["name"] and Items[item["collectItem"]["name"]].label or
                        locale("misc.none"),
                    item["collectItem"] and item["collectItem"]["durability"] or 0
                ),
                icon = "wrench",
                iconAnimation = Config.IconAnimation,
                disabled = item["collectItem"] == nil or item["collectItem"]["name"] == nil,
                onSelect = setItemDurability,
                args = {
                    farmKey = args.farmKey,
                    itemKey = args.itemKey,
                    callback = configMenu
                }
            },
            {
                title = locale("actions.item.gain_stress"),
                description = locale(
                    "actions.item.description_gain_stress",
                    item["gainStress"] and (item["gainStress"]["min"]) or 0,
                    item["gainStress"] and (item["gainStress"]["max"]) or 0
                ),
                icon = "face-tired",
                iconAnimation = Config.IconAnimation,
                onSelect = setGainStress,
                args = {
                    farmKey = args.farmKey,
                    itemKey = args.itemKey,
                    callback = configMenu
                }
            },
            {
                title = locale("actions.item.random"),
                description = locale(
                    "actions.item.description_random",
                    item.randomRoute and locale("misc.yes") or locale("misc.no")
                ),
                icon = "shuffle",
                iconColor = ifThen(item.randomRoute, ColorScheme.success, ColorScheme.danger),
                iconAnimation = Config.IconAnimation,
                onSelect = setRandom,
                args = {
                    farmKey = args.farmKey,
                    itemKey = args.itemKey,
                    callback = configMenu
                }
            },
            {
                title = locale("actions.item.unlimited"),
                description = locale(
                    "actions.item.description_unlimited",
                    item.unlimited and locale("misc.yes") or locale("misc.no")
                ),
                icon = "infinity",
                iconAnimation = Config.IconAnimation,
                iconColor = ifThen(item.unlimited, ColorScheme.success, ColorScheme.danger),
                onSelect = setUnlimited,
                args = {
                    farmKey = args.farmKey,
                    itemKey = args.itemKey,
                    callback = configMenu
                }
            },
            {
                title = locale("actions.item.extraItems"),
                description = locale("actions.item.description_extraItems"),
                icon = "list",
                iconAnimation = Config.IconAnimation,
                arrow = true,
                onSelect = listExtraItems,
                args = {
                    farmKey = args.farmKey,
                    itemKey = args.itemKey
                }
            }
        }
    }
    lib.registerContext(ctx)
    lib.showContext(ctx.id)
end

local function itemActionMenu(args)
    local item = Farms[args.farmKey].config.items[args.itemKey]
    local ctx = {
        id = "action_item",
        title = item["customName"] and item["customName"] ~= "" and item["customName"] or Items[args.itemKey].label,
        description = Items[args.itemKey].description,
        menu = "items_farm",
        options = {
            {
                title = locale("actions.item.setname"),
                description = locale("actions.item.description_setname"),
                icon = "tag",
                iconAnimation = Config.IconAnimation,
                onSelect = setName,
                args = {
                    farmKey = args.farmKey,
                    itemKey = args.itemKey,
                    callback = itemActionMenu
                }
            },
            {
                title = locale("actions.item.select"),
                description = locale("actions.item.description_select"),
                icon = "box-open",
                iconAnimation = Config.IconAnimation,
                onSelect = setItem,
                args = {
                    farmKey = args.farmKey,
                    itemKey = args.itemKey,
                    callback = ListItems
                }
            },
            {
                title = locale("actions.item.minmax"),
                description = locale("actions.item.description_minmax", item.min or 0, item.max or 0),
                icon = "up-down",
                iconAnimation = Config.IconAnimation,
                onSelect = setMinMax,
                args = {
                    farmKey = args.farmKey,
                    itemKey = args.itemKey,
                    callback = itemActionMenu
                }
            },
            {
                title = locale("actions.item.config"),
                description = locale("actions.item.description_config"),
                icon = "gear",
                iconAnimation = Config.IconAnimation,
                arrow = true,
                onSelect = configMenu,
                args = {
                    farmKey = args.farmKey,
                    itemKey = args.itemKey,
                    callback = itemActionMenu
                }
            },
            {
                title = locale("actions.item.animation"),
                description = locale("actions.item.description_animation"),
                icon = "person-walking",
                iconAnimation = Config.IconAnimation,
                onSelect = setAnimation,
                args = {
                    farmKey = args.farmKey,
                    itemKey = args.itemKey,
                    callback = itemActionMenu
                }
            },
            {
                title = locale("actions.item.points"),
                description = locale("actions.item.description_points", #item.points),
                icon = "location-crosshairs",
                iconAnimation = Config.IconAnimation,
                arrow = true,
                onSelect = listPoints,
                args = {
                    farmKey = args.farmKey,
                    itemKey = args.itemKey
                }
            },
            {
                title = locale("actions.delete"),
                description = locale("actions.description_delete", locale("actions.item")),
                icon = "trash",
                iconAnimation = Config.IconAnimation,
                iconColor = ColorScheme.danger,
                onSelect = deleteItem,
                args = {
                    farmKey = args.farmKey,
                    itemKey = args.itemKey,
                    callback = ListItems,
                    callbackCancel = itemActionMenu
                }
            }
        }
    }

    lib.registerContext(ctx)
    lib.showContext(ctx.id)
end

function ListItems(args)
    local farm = Farms[args.farmKey]
    local ctx = {
        id = "items_farm",
        title = locale("menus.items"),
        menu = "action_farm",
        description = farm.name,
        options = {
            {
                title = locale("actions.item.create"),
                description = locale("actions.item.description_create"),
                icon = "square-plus",
                iconAnimation = Config.IconAnimation,
                arrow = true,
                onSelect = setItem,
                args = {
                    farmKey = args.farmKey,
                    callback = ListItems
                }
            }
        }
    }
    for k, v in pairs(farm.config.items) do
        if Items[k] then
            ctx.options[#ctx.options + 1] = {
                title = v["customName"] and v["customName"] ~= "" and v["customName"] or Items[k].label,
                icon = string.format("%s/%s.png", ImageURL, Items[k].name),
                image = string.format("%s/%s.png", ImageURL, Items[k].name),
                metadata = Utils.GetItemMetadata(Items[k]),
                description = Items[k].description,
                onSelect = itemActionMenu,
                args = {
                    itemKey = k,
                    farmKey = args.farmKey
                }
            }
        else
            ctx.options[#ctx.options + 1] = {
                title = locale("error.invalid_item", k),
                description = locale("error.invalid_item_description"),
                icon = "trash",
                iconAnimation = Config.IconAnimation,
                iconColor = ColorScheme.danger,
                onSelect = deleteItem,
                args = {
                    farmKey = args.farmKey,
                    itemKey = k,
                    callback = ListItems,
                    callbackCancel = ListItems
                }
            }
        end
    end
    lib.registerContext(ctx)
    lib.showContext(ctx.id)
end

local function saveFarm(args)
    lib.callback.await("mri_Qfarm:server:SaveFarm", false, Farms[args.farmKey], args.farmKey)
    args.callback(args.farmKey)
end

local function actionMenu(key)
    local farm = Farms[key]
    local groupName = locale("creator.no_group")
    local grade = "0"
    local groups = Utils.GetBaseGroups(true)
    local disableGradeSet = false
    if farm.group["name"] then
        groupName = Utils.GetGroupsLabel(farm.group["name"])
    else
        disableGradeSet = true
    end
    if farm.group["grade"] then
        grade = farm.group["grade"]
    end
    local locationText = locale("actions.farm.change_location")
    if farm.config.start.location == nil then
        locationText = locale("actions.farm.set_location")
    end
    local ctx = {
        id = "action_farm",
        title = farm.name:upper(),
        menu = "list_farms",
        options = {
            {
                title = locale("actions.farm.rename"),
                description = locale("actions.farm.description_rename"),
                icon = "tag",
                iconAnimation = Config.IconAnimation,
                onSelect = setFarmName,
                args = {
                    farmKey = key,
                    callback = actionMenu
                }
            },
            {
                title = locale("creator.groups"),
                description = locale("creator.description_group", groupName),
                icon = "users",
                iconAnimation = Config.IconAnimation,
                onSelect = setFarmGroup,
                args = {
                    farmKey = key,
                    callback = actionMenu
                }
            },
            {
                title = locale("creator.grade"),
                description = locale("creator.description_grade", grade),
                icon = "list-ol",
                iconAnimation = Config.IconAnimation,
                onSelect = setFarmGrade,
                disabled = disableGradeSet,
                args = {
                    farmKey = key,
                    callback = actionMenu
                }
            },
            {
                title = locationText,
                icon = "map-location-dot",
                iconAnimation = Config.IconAnimation,
                onSelect = changeFarmLocation,
                description = locale("actions.farm.description_location"),
                args = {
                    farmKey = key,
                    callback = actionMenu
                }
            },
            {
                title = locale("actions.farm.items"),
                description = locale("actions.farm.description_items"),
                icon = "route",
                iconAnimation = Config.IconAnimation,
                arrow = true,
                onSelect = ListItems,
                args = {
                    farmKey = key
                }
            },
            {
                title = locale("actions.teleport"),
                description = locale("actions.description_teleport"),
                icon = "location-dot",
                iconAnimation = Config.IconAnimation,
                onSelect = teleportToFarm,
                args = {
                    farmKey = key,
                    callback = actionMenu
                }
            },
            {
                title = locale("actions.export"),
                description = locale("actions.description_export", locale("actions.farm")),
                icon = "share-from-square",
                iconAnimation = Config.IconAnimation,
                onSelect = exportFarm,
                args = {
                    farmKey = key,
                    callback = actionMenu
                }
            },
            {
                title = locale("actions.save"),
                description = locale("actions.description_save"),
                icon = "floppy-disk",
                iconAnimation = Config.IconAnimation,
                onSelect = saveFarm,
                args = {
                    farmKey = key,
                    callback = actionMenu
                }
            },
            {
                title = locale("actions.delete"),
                description = locale("actions.description_delete", locale("actions.farm")),
                icon = "trash",
                iconAnimation = Config.IconAnimation,
                iconColor = ColorScheme.danger,
                onSelect = deleteFarm,
                args = {
                    farmKey = key,
                    callback = ListFarm,
                    callbackCancel = actionMenu
                }
            }
        }
    }
    lib.registerContext(ctx)
    lib.showContext(ctx.id)
end

function ListFarm()
    local ctx = {
        id = "list_farms",
        menu = "menu_farm",
        title = locale("menus.farms"),
        description = locale("actions.farm.description_title", #Farms),
        options = {}
    }
    for k, v in pairs(Farms) do
        local groupName = locale("creator.no_group")
        if v.group["name"] then
            groupName = Utils.GetGroupsLabel(v.group["name"])
        end
        local description = locale("menus.description_farm", locale("creator.groups"), groupName)
        ctx.options[#ctx.options + 1] = {
            title = v.name:upper(),
            icon = "warehouse",
            iconAnimation = Config.IconAnimation,
            description = description,
            metadata = Utils.GetMetadataFromFarm(k),
            onSelect = function()
                actionMenu(k)
            end
        }
    end
    lib.registerContext(ctx)
    lib.showContext(ctx.id)
end

local function manageFarms(targetFarmId, targetTab, targetItemKey)
    isCreatorOpen = true
    -- Only pull from GlobalState if local Farms table is empty or we are forced to
    if not Farms or next(Farms) == nil then
        Farms = GlobalState.Farms or {}
    end
    Items = exports.ox_inventory:Items()

    currentEditingFarm = targetFarmId
    currentEditingItem = targetItemKey
    refreshCreatorCheckpoints()

    local farmsData = {}
    for k, v in pairs(Farms) do
        table.insert(farmsData, {
            id = k,
            name = v.name,
            farmId = v.farmId,
            group = v.group,
            config = v.config
        })
    end
    
    SetNuiFocus(true, true)

    if Config.Debug then
        print(string.format("^3[manageFarms] Sending open to NUI. TargetFarmId: %s, TargetTab: %s, FarmsCount: %d^7", tostring(targetFarmId), tostring(targetTab), #farmsData))
    end

    SendNUIMessage({
        action = "open",
        type = "creator",
        farms = farmsData,
        config = Config,
        targetFarmId = targetFarmId and tonumber(targetFarmId) or nil,
        targetTab = targetTab,
        targetItemKey = targetItemKey
    })
end

RegisterNUICallback('saveGeneral', function(data, cb)
    local key = tonumber(data.farmKey)
    local farm = Farms[key]
    if farm then
        farm.name = data.name
        if not farm.config.start.ped then 
            farm.config.start.ped = { model = "s_m_m_scientist_01", enabled = false } 
        end
        farm.config.start.ped.enabled = data.ped.enabled
        farm.config.start.ped.model = data.ped.model
        -- farm.config.start.ped.coords remains as is
        
        Farms[key] = farm
        local updatedFarm = lib.callback.await("mri_Qfarm:server:SaveFarm", false, farm)
        if updatedFarm then Farms[key] = updatedFarm end
        lib.notify({ type = 'success', description = 'Configurações gerais atualizadas!' })
        manageFarms(farm.farmId, "general")
    end
    cb('ok')
end)

RegisterNUICallback('refreshFarms', function(data, cb)
    manageFarms()
    cb('ok')
end)

RegisterNUICallback('duplicateFarm', function(data, cb)
    local sourceKey = data.farmKey
    local sourceFarm = Farms[sourceKey]
    if sourceFarm then
        local newFarmObj = table.clone(sourceFarm)
        newFarmObj.farmId = nil -- Crucial: setting to nil makes the server create a new entry
        newFarmObj.name = data.newName
        
        local success = lib.callback.await("mri_Qfarm:server:SaveFarm", false, newFarmObj)
        if success then
            lib.notify({ type = 'success', description = 'Rota duplicada com sucesso!' })
            manageFarms() -- Refresh UI
        end
    end
    cb('ok')
end)

RegisterNUICallback('deleteFarm', function(data, cb)
    local farmKey = tonumber(data.farmKey)
    local farm = Farms[farmKey]
    if farm then
        lib.callback.await("mri_Qfarm:server:DeleteFarm", false, farm.farmId)
        Farms[farmKey] = nil
        lib.notify({ type = 'success', description = 'Farm excluído com sucesso!' })
        manageFarms() -- Back to list
    end
    cb('ok')
end)

RegisterNUICallback('createFarm', function(data, cb)
    local newFarmObj = {
        name = data.name,
        config = {
            start = { location = nil, width = Config.FarmBoxWidth, length = Config.FarmBoxLength },
            items = {}
        },
        group = { name = {}, grade = 0 } -- Start with empty table for multi-job
    }
    
    local success = lib.callback.await("mri_Qfarm:server:SaveFarm", false, newFarmObj)
    if success then
        lib.notify({ type = 'success', description = 'Novo farm criado!' })
        manageFarms() -- Refresh UI to show the new card
    end
    cb('ok')
end)

RegisterNUICallback('saveGrade', function(data, cb)
    local farm = Farms[data.farmKey]
    if farm then
        farm.group.grade = tonumber(data.grade) or 0
        local updatedFarm = lib.callback.await("mri_Qfarm:server:SaveFarm", false, farm)
        if updatedFarm then Farms[data.farmKey] = updatedFarm end
        lib.notify({ type = 'success', description = 'Rank mínimo atualizado!' })
        manageFarms(farm.farmId, "groups")
    end
    cb('ok')
end)

RegisterNUICallback('editGroups', function(data, cb)
    local farm = Farms[data.farmKey]
    if farm then
        local input = lib.inputDialog('Gerenciar Grupos', {
            {
                type = 'multi-select',
                label = 'Jobs/Gangs Permitidos',
                description = 'Selecione os grupos que podem acessar esta rota.',
                options = Utils.GetBaseGroups(),
                default = farm.group.name,
                searchable = true
            }
        })
        
        if input then
            farm.group.name = input[1]
            local updatedFarm = lib.callback.await("mri_Qfarm:server:SaveFarm", false, farm)
            if updatedFarm then Farms[data.farmKey] = updatedFarm end
            lib.notify({ type = 'success', description = 'Permissões atualizadas!' })
        end
        manageFarms(farm.farmId, "groups")
    end
    cb('ok')
end)

RegisterNUICallback('addPoint', function(data, cb)
    SetNuiFocus(false, false)
    addPoints({
        farmKey = data.farmKey,
        itemKey = data.itemKey,
        callback = manageFarms -- Reopen NUI after picking points
    })
    cb('ok')
end)

RegisterNUICallback('removePoint', function(data, cb)
    local farm = Farms[data.farmKey]
    if farm and farm.config.items[data.itemKey] then
        table.remove(farm.config.items[data.itemKey].points, data.pointIdx + 1)
        lib.callback.await("mri_Qfarm:server:SaveFarm", false, farm)
        lib.notify({ type = 'success', description = 'Ponto removido!' })
        manageFarms(farm.farmId, "points")
    end
    cb('ok')
end)

RegisterNUICallback('addFarmItem', function(data, cb)
    local farm = Farms[data.farmKey]
    if farm then
        local input = lib.inputDialog('Adicionar Item', {
            {
                type = 'select',
                label = 'Selecionar Item',
                options = Utils.GetBaseItems(),
                searchable = true,
                required = true
            }
        })

        if input then
            local itemKey = input[1]
            if not farm.config.items[itemKey] then
                farm.config.items[itemKey] = {
                    min = 1,
                    max = 1,
                    points = {},
                    collectTime = 2000,
                    customName = itemKey
                }
                local updatedFarm = lib.callback.await("mri_Qfarm:server:SaveFarm", false, farm)
                if updatedFarm then Farms[data.farmKey] = updatedFarm end
                lib.notify({ type = 'success', description = 'Item adicionado à rota!' })
            else
                lib.notify({ type = 'error', description = 'Este item já existe nesta rota!' })
            end
        end
        manageFarms(farm.farmId, "items")
    end
    cb('ok')
end)

RegisterNUICallback('removeItem', function(data, cb)
    local farm = Farms[data.farmKey]
    if farm and farm.config.items[data.itemKey] then
        farm.config.items[data.itemKey] = nil
        local updatedFarm = lib.callback.await("mri_Qfarm:server:SaveFarm", false, farm)
        if updatedFarm then Farms[data.farmKey] = updatedFarm end
        lib.notify({ type = 'success', description = 'Item removido da rota!' })
        manageFarms(farm.farmId, "items")
    end
    cb('ok')
end)

RegisterNUICallback('saveItemConfig', function(data, cb)
    local farm = Farms[data.farmKey]
    if farm and farm.config.items[data.itemKey] then
        local item = farm.config.items[data.itemKey]
        item.customName = data.config.customName
        item.min = data.config.min
        item.max = data.config.max
        item.collectTime = data.config.collectTime
        
        local updatedFarm = lib.callback.await("mri_Qfarm:server:SaveFarm", false, farm)
        if updatedFarm then Farms[data.farmKey] = updatedFarm end
        lib.notify({ type = 'success', description = 'Configurações do item salvas!' })
        manageFarms(farm.farmId, "items")
    end
    cb('ok')
end)

RegisterNUICallback('updatePoint', function(data, cb)
    local farm = Farms[data.farmKey]
    if farm and farm.config.items[data.itemKey] then
        SetNuiFocus(false, false)
        local result = Utils.GetPedCoords()
        if result.result == "choose" then
            local pos = result.coords
            if Config.Debug then print(string.format("^3[updatePoint] Captured coords: %s^7", tostring(pos))) end
            -- Explicitly convert vector3 to plain table for NUI/JSON safety
            farm.config.items[data.itemKey].points[data.pointIdx + 1] = { x = pos.x, y = pos.y, z = pos.z }
            local updatedFarm = lib.callback.await("mri_Qfarm:server:SaveFarm", false, farm)
            if updatedFarm then Farms[data.farmKey] = updatedFarm end
            lib.notify({ type = 'success', description = 'Ponto atualizado!' })
        else
            if Config.Debug then print("^1[updatePoint] Point selection cancelled or failed.^7") end
        end
        manageFarms(farm.farmId, "points", data.itemKey)
    end
    cb('ok')
end)

RegisterNUICallback('tpStart', function(data, cb)
    local farm = Farms[data.farmKey]
    if farm and farm.config.start.location then
        isCreatorOpen = false
        SetNuiFocus(false, false)
        SendNUIMessage({ action = "close" })
        Utils.TpToLoc(farm.config.start.location)
        lib.notify({ type = 'info', description = 'Teleportado para o início da rota!' })
    end
    cb('ok')
end)

RegisterNUICallback('tpPoint', function(data, cb)
    local farm = Farms[data.farmKey]
    if farm and farm.config.items[data.itemKey] then
        local points = Utils.EnsureSequence(farm.config.items[data.itemKey].points)
        local point = points[data.pointIdx + 1]
        if point then
            isCreatorOpen = false
            SetNuiFocus(false, false)
            SendNUIMessage({ action = "close" })
            Utils.TpToLoc(point)
            lib.notify({ type = 'info', description = 'Teleportado para o ponto de coleta!' })
        else
            if Config.Debug then print("^1[tpPoint] Point not found at index: " .. tostring(data.pointIdx + 1)) end
        end
    end
    cb('ok')
end)

RegisterNUICallback('capturePedData', function(data, cb)
    local farm = Farms[data.farmKey]
    if farm then
        SetNuiFocus(false, false)
        lib.notify({ type = 'info', description = 'Posicione-se e pressione [E] para capturar sua posição e direção.' })
        local result = Utils.GetPedCoords()
        if result.result == "choose" then
            if not farm.config.start.ped then farm.config.start.ped = {} end
            local coords = result.coords
            local heading = GetEntityHeading(cache.ped)
            farm.config.start.ped.coords = { x = coords.x, y = coords.y, z = coords.z, w = heading }
            farm.config.start.ped.model = data.model
            
            lib.callback.await("mri_Qfarm:server:SaveFarm", false, farm)
            lib.notify({ type = 'success', description = 'Posição do Ped capturada!' })
        end
        manageFarms(farm.farmId, "general")
    end
    cb('ok')
end)

RegisterNUICallback('setStartLocation', function(data, cb)
    local farm = Farms[data.farmKey]
    if farm then
        SetNuiFocus(false, false)
        local result = Utils.GetPedCoords()
        if result.result == "choose" then
            local pos = result.coords
            farm.config.start.location = { x = pos.x, y = pos.y, z = pos.z }
            local updatedFarm = lib.callback.await("mri_Qfarm:server:SaveFarm", false, farm)
            if updatedFarm then Farms[data.farmKey] = updatedFarm end
            lib.notify({ type = 'success', description = 'Local de início definido!' })
        end
        manageFarms(farm.farmId, "general")
    end
    cb('ok')
end)

RegisterNUICallback('updateEditorState', function(data, cb)
    currentEditingFarm = data.farmKey
    currentEditingItem = data.itemKey
    refreshCreatorCheckpoints()
    cb('ok')
end)

RegisterNUICallback('close', function(data, cb)
    isCreatorOpen = false
    clearCreatorCheckpoints()
    SetNuiFocus(false, false)
    SendNUIMessage({ action = "close" })
    cb('ok')
end)

CreateThread(function()
    while true do
        local sleep = 1000
        -- Text drawing removed as requested to leave only checkpoints.
        -- This thread now primarily sleeps to maintain 0.00ms impact.
        Wait(sleep)
    end
end)

if GetResourceState("mri_Qbox") == "started" then
    exports["mri_Qbox"]:AddManageMenu(
        {
            title = locale("creator.title"),
            description = locale("creator.description_title"),
            icon = "toolbox",
            iconAnimation = "fade",
            arrow = true,
            onSelectFunction = manageFarms
        }
    )
else
    lib.callback.register(
        "mri_Qfarm:manageFarmsMenu",
        function()
            manageFarms()
            return true
        end
    )
end
AddEventHandler('onResourceStop', function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end
    clearCreatorCheckpoints()
end)
