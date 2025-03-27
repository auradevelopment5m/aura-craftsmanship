local QBCore = exports['qb-core']:GetCoreObject()

local function CheckVersion()
    lib.versionCheck('auradevelopment5m/aura-craftsmanship')
end

CheckVersion()

local ServerState = {
    activeSessions = {},
    sessionTimeout = 30000, 
}

local function CreateCraftingSession(source, ingredients, sessionId)
    local src = tonumber(source)
    if not src then return nil end
    
    local sessionId = sessionId or tostring(GetGameTimer())
    
    ServerState.activeSessions[sessionId] = {
        playerId = src,
        ingredients = ingredients,
        timestamp = GetGameTimer(),
        validated = false
    }
    
    if Config.Debug then
        print("^2Created session " .. sessionId .. " for player " .. src .. "^7")
    end
    
    SetTimeout(ServerState.sessionTimeout, function()
        if ServerState.activeSessions[sessionId] then
            if Config.Debug then
                print("^3Session " .. sessionId .. " timed out^7")
            end
            ServerState.activeSessions[sessionId] = nil
        end
    end)
    
    return sessionId
end

lib.callback.register('aura-craftsmanship:getRecyclingLevel', function(source)
    local src = tonumber(source)
    if not src then return 0 end
    
    if not Config.UseSkillSystem then
        return Config.DefaultLevel
    end
    
    local level = exports['aura-skills']:GetSkillLevelSafe(src, 'civilian', 'recycling')
    
    if Config.Debug then
        print("^3Player " .. src .. " recycling level: " .. tostring(level) .. "^7")
    end
    
    if type(level) ~= 'number' then
        print("^1WARNING: Invalid recycling level type returned for player " .. src .. ": " .. type(level) .. "^7")
        return 0
    end
    
    return level
end)

lib.callback.register('aura-craftsmanship:hasRequiredItems', function(source, ingredients)
    local src = tonumber(source)
    if not src then return false, {} end
    
    if type(ingredients) ~= 'table' or #ingredients == 0 then
        return false, {}
    end
    
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return false, {} end
    
    local hasItems = true
    local missingItems = {}
    
    for _, ingredient in ipairs(ingredients) do
        if not ingredient.item or not ingredient.amount or 
           type(ingredient.amount) ~= 'number' or ingredient.amount <= 0 then
            return false, {}
        end
        
        local item = Player.Functions.GetItemByName(ingredient.item)
        
        if not item or item.amount < ingredient.amount then
            hasItems = false
            local missingAmount = ingredient.amount
            if item then
                missingAmount = ingredient.amount - item.amount
            end
            missingItems[ingredient.item] = missingAmount
        end
    end
    
    return hasItems, missingItems
end)

lib.callback.register('aura-craftsmanship:validateCrafting', function(source, ingredients, sessionId)
    local src = tonumber(source)
    if not src then return false, {} end
    
    if Config.Debug then
        print("^2Validating crafting for player " .. src .. " with session ID: " .. tostring(sessionId) .. "^7")
    end
    
    if type(ingredients) ~= 'table' or #ingredients == 0 then
        return false, {}
    end
    
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return false, {} end
    
    local hasItems = true
    local missingItems = {}
    
    for _, ingredient in ipairs(ingredients) do
        if not ingredient.item or not ingredient.amount or 
           type(ingredient.amount) ~= 'number' or ingredient.amount <= 0 then
            return false, {}
        end
        
        local item = Player.Functions.GetItemByName(ingredient.item)
        
        if not item or item.amount < ingredient.amount then
            hasItems = false
            local missingAmount = ingredient.amount
            if item then
                missingAmount = ingredient.amount - item.amount
            end
            missingItems[ingredient.item] = missingAmount
        end
    end
    
    if hasItems and sessionId then
        CreateCraftingSession(src, ingredients, sessionId)
        
        if Config.Debug then
            print("^2Session " .. sessionId .. " created/updated for player " .. src .. "^7")
        end
    end
    
    return hasItems, missingItems
end)

