--[[
    Aura Free Crafting System Configuration
    
    This file contains all the configuration options for the crafting system.
    You can customize locations, categories, recipes, and skill system settings.
]]

Config = {}

-- ============================
-- SKILL SYSTEM CONFIGURATION
-- ============================
-- Controls whether the crafting system uses the skill-based progression
Config.UseSkillSystem = false -- Set to false to disable the skill system (You can purchase the skill system here: https://auradevelopment.tebex.io/package/6721231)
Config.DefaultLevel = 0 -- Default level when skill system is disabled (0 means no level requirements for any recipes)

-- ============================
-- CRAFTING LOCATIONS
-- ============================
-- Define where players can access the crafting system in the world
Config.CraftingLocations = {
    {
        coords = vec3(-583.83, -1623.77, 33.01), -- Coordinates where the crafting zone will be placed
        size = vector3(2.0, 2.0, 2.0), -- Size of the box zone (width, length, height)
        rotation = 0, -- Rotation of the box zone in degrees
        radius = 3.0, -- Alternative radius for legacy systems (not used with box zones)
        blip = { -- Map blip configuration
            enabled = false, -- Whether to show a blip on the map for this location
            sprite = 365, -- The icon to use for the blip (see: https://docs.fivem.net/docs/game-references/blips/)
            color = 2, -- The color of the blip (2 = green)
            scale = 0.8, -- Size of the blip on the map
            label = "Recycling & Crafting" -- Text that appears when hovering over the blip
        }
    }
    -- You can add more locations by copying this structure
}


-- ============================
-- PROP TARGETING CONFIGURATION
-- ============================
-- Define props that can be targeted to open the crafting menu
-- Define props that can be targeted to open the crafting menu
Config.TargetProps = {
    -- Example prop configuration
    {
        model = `prop_toolchest_01`, -- Model hash of the prop (use backticks)
        label = "Toolbox", -- Label to display when targeting
        icon = "fas fa-tools", -- Icon to display when targeting
        distance = 2.0, -- Maximum distance to interact with the prop
        category = "tools", -- Optional: specific category to open (leave nil to show all categories)
        enabled = true -- Whether this prop is enabled for targeting
    },
    {
        model = `prop_tool_bench02`, -- Workbench
        label = "Workbench",
        icon = "fas fa-hammer",
        distance = 2.5,
        categories = {"tools", "weapons"}, -- Optional: multiple specific categories
        enabled = true
    },
    {
        model = `prop_medstation_01`, -- Medical station
        label = "Medical Station",
        icon = "fas fa-kit-medical",
        distance = 2.0,
        category = "medical",
        enabled = false -- This prop is disabled by default
    },
    {
        model = `prop_elecbox_01a`, -- Electronics box
        label = "Electronics Workstation",
        icon = "fas fa-microchip",
        distance = 2.0,
        category = "electronics",
        enabled = true
    }
    -- Add more props as needed
}

Config.EnablePropTargeting = true -- Master switch for all prop targeting
-- Target system to use
Config.TargetSystem = "ox_target" -- Options: "ox_target", "qb-target", "textui"

-- ============================
-- CRAFTING CATEGORIES
-- ============================
-- Categories organize recipes in the crafting menu
Config.Categories = {
    ["tools"] = {
        label = "Tools", -- Display name in the menu
        icon = "fas fa-tools" -- FontAwesome icon (refer to https://fontawesome.com/icons)
    },
    ["weapons"] = {
        label = "Weapons",
        icon = "fas fa-gun"
    },
    ["electronics"] = {
        label = "Electronics",
        icon = "fas fa-microchip"
    },
    ["medical"] = {
        label = "Medical",
        icon = "fas fa-kit-medical"
    }
    -- Add more categories as needed
}

-- ============================
-- CRAFTING RECIPES
-- ============================
-- Define all craftable items, their requirements, and rewards
Config.Recipes = {
    -- Tools Category
    {
        name = "lockpick", -- Item spawn code (must match the item name in your inventory system)
        label = "Lockpick", -- Display name in the crafting menu
        category = "tools", -- Which category this recipe belongs to (must match a category key above)
        requiredLevel = 1, -- Minimum recycling skill level required (ignored if UseSkillSystem = false)
        ingredients = { -- Materials required to craft this item
            {item = "metalscrap", amount = 4}, -- Each ingredient needs an item name and amount
            {item = "plastic", amount = 2}
        },
        time = 5000, -- Time in milliseconds it takes to craft (5000 = 5 seconds)
        amount = 1, -- How many of this item are produced per craft
        xpReward = 1 -- Experience points awarded for crafting (only if skill system is enabled)
    },
    {
        name = "advancedlockpick",
        label = "Advanced Lockpick",
        category = "tools",
        requiredLevel = 3,
        ingredients = {
            {item = "metalscrap", amount = 7},
            {item = "plastic", amount = 3},
            {item = "rubber", amount = 2}
        },
        time = 8000, -- 8 seconds
        amount = 1,
        xpReward = 2
    },
    {
        name = "screwdriverset",
        label = "Screwdriver Set",
        category = "tools",
        requiredLevel = 2,
        ingredients = {
            {item = "metalscrap", amount = 5},
            {item = "plastic", amount = 2}
        },
        time = 6000, -- 6 seconds
        amount = 1,
        xpReward = 1
    },
    {
        name = "drill",
        label = "Drill",
        category = "tools",
        requiredLevel = 5,
        ingredients = {
            {item = "metalscrap", amount = 10},
            {item = "plastic", amount = 5},
            {item = "electronic", amount = 3}
        },
        time = 12000, -- 12 seconds
        amount = 1,
        xpReward = 3
    },
    
    -- Weapons Category
    {
        name = "weapon_knife",
        label = "Knife",
        category = "weapons",
        requiredLevel = 4,
        ingredients = {
            {item = "metalscrap", amount = 8},
            {item = "steel", amount = 5}
        },
        time = 10000, -- 10 seconds
        amount = 1,
        xpReward = 2
    },
    {
        name = "pistol_ammo",
        label = "Pistol Ammo",
        category = "weapons",
        requiredLevel = 7, 
        ingredients = {
            {item = "metalscrap", amount = 10},
            {item = "steel", amount = 5},
            {item = "gunpowder", amount = 3}
        },
        time = 15000, -- 15 seconds
        amount = 10, -- Creates 10 ammo at once
        xpReward = 4
    },
    
    -- Electronics Category
    {
        name = "phone",
        label = "Phone",
        category = "electronics",
        requiredLevel = 6,
        ingredients = {
            {item = "electronics", amount = 8},
            {item = "plastic", amount = 4},
            {item = "glass", amount = 2}
        },
        time = 12000, -- 12 seconds
        amount = 1,
        xpReward = 3
    },
    {
        name = "radio",
        label = "Radio",
        category = "electronics",
        requiredLevel = 8,
        ingredients = {
            {item = "electronics", amount = 10},
            {item = "plastic", amount = 5},
            {item = "steel", amount = 3}
        },
        time = 14000, -- 14 seconds
        amount = 1,
        xpReward = 4
    },
    
    {
        name = "advancedradio",
        label = "Enhanced Radio",
        category = "electronics",
        requiredLevel = 10, -- Max level requirement
        ingredients = {
            {item = "electronics", amount = 115},
            {item = "plastic", amount = 15},
            {item = "steel", amount = 45},
            {item = "radiochip", amount = 1},
        },
        time = 14000, -- 14 seconds
        amount = 1,
        xpReward = 4
    },

    -- Medical Category
    {
        name = "bandage",
        label = "Bandage",
        category = "medical",
        requiredLevel = 2,
        ingredients = {
            {item = "cloth", amount = 3}
        },
        time = 4000, -- 4 seconds (simple item)
        amount = 2, -- Creates 2 bandages at once
        xpReward = 1
    },
    {
        name = "firstaid",
        label = "First Aid Kit",
        category = "medical",
        requiredLevel = 10, -- High level requirement
        ingredients = {
            {item = "cloth", amount = 5},
            {item = "plastic", amount = 2},
            {item = "aluminum", amount = 1}
        },
        time = 10000, -- 10 seconds
        amount = 1,
        xpReward = 5 -- Highest XP reward
    }
    
    -- You can add more recipes by following this format
}

-- ============================
-- ADVANCED SETTINGS
-- ============================
-- Enable debug mode to see additional console output for troubleshooting
Config.Debug = false -- Set to false in production to reduce console spam

-- Optional: You can add location-specific categories
-- This restricts which categories are available at specific locations
-- Example:
-- Config.LocationCategories = {
--     [1] = {"tools", "electronics"}, -- First location only has tools and electronics
--     [2] = {"weapons", "medical"}    -- Second location only has weapons and medical
-- }