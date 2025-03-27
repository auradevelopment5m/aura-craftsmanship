local QBCore = exports['qb-core']:GetCoreObject()

lib.locale()

local CraftingState = {
    zones = {},
    cachedRecipes = {},
    cachedLevels = {},
    levelCacheTTL = 60000,
}

local activeTargets = {}

local function GetPlayerRecyclingLevel()
    if not Config.UseSkillSystem then
        return Config.DefaultLevel
    end
    
    local currentTime = GetGameTimer()
    
    if CraftingState.cachedLevels.timestamp and 
       (currentTime - CraftingState.cachedLevels.timestamp) < CraftingState.levelCacheTTL then
        return CraftingState.cachedLevels.level
    end
    
    local level = lib.callback.await('aura-craftsmanship:getRecyclingLevel', false)
    
    CraftingState.cachedLevels = {
        level = level or 0,
        timestamp = currentTime
    }
    
    return level or 0
end

local function ValidateIngredients(ingredients)
    if type(ingredients) ~= 'table' or #ingredients == 0 then
        return false, {}
    end
    
    local hasItems, missingItems = lib.callback.await('aura-craftsmanship:hasRequiredItems', false, ingredients)
    return hasItems or false, missingItems or {}
end

local function InitializeBlips()
    CreateThread(function()
        for i, location in ipairs(Config.CraftingLocations) do
            if location and location.blip and location.blip.enabled then
                if type(location.coords) ~= 'vector3' and type(location.coords) ~= 'table' then
                    goto continue
                end
                
                local coords = type(location.coords) == 'vector3' and location.coords or 
                               vector3(location.coords.x, location.coords.y, location.coords.z)
                
                local blip = AddBlipForCoord(coords.x, coords.y, coords.z)
                
                pcall(function()
                    SetBlipSprite(blip, location.blip.sprite or 566)
                    SetBlipDisplay(blip, 4)
                    SetBlipScale(blip, location.blip.scale or 0.7)
                    SetBlipColour(blip, location.blip.color or 2)
                    SetBlipAsShortRange(blip, true)
                    BeginTextCommandSetBlipName("STRING")
                    AddTextComponentString(location.blip.label or locale('crafting_title'))
                    EndTextCommandSetBlipName(blip)
                end)
            end
            
            ::continue::
        end
    end)
end

local function InitializeZones()
    CreateThread(function()
        for i, location in ipairs(Config.CraftingLocations) do
            if not location or not location.coords then goto continue end
            
            local coords = type(location.coords) == 'vector3' and location.coords or 
                           vector3(location.coords.x, location.coords.y, location.coords.z)
            
            local size = type(location.size) == 'vector3' and location.size or 
                         vector3(location.size.x or 2.0, location.size.y or 2.0, location.size.z or 2.0)
            
            CraftingState.zones[i] = lib.zones.box({
                coords = coords,
                size = size,
                rotation = location.rotation or 0,
                debug = Config.Debug,
                
                inside = function()
                    lib.showTextUI(locale('open_crafting_menu'), {
                        position = "right-center",
                        icon = 'fas fa-tools'
                    })
                    
                    if IsControlJustReleased(0, 38) then
                        SetTimeout(100, function()
                            OpenCraftingMenu(location.id or i)
                        end)
                    end
                end,
                
                onExit = function()
                    lib.hideTextUI()
                end
            })
            
            ::continue::
        end
    end)
end

local function GetModelName(model)
    local hash = tonumber(model) or model
    return tostring(hash)
end

local function RemovePropTarget(index)
    if not activeTargets[index] then return false end
    
    local target = activeTargets[index]
    
    if target.system == "ox_target" then
        if exports.ox_target then
            exports.ox_target:removeModel(target.model, target.name)
        end
    elseif target.system == "qb-target" then
        if Config.Debug then
            print("^3Warning: qb-target doesn't support removing individual targets. Reinitializing all targets.^7")
        end
        InitializeQBTarget()
    elseif target.system == "textui" then
        target.active = false
    end
    
    activeTargets[index] = nil
    return true
end