lib.callback.register('aura-craftsmanship:completeCrafting', function(source, itemName, amount, ingredients, xpReward, sessionId)
    local src = tonumber(source)
    if not src then 
        if Config.Debug then print("^1Invalid source in completeCrafting^7") end
        return false 
    end
    
    if Config.Debug then
        print("^2Completing crafting for player " .. src .. " with session ID: " .. tostring(sessionId) .. "^7")
        print("^2Active sessions: " .. json.encode(ServerState.activeSessions) .. "^7")
    end
    
    if not sessionId or not ServerState.activeSessions[sessionId] then
        if Config.Debug then print("^1Invalid session ID: " .. tostring(sessionId) .. "^7") end
        return false
    end
    
    local session = ServerState.activeSessions[sessionId]
    
    if session.playerId ~= src then
        if Config.Debug then print("^1Session ownership mismatch: " .. session.playerId .. " vs " .. src .. "^7") end
        return false
    end
    
    if GetGameTimer() - session.timestamp > ServerState.sessionTimeout then
        if Config.Debug then print("^1Session expired^7") end
        ServerState.activeSessions[sessionId] = nil
        return false
    end
    
    if not itemName or not amount or type(amount) ~= 'number' or amount <= 0 or 
       not ingredients or type(ingredients) ~= 'table' or #ingredients == 0 or
       not xpReward or type(xpReward) ~= 'number' or xpReward < 0 then
        if Config.Debug then print("^1Invalid parameters in completeCrafting^7") end
        return false
    end
    
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then 
        if Config.Debug then print("^1Player not found: " .. src .. "^7") end
        return false 
    end
    
    if Config.Debug then
        print("^2Starting crafting transaction for player " .. src .. "^7")
        print("^2Item: " .. itemName .. ", Amount: " .. amount .. "^7")
    end
    
    if not QBCore.Shared.Items[itemName] then
        if Config.Debug then print("^1Item does not exist in shared items: " .. itemName .. "^7") end
        return false
    end
    
    local transaction = {
        success = true,
        removedItems = {},
        addedItems = {}
    }
    
    for _, ingredient in ipairs(ingredients) do
        local item = Player.Functions.GetItemByName(ingredient.item)
        if not item or item.amount < ingredient.amount then
            if Config.Debug then 
                print("^1Missing ingredient: " .. ingredient.item .. " - Required: " .. ingredient.amount .. ", Has: " .. (item and item.amount or 0) .. "^7") 
            end
            transaction.success = false
            break
        end
    end
    
    if transaction.success then
        for _, ingredient in ipairs(ingredients) do
            if Config.Debug then print("^2Removing " .. ingredient.amount .. "x " .. ingredient.item .. "^7") end
            
            local removed = Player.Functions.RemoveItem(ingredient.item, ingredient.amount)
            if removed then
                table.insert(transaction.removedItems, {
                    item = ingredient.item,
                    amount = ingredient.amount
                })
                TriggerClientEvent('qb-inventory:client:ItemBox', src, QBCore.Shared.Items[ingredient.item], "remove", ingredient.amount)
            else
                if Config.Debug then print("^1Failed to remove item: " .. ingredient.item .. "^7") end
                transaction.success = false
                break
            end
        end
    end
    
    if transaction.success then
        if Config.Debug then print("^2Adding " .. amount .. "x " .. itemName .. "^7") end
        
        local added = Player.Functions.AddItem(itemName, amount)
        if added then
            table.insert(transaction.addedItems, {
                item = itemName,
                amount = amount
            })
            TriggerClientEvent('qb-inventory:client:ItemBox', src, QBCore.Shared.Items[itemName], "add", amount)
            
            if Config.UseSkillSystem then
                if Config.Debug then print("^2Adding " .. xpReward .. " XP to recycling skill^7") end
                
                local xpSuccess = pcall(function()
                    exports['aura-skills']:AddSkillXP(src, 'civilian', 'recycling', xpReward)
                end)
                
                if not xpSuccess and Config.Debug then
                    print("^1Failed to add XP, but continuing with crafting^7")
                end
            end
            
            if Config.Debug then
                print("^2Player " .. src .. " successfully crafted " .. amount .. "x " .. itemName .. "^7")
            end
        else
            if Config.Debug then print("^1Failed to add crafted item: " .. itemName .. "^7") end
            transaction.success = false
        end
    end
    
    if not transaction.success and #transaction.removedItems > 0 then
        if Config.Debug then print("^3Transaction failed, rolling back items^7") end
        
        for _, item in ipairs(transaction.removedItems) do
            Player.Functions.AddItem(item.item, item.amount)
            TriggerClientEvent('qb-inventory:client:ItemBox', src, QBCore.Shared.Items[item.item], "add", item.amount)
        end
        
        if Config.Debug then
            print("^3Transaction rollback completed for player " .. src .. "^7")
        end
    end
    
    ServerState.activeSessions[sessionId] = nil
    
    if Config.Debug then
        print("^2Crafting transaction " .. (transaction.success and "succeeded" or "failed") .. " for player " .. src .. "^7")
    end
    
    return transaction.success
end)

lib.callback.register('aura-craftsmanship:cancelCrafting', function(source, sessionId)
    local src = tonumber(source)
    if not src then return false end
    
    if not sessionId or not ServerState.activeSessions[sessionId] then
        return false
    end
    
    local session = ServerState.activeSessions[sessionId]
    
    if session.playerId ~= src then
        print("^1WARNING: Player " .. src .. " tried to cancel another player's crafting session!^7")
        return false
    end
    
    ServerState.activeSessions[sessionId] = nil
    
    return true
end)

Citizen.CreateThread(function()
    while true do
        Wait(60000)
        
        local currentTime = GetGameTimer()
        
        for sessionId, session in pairs(ServerState.activeSessions) do
            if currentTime - session.timestamp > ServerState.sessionTimeout then
                ServerState.activeSessions[sessionId] = nil
            end
        end
    end
end)

AddEventHandler('onResourceStart', function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end
    
    print("^2" .. resourceName .. " started. Advanced crafting system initialized.^7")
end)

