local Utils = {}

function Utils.GetPedCoords()
    lib.hideTextUI()
    local text = {}
    table.insert(text, locale("actions.choose_location.1"))
    table.insert(text, locale("actions.choose_location.2"))
    lib.showTextUI(
        table.concat(text),
        {
            position = "right-center"
        }
    )

    while true do
        Wait(0)
        if IsControlJustReleased(0, 38) then
            Wait(200)
            lib.hideTextUI()
            return {
                result = "choose",
                coords = GetEntityCoords(cache.ped)
            }
        end
        if IsControlJustReleased(0, 177) then
            lib.hideTextUI()
            return {
                result = "cancel",
                coords = nil
            }
        end
        if IsControlJustPressed(0, 201) then
            lib.hideTextUI()
            return {
                result = "end",
                coords = nil
            }
        end
    end
end

function Utils.TpToLoc(coords)
    if coords then
        DoScreenFadeOut(500)
        Wait(1000)
        SetPedCoordsKeepVehicle(PlayerPedId(), coords.x, coords.y, coords.z)
        DoScreenFadeIn(500)
    end
end

function Utils.ConfirmationDialog(content)
    return lib.alertDialog(
        {
            header = locale("dialog.confirmation"),
            content = content,
            centered = true,
            cancel = true,
            labels = {
                cancel = locale("actions.cancel"),
                confirm = locale("actions.confirm")
            }
        }
    )
end

function Utils.GetLocation(coords)
    local streetName, crossingRoad = GetStreetNameAtCoord(coords.x, coords.y, coords.z)
    return GetStreetNameFromHashKey(streetName)
end

function Utils.GetLocationFormatted(location, key)
    if key then
        return string.format("[%02d] - %s", key, Utils.GetLocation(location))
    else
        return Utils.GetLocation(location)
    end
end

function Utils.GetGroupGrades(group)
    local grades = {}
    for k, v in pairs(group.grades) do
        grades[#grades + 1] = {
            value = k,
            label = string.format("%s - %s", k, v.name)
        }
    end
    return grades
end

function Utils.GetBaseGroups(named)
    local jobs = exports.qbx_core:GetJobs()
    local gangs = exports.qbx_core:GetGangs()
    local groups = {}
    for k, v in pairs(jobs) do
        if v.type then
            local data = {
                value = k,
                label = v.label,
                grades = Utils.GetGroupGrades(v)
            }
            if named then
                groups[k] = data
            else
                groups[#groups + 1] = data
            end
        end
    end
    for k, v in pairs(gangs) do
        if not (k == "none") then
            local data = {
                value = k,
                label = v.label,
                grades = Utils.GetGroupGrades(v)
            }
            if named then
                groups[k] = data
            else
                groups[#groups + 1] = data
            end
        end
    end
    return groups
end

function Utils.GetGroupsLabel(groups)
    local baseGroups = Utils.GetBaseGroups(true)
    local groupName = ""
    for i = 1, #(groups) do
        local group = locale("error.group_not_found", groups[i])
        if baseGroups[groups[i]] then
            group = baseGroups[groups[i]]["label"]
        end
        if groupName == "" then
            groupName = group
        else
            groupName = groupName .. ", " .. group
        end
    end
    groupName = groupName == "" and locale("creator.no_group") or groupName
    return groupName
end

function Utils.GetBaseItems()
    local items = {}
    for k, v in pairs(exports.ox_inventory:Items()) do
        items[#items + 1] = {
            value = k,
            label = string.format("%s (%s)", v.label, k)
        }
    end
    return items
end

function Utils.GetItemMetadata(item, hideSpawn)
    local result = {}
    if not hideSpawn then
        result[#result + 1] = {
            label = locale("items.spawn"),
            value = item.name
        }
    end
    if item.weight then
        result[#result + 1] = {
            label = locale("items.weight"),
            value = item.weight
        }
    end
    if item.type then
        result[#result + 1] = {
            label = locale("items.type"),
            value = item.type
        }
    end
    return result
end

function Utils.GetMetadataFromFarm(key)
    local data = {}
    local items = Farms[key].config.items
    for k, v in pairs(items) do
        if Items[k] then
            data[#data + 1] = {
                label = locale("menus.route"),
                value = string.format("%s (%s)", Items[k].label, k)
            }
        end
    end
    if #data <= 0 then
        return {
            {
                label = locale("menus.route"),
                value = locale("menus.no_route")
            }
        }
    end
    return data
end

function Utils.GetDefaultAnim(useEmoteMenu)
    if not useEmoteMenu then
        return DefaultAnim
    end
    return DefaultAnimCmd
end

function Utils.SendNotification(data)
    lib.notify(
        {
            id = data["id"] or nil,
            title = data["title"] or nil,
            description = data["description"] or nil,
            type = data["type"] or "info"
        }
    )
end

function Utils.DrawText3D(x, y, z, text)
    local onScreen, _x, _y = World3dToScreen2d(x, y, z)
    local px, py, pz = table.unpack(GetGameplayCamCoords())
    local dist = #(vector3(px, py, pz) - vector3(x, y, z))
    local scale = (1 / dist) * 2
    local fov = (1 / GetGameplayCamFov()) * 100
    scale = scale * fov
    if onScreen then
        SetTextScale(0.0, 0.35 * scale)
        SetTextFont(4)
        SetTextProportional(true)
        SetTextColour(255, 255, 255, 215)
        SetTextEntry("STRING")
        SetTextCentre(true)
        AddTextComponentString(text)
        DrawText(_x, _y)
        local factor = (string.len(text)) / 370
        DrawRect(_x, _y + 0.0125, 0.015 + factor, 0.03, 41, 11, 41, 100)
    end
end

function Utils.EnsureSequence(tbl)
    if not tbl then return {} end
    if type(tbl) ~= "table" then return tbl end
    
    local keys = {}
    local isDictionary = false
    local count = 0
    
    for k, v in pairs(tbl) do
        count = count + 1
        if type(k) == "string" and tonumber(k) then
            isDictionary = true
        end
        table.insert(keys, k)
    end
    
    if isDictionary or #tbl ~= count then
        local newTbl = {}
        -- Sort keys if they are numeric or strings of numbers
        table.sort(keys, function(a, b)
            local na, nb = tonumber(a), tonumber(b)
            if na and nb then return na < nb end
            return tostring(a) < tostring(b)
        end)
        
        for _, k in ipairs(keys) do
            table.insert(newTbl, tbl[k])
        end
        return newTbl
    end
    
    return tbl
end

return Utils