local function AddPropTarget(index)
    if activeTargets[index] then return false end
    
    local prop = Config.TargetProps[index]
    if not prop or prop.enabled == false then return false end
    
    if Config.TargetSystem == "ox_target" then
        if exports.ox_target then
            local targetName = 'crafting_' .. index .. '_' .. prop.model
            
            exports.ox_target:addModel(prop.model, {
                {
                    name = targetName,
                    icon = prop.icon or 'fas fa-tools',
                    label = prop.label or 'Use Crafting Station',
                    distance = prop.distance or 2.0,
                    onSelect = function()
                        if prop.category then
                            OpenCraftingMenuForCategory(prop.category)
                        elseif prop.categories then
                            OpenCraftingMenuForCategories(prop.categories)
                        else
                            OpenCraftingMenu()
                        end
                    end
                }
            })
            
            activeTargets[index] = {
                system = "ox_target",
                name = targetName,
                model = prop.model
            }
            
            return true
        end
    elseif Config.TargetSystem == "qb-target" then
        if exports['qb-target'] then
            InitializeQBTarget()
            return true
        end
    elseif Config.TargetSystem == "textui" then
        activeTargets[1] = {
            system = "textui",
            active = true
        }
        return true
    end
    
    return false
end

function EnableProp(index, enabled)
    if not Config.TargetProps or not Config.TargetProps[index] then
        if Config.Debug then
            print("^1Invalid prop index: " .. tostring(index) .. "^7")
        end
        return false
    end
    
    Config.TargetProps[index].enabled = enabled
    
    if not enabled and activeTargets[index] then
        RemovePropTarget(index)
    end
    
    if enabled and not activeTargets[index] then
        AddPropTarget(index)
    end
    
    if Config.Debug then
        print("^2Prop " .. index .. " (" .. GetModelName(Config.TargetProps[index].model) .. ") " .. 
              (enabled and "enabled" or "disabled") .. "^7")
    end
    
    return true
end

function EnableAllProps(enabled)
    if Config.Debug then
        print("^2" .. (enabled and "Enabling" or "Disabling") .. " all props^7")
    end
    
    Config.EnablePropTargeting = enabled
    
    for i, prop in ipairs(Config.TargetProps) do
        Config.TargetProps[i].enabled = enabled
    end
    
    for index, _ in pairs(activeTargets) do
        RemovePropTarget(index)
    end
    
    if enabled then
        InitializeTargetProps()
    end
    
    return true
end

function IsPropEnabled(index)
    if not Config.EnablePropTargeting then
        return false
    end
    
    if not Config.TargetProps or not Config.TargetProps[index] then
        return false
    end
    
    return Config.TargetProps[index].enabled ~= false
end

local function InitializeOxTarget()
    if not exports.ox_target then
        if Config.Debug then
            print("^1ox_target not found^7")
        end
        return
    end
    
    for i, prop in ipairs(Config.TargetProps) do
        if prop.enabled == false then
            if Config.Debug then
                print("^3Skipping disabled prop: " .. GetModelName(prop.model) .. "^7")
            end
            goto continue
        end
        
        local targetName = 'crafting_' .. i .. '_' .. prop.model
        
        exports.ox_target:addModel(prop.model, {
            {
                name = targetName,
                icon = prop.icon or 'fas fa-tools',
                label = prop.label or 'Use Crafting Station',
                distance = prop.distance or 2.0,
                onSelect = function()
                    if prop.category then
                        OpenCraftingMenuForCategory(prop.category)
                    elseif prop.categories then
                        OpenCraftingMenuForCategories(prop.categories)
                    else
                        OpenCraftingMenu()
                    end
                end
            }
        })
        
        activeTargets[i] = {
            system = "ox_target",
            name = targetName,
            model = prop.model
        }
        
        ::continue::
    end
end

local function InitializeQBTarget()
    if not exports['qb-target'] then
        if Config.Debug then
            print("^1qb-target not found^7")
        end
        return
    end
    
    for i, prop in ipairs(Config.TargetProps) do
        if prop.enabled == false then
            if Config.Debug then
                print("^3Skipping disabled prop: " .. GetModelName(prop.model) .. "^7")
            end
            goto continue
        end
        
        local targetName = 'crafting_' .. i .. '_' .. prop.model
        
        exports['qb-target']:AddTargetModel(prop.model, {
            options = {
                {
                    type = "client",
                    icon = prop.icon or 'fas fa-tools',
                    label = prop.label or 'Use Crafting Station',
                    action = function()
                        if prop.category then
                            OpenCraftingMenuForCategory(prop.category)
                        elseif prop.categories then
                            OpenCraftingMenuForCategories(prop.categories)
                        else
                            OpenCraftingMenu()
                        end
                    end
                }
            },
            distance = prop.distance or 2.0
        })
        
        activeTargets[i] = {
            system = "qb-target",
            name = targetName,
            model = prop.model
        }
        
        ::continue::
    end
end

