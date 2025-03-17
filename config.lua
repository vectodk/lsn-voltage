Config = {}

Config.Debug = false -- Enables debugging mode (true/false). If enabled, debug messages will be printed.

Config.buyPrice = 75000 -- Price to buy the wind turbine.
Config.repairCostPerPercent = 100 -- Repair cost per percent of damage.

Config.energyItemName = 'battery'

Config.allowSabotage = true  -- if true, people will be able to steal energy of Windmills
Config.mainHackingTool = 'CHANGE-ME' -- Item thats needs to be used next to a windmill
Config.secondHackingTool = 'CHANGE-ME' -- Item thats needs to be in the inventory for it to work
Config.hackingDifficulty = {'easy', 'easy', 'medium'} -- possible: 'easy', 'medium', 'hard'
Config.hackingKeys = {'w', 'a', 's', 'd'} -- Legit every Key out there lul
Config.policeAlertType = 'server' -- 'client' or 'server'   --> This will either use the client(ps-dispatch) or server(default qbx_police one) sided police function

Config.priceForEnergy = math.random(100, 150) -- Price for Energy per MWh.
Config.priceForOverflowEnergy = math.random(25, 50) -- Price for Overflowing Energy per MWh ( should be bad ).

Config.MinProduction = 1 -- Minimum energy production per cycle.
Config.MaxProduction = 5 -- Maximum energy production per cycle.
Config.EnergyMultiplier = 2 -- Multiplier for energy production efficiency.

Config.DefaultStorage = 250 -- Default maximum energy storage capacity.

Config.WindTurbine = {
    ["prop_windmill_01"] = true -- Defines the valid wind turbine prop model.
}

Config.Upgrades = {
    durability = { -- Increases the maximum durability.
        [0] = { -- KEEP 0 LIKE THIS
            cost = 0,  -- KEEP 0 LIKE THIS
            effect = 0,  -- KEEP 0 LIKE THIS
        },
        [1] = {
            cost = 10000, -- Cost for Level 1 upgrade.
            effect = 25, -- Durability increase (+25).
        },
        [2] = {
            cost = 20000, -- Cost for Level 2 upgrade.
            effect = 50, -- Durability increase (+50).
        },
        [3] = {
            cost = 40000, -- Cost for Level 3 upgrade.
            effect = 100, -- Durability increase (+100).
        }
    },
    efficiency = { -- Increases production speed/effectiveness.
        [0] = { -- KEEP 0 LIKE THIS
            cost = 0,  -- KEEP 0 LIKE THIS
            effect = 1.0,  -- KEEP 0 LIKE THIS
        },
        [1] = {
            cost = 7500, -- Cost for Level 1 upgrade.
            effect = 1.25, -- Efficiency boost (+25% faster energy generation).
        },
        [2] = {
            cost = 15000, -- Cost for Level 2 upgrade.
            effect = 1.5, -- Efficiency boost (+50%).
        },
        [3] = {
            cost = 30000, -- Cost for Level 3 upgrade.
            effect = 2.0, -- Efficiency boost (+100%).
        }
    },
    max_capacity = { -- Increases maximum energy storage capacity.
        [0] = {  -- KEEP 0 LIKE THIS
            cost = 0,  -- KEEP 0 LIKE THIS 
            effect = 0,  -- KEEP 0 LIKE THIS
        },
        [1] = {
            cost = 7500, -- Cost for Level 1 upgrade.
            effect = 100, -- Increases max capacity by 100 units.
        },
        [2] = {
            cost = 15000, -- Cost for Level 2 upgrade.
            effect = 250, -- Increases max capacity by 250 units.
        },
        [3] = {
            cost = 30000, -- Cost for Level 3 upgrade.
            effect = 500, -- Increases max capacity by 500 units.
        }
    },
    security = { -- This will decrease the rob amount and increase the Police Call chance.
        [0] = {  -- KEEP 0 LIKE THIS
            cost = 0,  -- KEEP 0 LIKE THIS
            effect = 0.75, -- Takes 75% for each rob
            callChance = 10 -- 10% police call chance
        },
        [1] = {
            cost = 50000, -- Cost for Level 1 upgrade.
            effect = 0.5,  -- Takes 50% for each rob
            callChance = 25 -- 25% police call chance
        },
        [2] = {
            cost = 75000, -- Cost for Level 2 upgrade.
            effect = 0.25,   -- Takes 25% for each rob
            callChance = 50 -- 50% police call chance
        },
        [3] = {
            cost = 100000, -- Cost for Level 3 upgrade.
            effect = 0.05,   -- Takes 5% for each rob
            callChance = 90 -- 90% police call chance
        },
    },
    grid_connection = { -- Sells Energy wenn Capacity is full.
        [0] = {  -- KEEP 0 LIKE THIS
            cost = 0,  -- KEEP 0 LIKE THIS
        },
        [1] = {
            cost = 50000, -- Cost for Level 1 upgrade.
        },
    },
}

Config.WindmillBlip = {
    sprite = 564,
    scale = 1.0,
    color = 5,
}

Config.pedData = {
    {
        model = 's_m_y_construct_01', -- Model of the NPC (non-playable character).
        coords = vec4(2137.15, 1936.34, 93.77, 90.21), -- Position of the NPC in the game world.
        scenario = 'WORLD_HUMAN_CLIPBOARD', -- NPC animation scenario.
        blips = {
            sprite = 801,
            scale = 1.0,
            color = 5,
            name = locale("blips.windmill_manager"),
        },
        target = {
            label = 'Talk to Peter Wind', -- Interaction text.
            icon = 'fas fa-comment', -- Icon displayed for interaction.
            distance = 3.0, -- Maximum interaction distance.
            event = "lsn-voltage:client:openWindMillPedMenu",
        }
    },
    {
        model = 'u_m_m_curtis', -- Model of the NPC (non-playable character).
        coords = {
            vec4(-428.88, -1728.07, 19.78, 71.66),
            vec4(-539.06, -1720.24, 19.39, 324.69),
            vec4(-499.05, -1714.0, 19.9, 146.81),
            vec4(-559.47, -1804.34, 22.61, 333.31),
            vec4(-570.87, -1775.89, 23.18, 142.53),
            vec4(-592.6, -1765.11, 23.18, 236.33)
        }, -- Position of the NPC in the game world.
        scenario = 'WORLD_HUMAN_STAND_MOBILE', -- NPC animation scenario.
        blips = {
            sprite = 280,
            scale = 1.0,
            color = 5,
            name = "Battery Buyer",
        },
        target = {
            label = 'Sell Batterys', -- Interaction text.
            icon = 'fas fa-money-bill-transfer', -- Icon displayed for interaction.
            distance = 3.0, -- Maximum interaction distance.
            event = "lsn-voltage:client:sellBatterys",
        }
    },
}

--------------------------------------[[ NEEDED! ]]--------------------------------------

function dbug(...)
    if Config.Debug then print('^3[DEBUG]^7', ...) end
end

function formatWithCommas(n)
    local str = tostring(n)
    local formatted = str:reverse():gsub("(%d%d%d)", "%1,"):reverse()
    return formatted:gsub("^,", "")
end