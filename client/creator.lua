local Utils = lib.require("client/utils")
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

local function deletePoint(args)
    local result =
        delete(
        locale("actions.confirmation_description", locale("actions.point"), args.name),
        Farms[args.farmKey].config.items[args.itemKey].points,
        args.pointKey
    )
    args.callback(
        {
            farmKey = args.farmKey,
            itemKey = args.itemKey
        }
    )
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
        lib.notify(
            {
                type = "success",
                description = locale("notify.updated")
            }
        )
    end
    args.callback(
        {
            farmKey = args.farmKey,
            itemKey = args.itemKey,
            pointKey = args.pointKey
        }
    )
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
            item.points[#item.points + 1] = result.coords
            lib.notify(
                {
                    type = "success",
                    description = locale("actions.point.add")
                }
            )
        end
    end
    Farms[args.farmKey].config.items[args.itemKey] = item
    args.callback(
        {
            farmKey = args.farmKey,
            itemKey = args.itemKey
        }
    )
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

local function manageFarms()
    Items = exports.ox_inventory:Items()
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
    SendNUIMessage({
        action = "open",
        type = "creator",
        farms = farmsData,
        config = Config
    })
end

RegisterNUICallback('saveGeneral', function(data, cb)
    local key = data.farmKey
    local farm = Farms[key]
    if farm then
        farm.name = data.name
        Farms[key] = farm
        -- Here usually you'd call a server event to save the change
        lib.callback.await("mri_Qfarm:server:SaveFarm", false, farm)
        lib.notify({ type = 'success', description = 'Nome do farm atualizado!' })
    end
    cb('ok')
end)

RegisterNUICallback('deleteFarm', function(data, cb)
    local farm = Farms[data.farmKey]
    if farm then
        lib.callback.await("mri_Qfarm:server:DeleteFarm", false, farm.farmId)
        Farms[data.farmKey] = nil
        lib.notify({ type = 'success', description = 'Farm excluído com sucesso!' })
        SetNuiFocus(false, false)
        SendNUIMessage({ action = "close" })
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
        group = { name = nil, grade = 0 }
    }
    
    local key = #Farms + 1
    Farms[key] = newFarmObj
    -- Call server to create and get a real ID
    local success = lib.callback.await("mri_Qfarm:server:CreateFarm", false, newFarmObj)
    if success then
        lib.notify({ type = 'success', description = 'Novo farm criado!' })
    end
    
    SetNuiFocus(false, false)
    SendNUIMessage({ action = "close" })
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

RegisterNUICallback('tpPoint', function(data, cb)
    teleportToPoint({
        farmKey = data.farmKey,
        itemKey = data.itemKey,
        pointKey = data.pointIdx + 1, -- +1 because Lua is 1-indexed
        callback = manageFarms
    })
    cb('ok')
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