local function InitializeTextUITarget()
    CreateThread(function()
        while true do
            local sleep = 1000
            local playerPed = PlayerPedId()
            local playerCoords = GetEntityCoords(playerPed)
            local nearbyProp = nil
            local minDistance = 10.0
            
            for _, prop in ipairs(Config.TargetProps) do
                if prop.enabled == false then
                    goto continue
                end
                
                local propDistance = prop.distance or 2.0
                
                local closestProp = GetClosestObjectOfType(
                    playerCoords.x, playerCoords.y, playerCoords.z,
                    propDistance + 1.0, prop.model, false, false, false
                )
                
                if closestProp and closestProp ~= 0 then
                    local propCoords = GetEntityCoords(closestProp)
                    local distance = #(playerCoords - propCoords)
                    
                    if distance < propDistance and distance < minDistance then
                        nearbyProp = prop
                        minDistance = distance
                        sleep = 0
                    end
                end
                
                ::continue::
            end
            
            if nearbyProp then
                lib.showTextUI(string.format('[E] %s', nearbyProp.label or 'Use Crafting Station'), {
                    position = "right-center",
                    icon = nearbyProp.icon or 'fas fa-tools'
                })
                
                if IsControlJustReleased(0, 38) then
                    lib.hideTextUI()
                    
                    if nearbyProp.category then
                        OpenCraftingMenuForCategory(nearbyProp.category)
                    elseif nearbyProp.categories then
                        OpenCraftingMenuForCategories(nearbyProp.categories)
                    else
                        OpenCraftingMenu()
                    end
                    
                    Wait(500)
                end
            else
                lib.hideTextUI()
            end
            
            Wait(sleep)
        end
    end)
    
    activeTargets[1] = {
        system = "textui",
        active = true
    }
end

local function InitializeTargetProps()
    if not Config.EnablePropTargeting then
        if Config.Debug then
            print("^3Prop targeting is disabled globally^7")
        end
        return
    end
    
    if Config.TargetProps and #Config.TargetProps > 0 then
        if Config.Debug then
            print("^2Initializing prop targeting with " .. Config.TargetSystem .. " system^7")
        end
        
        if Config.TargetSystem == "ox_target" then
            InitializeOxTarget()
        elseif Config.TargetSystem == "qb-target" then
            InitializeQBTarget()
        elseif Config.TargetSystem == "textui" then
            InitializeTextUITarget()
        else
            if Config.Debug then
                print("^1Unknown target system: " .. tostring(Config.TargetSystem) .. "^7")
            end
        end
    end
end

local function GenerateRecipeOptions(categoryId, playerLevel)
    local cacheKey = categoryId .. '_' .. playerLevel
    if CraftingState.cachedRecipes[cacheKey] then
        return CraftingState.cachedRecipes[cacheKey]
    end
    
    local options = {}
    local validRecipes = 0
    
    for _, recipe in ipairs(Config.Recipes) do
        if not recipe or recipe.category ~= categoryId then goto continue end
        
        if not recipe.name or not recipe.label or not recipe.ingredients or 
           not recipe.requiredLevel or not recipe.time or not recipe.xpReward then
            goto continue
        end
        
        validRecipes = validRecipes + 1
        
        local canCraftLevel = Config.UseSkillSystem and playerLevel >= recipe.requiredLevel or true
        
        local hasItems, missingItems = ValidateIngredients(recipe.ingredients)
        
        local ingredientText = locale('ingredients')
        for _, ingredient in ipairs(recipe.ingredients) do
            local hasIngredient = not missingItems or not missingItems[ingredient.item]
            local statusSymbol = hasIngredient and "✓" or "✗"
            ingredientText = ingredientText .. "\n• " .. ingredient.amount .. "x " .. ingredient.item .. " " .. statusSymbol
        end
        
        ingredientText = ingredientText .. "\n" .. locale('crafting_time', math.floor((recipe.time / 1000) * 10) / 10)
        
        if Config.UseSkillSystem then
            ingredientText = ingredientText .. "\n" .. locale('xp_reward', recipe.xpReward)
        end
        
        local canCraft = canCraftLevel and hasItems
        
        local statusText = ""
        if Config.UseSkillSystem and not canCraftLevel then
            statusText = locale('requires_level', recipe.requiredLevel)
            ingredientText = statusText .. "\n\n" .. ingredientText
        elseif not hasItems then
            statusText = locale('missing_ingredients')
            ingredientText = statusText .. "\n\n" .. ingredientText
        else
            statusText = locale('ready_to_craft')
            ingredientText = statusText .. "\n\n" .. ingredientText
        end
        
        local metadataTable = {
            {label = locale('crafting_time'), value = (recipe.time / 1000) .. 's'}
        }
        
        if Config.UseSkillSystem then
            table.insert(metadataTable, 1, {label = locale('required_level'), value = recipe.requiredLevel})
        end
        
        table.insert(options, {
            title = recipe.label,
            description = ingredientText,
            icon = canCraft and "fas fa-check" or "fas fa-lock",
            iconColor = canCraft and "#2ecc71" or "#e74c3c",
            image = "nui://ox_inventory/web/images/" .. recipe.name .. ".png",
            onSelect = function()
                if canCraft then
                    InitiateCraftingProcess(recipe)
                elseif Config.UseSkillSystem and not canCraftLevel then
                    lib.notify({
                        title = locale('crafting_title'),
                        description = locale('level_requirement', recipe.requiredLevel),
                        type = 'error'
                    })
                else
                    local missingText = locale('missing_items')
                    for item, amount in pairs(missingItems) do
                        missingText = missingText .. "\n• " .. amount .. "x " .. item
                    end
                    
                    lib.notify({
                        title = locale('crafting_title'),
                        description = missingText,
                        type = 'error'
                    })
                end
            end,
            disabled = not canCraft,
            metadata = metadataTable
        })
        
        ::continue::
    end
    
    if validRecipes > 0 then
        CraftingState.cachedRecipes[cacheKey] = options
    end
    
    return options
end

function OpenCraftingMenu(locationId)
    local playerLevel = GetPlayerRecyclingLevel()
    
    local mainOptions = {}
    local validCategories = 0
    
    for categoryId, category in pairs(Config.Categories) do
        if not category or not category.label then goto continue end
        
        if locationId and Config.LocationCategories and Config.LocationCategories[locationId] then
            local found = false
            for _, catId in ipairs(Config.LocationCategories[locationId]) do
                if catId == categoryId then
                    found = true
                    break
                end
            end
            if not found then goto continue end
        end
        
        local categoryOptions = GenerateRecipeOptions(categoryId, playerLevel)
        
        if #categoryOptions > 0 then
            validCategories = validCategories + 1
            
            local metadataTable = {}
            if Config.UseSkillSystem then
                metadataTable = {
                    {label = locale('your_recycling_level'), value = playerLevel}
                }
            end
            
            table.insert(mainOptions, {
                title = category.label,
                description = locale('browse_recipes', category.label),
                icon = category.icon or "fas fa-hammer",
                menu = 'crafting_' .. categoryId,
                metadata = metadataTable
            })
            
            lib.registerContext({
                id = 'crafting_' .. categoryId,
                title = category.label .. ' ' .. locale('crafting_title'),
                menu = 'crafting_main',
                options = categoryOptions
            })
        end
        
        ::continue::
    end
    
    if validCategories > 0 then
        lib.registerContext({
            id = 'crafting_main',
            title = locale('crafting_menu'),
            options = mainOptions
        })
        
        lib.showContext('crafting_main')
    else
        lib.notify({
            title = locale('crafting_title'),
            description = locale('no_recipes_available'),
            type = 'error'
        })
    end
end

function OpenCraftingMenuForCategory(category)
    local playerLevel = GetPlayerRecyclingLevel()
    
    local categoryData = Config.Categories[category]
    if not categoryData then
        if Config.Debug then
            print("^1Category not found: " .. tostring(category) .. "^7")
        end
        return
    end
    
    local categoryOptions = GenerateRecipeOptions(category, playerLevel)
    
    if #categoryOptions > 0 then
        local metadataTable = {}
        if Config.UseSkillSystem then
            metadataTable = {
                {label = locale('your_recycling_level'), value = playerLevel}
            }
        end
        
        lib.registerContext({
            id = 'crafting_category_' .. category,
            title = categoryData.label .. ' ' .. locale('crafting_title'),
            options = categoryOptions,
            metadata = metadataTable
        })
        
        lib.showContext('crafting_category_' .. category)
    else
        lib.notify({
            title = locale('crafting_title'),
            description = locale('no_recipes_available'),
            type = 'error'
        })
    end
end

function OpenCraftingMenuForCategories(categories)
    local playerLevel = GetPlayerRecyclingLevel()
    
    local mainOptions = {}
    local validCategories = 0
    
    for _, categoryId in ipairs(categories) do
        local category = Config.Categories[categoryId]
        
        if not category or not category.label then goto continue end
        
        local categoryOptions = GenerateRecipeOptions(categoryId, playerLevel)
        
        if #categoryOptions > 0 then
            validCategories = validCategories + 1
            
            local metadataTable = {}
            if Config.UseSkillSystem then
                metadataTable = {
                    {label = locale('your_recycling_level'), value = playerLevel}
                }
            end
            
            table.insert(mainOptions, {
                title = category.label,
                description = locale('browse_recipes', category.label),
                icon = category.icon or "fas fa-hammer",
                menu = 'crafting_' .. categoryId,
                metadata = metadataTable
            })
            
            lib.registerContext({
                id = 'crafting_' .. categoryId,
                title = category.label .. ' ' .. locale('crafting_title'),
                menu = 'crafting_filtered_main',
                options = categoryOptions
            })
        end
        
        ::continue::
    end
    
    if validCategories > 0 then
        lib.registerContext({
            id = 'crafting_filtered_main',
            title = locale('crafting_menu'),
            options = mainOptions
        })
        
        lib.showContext('crafting_filtered_main')
    else
        lib.notify({
            title = locale('crafting_title'),
            description = locale('no_recipes_available'),
            type = 'error'
        })
    end
end

function InitiateCraftingProcess(recipe)
    if not recipe or not recipe.name or not recipe.label or not recipe.ingredients or 
       not recipe.time or not recipe.amount or not recipe.xpReward then
        return
    end
    
    local craftingSessionId = tostring(GetGameTimer())
    
    if Config.Debug then
        print("Generated session ID: " .. craftingSessionId)
    end
    
    local hasItems, missingItems = lib.callback.await('aura-craftsmanship:validateCrafting', false, 
        recipe.ingredients, craftingSessionId)
    
    if hasItems then
        local animDict = "mini@repair"
        local animName = "fixing_a_ped"
        
        RequestAnimDict(animDict)
        local timeout = GetGameTimer() + 5000
        while not HasAnimDictLoaded(animDict) and GetGameTimer() < timeout do
            Wait(100)
        end
        
        if lib.progressBar({
            duration = recipe.time,
            label = locale('crafting_progress', recipe.label),
            useWhileDead = false,
            canCancel = true,
            disable = {
                car = true,
                move = true,
                combat = true,
            },
            anim = {
                dict = animDict,
                clip = animName
            },
        }) then
            if Config.Debug then
                print("Progress bar completed, calling completeCrafting with session ID: " .. craftingSessionId)
            end
            
            local craftSuccess = lib.callback.await('aura-craftsmanship:completeCrafting', false, 
                recipe.name, recipe.amount, recipe.ingredients, recipe.xpReward, craftingSessionId)
            
            if craftSuccess then
                lib.notify({
                    title = locale('crafting_title'),
                    description = locale('crafting_success', recipe.amount, recipe.label),
                    type = 'success'
                })
                
                CraftingState.cachedRecipes = {}
            else
                if Config.Debug then
                    print("Crafting failed in server callback")
                end
                
                lib.notify({
                    title = locale('crafting_title'),
                    description = locale('crafting_failed'),
                    type = 'error'
                })
            end
        else
            lib.callback.await('aura-craftsmanship:cancelCrafting', false, craftingSessionId)
            
            lib.notify({
                title = locale('crafting_title'),
                description = locale('crafting_cancelled'),
                type = 'error'
            })
        end
    else
        local missingText = locale('missing_items')
        for item, amount in pairs(missingItems or {}) do
            missingText = missingText .. "\n• " .. amount .. "x " .. item
        end
        
        lib.notify({
            title = locale('crafting_title'),
            description = missingText,
            type = 'error'
        })
    end
end

CreateThread(function()
    Wait(1000)
    
    local success, error = pcall(function()
        InitializeBlips()
        InitializeZones()
        
        if Config.EnablePropTargeting then
            InitializeTargetProps()
        else
            if Config.Debug then
                print("^3Prop targeting is disabled globally^7")
            end
        end
    end)
    
    if not success and Config.Debug then
        print("^1Error initializing crafting system: " .. tostring(error) .. "^7")
    end
end)

AddEventHandler('onResourceStop', function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end
    
    for _, zone in pairs(CraftingState.zones) do
        if zone and zone.remove then
            zone:remove()
        end
    end
    
    lib.hideTextUI()
end)

exports('EnableProp', EnableProp)
exports('EnableAllProps', EnableAllProps)
exports('IsPropEnabled', IsPropEnabled)
exports('OpenCraftingMenu', OpenCraftingMenu)
exports('OpenCraftingMenuForCategory', OpenCraftingMenuForCategory)
exports('OpenCraftingMenuForCategories', OpenCraftingMenuForCategories)

