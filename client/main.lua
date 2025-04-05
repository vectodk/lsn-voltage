--------------------------------------[[ VARIABLES ]]--------------------------------------

local spawnedPeds       = {}
local pedSpawnPositions = {}
local blip              = nil
local ownedWindmill     = nil
local ESX               = nil

--------------------------------------[[ FUNCTIONS ]]--------------------------------------

CreateThread(function()
    while ESX == nil do
        TriggerEvent('esx:getSharedObject', function(obj) ESX = obj end)
        Wait(0)
    end
end)

local function createBlips()
    if blip == nil then
        for _, ped in ipairs(Config.pedData) do
            local pedPositions = type(ped.coords) == "table" and ped.coords or { ped.coords }

            if not pedSpawnPositions[ped.model] then
                pedSpawnPositions[ped.model] = pedPositions[math.random(1, #pedPositions)]
            end

            local coords = pedSpawnPositions[ped.model]

            local blip = AddBlipForCoord(coords.x, coords.y, coords.z)
            SetBlipSprite(blip, ped.blips.sprite)
            SetBlipDisplay(blip, 4)
            SetBlipScale(blip, ped.blips.scale)
            SetBlipColour(blip, ped.blips.color)
            SetBlipAsShortRange(blip, true)
            BeginTextCommandSetBlipName("STRING")
            AddTextComponentString(ped.blips.name)
            EndTextCommandSetBlipName(blip)
        end
    end

    local ownedTurbine = lib.callback.await('lsn-voltage:server:getOwnedTurbine', false)
    if ownedTurbine then
        local ownerWindMillCoords = json.decode(ownedTurbine.coords)
        local ownedWindmill = AddBlipForCoord(ownerWindMillCoords.x, ownerWindMillCoords.y, ownerWindMillCoords.z)
        SetBlipSprite(ownedWindmill, Config.WindmillBlip.sprite)
        SetBlipDisplay(ownedWindmill, 4)
        SetBlipScale(ownedWindmill, Config.WindmillBlip.scale)
        SetBlipColour(ownedWindmill, Config.WindmillBlip.color)
        SetBlipAsShortRange(ownedWindmill, true)
        BeginTextCommandSetBlipName("STRING")
        AddTextComponentString(locale("blips.owned_windmill") .. ownedTurbine.id)
        EndTextCommandSetBlipName(ownedWindmill)
    end
end

local function deleteBlips(onlyWindMill)
    if ownedWindmill and DoesBlipExist(ownedWindmill) then
        RemoveBlip(ownedWindmill)
        ownedWindmill = nil
    end

    if blip and DoesBlipExist(blip) and not onlyWindMill then
        RemoveBlip(blip)
        blip = nil
    end
end

local function windmillPedMenu()
    if lib.progressCircle({
            duration = 1500,
            position = 'bottom',
            label = locale("progresscircle.peter_menu"),
            useWhileDead = false,
            canCancel = true,
            disable = {
                move = true,
                car = true,
                mouse = false,
                combat = true,
            },
            anim = {
                dict = 'oddjobs@assassinate@vice@hooker',
                clip = 'argue_a',
            },
        })
    then
        local ownedTurbine, energyGain = lib.callback.await('lsn-voltage:server:getOwnedTurbine', false)
        if ownedTurbine then
            if ownedTurbine == nil then
                lib.notify({
                    title = locale("ui.windmill_manager"),
                    description = locale("error.went_wrong"),
                    type = 'error',
                    duration = 5000,
                    showDuration = true
                })
            end

            local success = lib.callback.await('lsn-voltage:server:getUpgrades', false, ownedTurbine.id)
            local addedCapacity = Config.Upgrades["max_capacity"][success.max_capacity].effect
            local title = locale("ui.energy_stored", ownedTurbine.energy_amount)
            if ownedTurbine.energy_amount >= Config.DefaultStorage + addedCapacity then
                title = locale("ui.energy_stored_max", ownedTurbine.energy_amount)
            end

            local function disableFunction(type, level)
                local disabled = false
                if type == "grid_connection" then
                    if level >= 1 then
                        disabled = true
                        return disabled
                    end
                end
                if level >= 3 then
                    disabled = true
                    return disabled
                end
                return disabled
            end

            local emptyStorageDisable = false
            if ownedTurbine.energy_amount < 5 then
                emptyStorageDisable = true
            end

            lib.registerContext({
                id = 'windmill_' .. ownedTurbine.id,
                title = locale("ui.windmill") .. ownedTurbine.id,
                options = {
                    {
                        title = title,
                        icon = 'fas fa-warehouse',
                        description = locale("ui.max_storage_description"),
                        metadata = {
                            locale("ui.storage_metadata", Config.DefaultStorage + addedCapacity)
                        }
                    },
                    {
                        title = locale("ui.empty_storage_title"),
                        icon = 'fas fa-truck-fast',
                        disabled = emptyStorageDisable,
                        description = locale("ui.empty_storage_description"),
                        onSelect = function()
                            local alert = lib.alertDialog({
                                header = locale("ui.windmill_manager"),
                                content = locale("ui.empty_storage_content"),
                                centered = true,
                                cancel = true
                            })

                            if alert == 'confirm' then
                                local emptyStorage, removedBatterys = lib.callback.await(
                                    'lsn-voltage:server:emptyStorage', false, ownedTurbine.id)
                                if emptyStorage == 'gotitems' then
                                    lib.notify({
                                        title = locale("ui.windmill_manager"),
                                        description = locale("ui.empty_notify_description", removedBatterys),
                                        type = 'success',
                                        icon = 'fas fa-money-bill-transfer',
                                        duration = 5000,
                                        showDuration = true
                                    })
                                elseif emptyStorage == 'no_space' then
                                    lib.notify({
                                        title = locale("ui.windmill_manager"),
                                        description = locale("ui.empty_notify_description_no_space"),
                                        type = 'error',
                                        icon = 'fas fa-money-bill-transfer',
                                        duration = 5000,
                                        showDuration = true
                                    })
                                else
                                    dbug("Something went wrong!")
                                end
                            end
                        end,
                        metadata = {
                            locale("ui.empty_storage_metadata", math.floor(ownedTurbine.energy_amount / 5))
                        }
                    },
                    {
                        title = locale("ui.capacity_title"),
                        icon = 'fas fa-gear',
                        iconAnimation = 'spin',
                        description = locale("ui.capacity_description"),
                        disabled = disableFunction("max_capacity", success.max_capacity),
                        colorScheme = 'blue',
                        progress = success.max_capacity * (100 / 3),
                        onSelect = function()
                            if success.max_capacity >= 3 then
                                lib.notify({
                                    title = locale("ui.windmill_manager"),
                                    description = locale("ui.capacity_description2"),
                                    type = 'error',
                                    duration = 5000,
                                    showDuration = true
                                })
                                return
                            end
                            local alert = lib.alertDialog({
                                header = locale("ui.capacity_header"),
                                content = locale("ui.capacity_content",
                                    formatWithCommas(Config.Upgrades["max_capacity"][success.max_capacity + 1].cost)),
                                centered = true,
                                cancel = true
                            })

                            if alert == 'confirm' then
                                local capacityUpgraded = lib.callback.await('lsn-voltage:server:upgradeTurbine', false,
                                    ownedTurbine.id, "max_capacity")
                                if capacityUpgraded == 'upgraded' then
                                    lib.notify({
                                        title = locale("ui.windmill_manager"),
                                        description = locale("ui.upgraded_notify_description_capacity",
                                            success.max_capacity + 1),
                                        type = 'success',
                                        icon = 'fas fa-money-bill-transfer',
                                        duration = 5000,
                                        showDuration = true
                                    })
                                elseif capacityUpgraded == 'nomoney' then
                                    lib.notify({
                                        title = locale("ui.windmill_manager"),
                                        description = locale("ui.nomoney_notify_description_capacity",
                                            formatWithCommas(Config.Upgrades["max_capacity"][success.max_capacity].cost +
                                                1)),
                                        type = 'error',
                                        duration = 5000,
                                        showDuration = true
                                    })
                                end
                            end
                        end,
                        metadata = {
                            locale("ui.capacity_metadata", success.max_capacity)
                        }
                    },
                    {
                        title = locale("ui.durability_title"),
                        icon = 'fas fa-gear',
                        iconAnimation = 'spin',
                        description = locale("ui.durability_description"),
                        disabled = disableFunction("durability", success.durability),
                        colorScheme = 'blue',
                        progress = success.durability * (100 / 3),
                        onSelect = function()
                            if success.durability >= 3 then
                                lib.notify({
                                    title = locale("ui.windmill_manager"),
                                    description = locale("ui.durability_title_description2"),
                                    type = 'error',
                                    duration = 5000,
                                    showDuration = true
                                })
                                return
                            end
                            local alert = lib.alertDialog({
                                header = locale("ui.durability_header"),
                                content = locale("ui.durability_content",
                                    formatWithCommas(Config.Upgrades["durability"][success.durability + 1].cost)),
                                centered = true,
                                cancel = true
                            })

                            if alert == 'confirm' then
                                local durabilityUpgraded = lib.callback.await('lsn-voltage:server:upgradeTurbine', false,
                                    ownedTurbine.id, "durability")
                                if durabilityUpgraded == 'upgraded' then
                                    lib.notify({
                                        title = locale("ui.windmill_manager"),
                                        description = locale("ui.upgraded_notify_description_durability",
                                            success.durability + 1),
                                        type = 'success',
                                        icon = 'fas fa-money-bill-transfer',
                                        duration = 5000,
                                        showDuration = true
                                    })
                                elseif durabilityUpgraded == 'nomoney' then
                                    lib.notify({
                                        title = 'Windmill Manager',
                                        description = locale("ui.nomoney_notify_description_durability",
                                            formatWithCommas(Config.Upgrades["durability"][success.durability + 1].cost)),
                                        type = 'error',
                                        duration = 5000,
                                        showDuration = true
                                    })
                                end
                            end
                        end,
                        metadata = {
                            locale("ui.durability_metadata", success.durability),
                        }
                    },
                    {
                        title = locale("ui.efficiency_title"),
                        icon = 'fas fa-gear',
                        iconAnimation = 'spin',
                        description = locale("ui.efficiency_description"),
                        disabled = disableFunction("efficiency", success.efficiency),
                        colorScheme = 'blue',
                        progress = success.efficiency * (100 / 3),
                        onSelect = function()
                            if success.efficiency >= 3 then
                                lib.notify({
                                    title = locale("ui.windmill_manager"),
                                    description = locale("ui.efficiency_description2"),
                                    type = 'error',
                                    duration = 5000,
                                    showDuration = true
                                })
                                return
                            end
                            local alert = lib.alertDialog({
                                header = locale("ui.efficiency_header"),
                                content = locale("ui.efficiency_content",
                                    formatWithCommas(Config.Upgrades["efficiency"][success.efficiency + 1].cost)),
                                centered = true,
                                cancel = true
                            })

                            if alert == 'confirm' then
                                local efficiencyUpgraded = lib.callback.await('lsn-voltage:server:upgradeTurbine', false,
                                    ownedTurbine.id, "efficiency")
                                if efficiencyUpgraded == 'upgraded' then
                                    lib.notify({
                                        title = locale("ui.windmill_manager"),
                                        description = locale("ui.upgraded_notify_description_efficiency",
                                            success.efficiency + 1),
                                        type = 'success',
                                        icon = 'fas fa-money-bill-transfer',
                                        duration = 5000,
                                        showDuration = true
                                    })
                                elseif efficiencyUpgraded == 'nomoney' then
                                    lib.notify({
                                        title = locale("ui.windmill_manager"),
                                        description = locale("ui.nomoney_notify_description_efficiency",
                                            formatWithCommas(Config.Upgrades["efficiency"][success.efficiency + 1].cost)),
                                        type = 'error',
                                        duration = 5000,
                                        showDuration = true
                                    })
                                end
                            end
                        end,
                        metadata = {
                            locale("ui.efficiency_metadata", success.efficiency),
                        }
                    },
                    {
                        title = locale("ui.grid_connection_title"),
                        icon = 'fas fa-gear',
                        iconAnimation = 'spin',
                        description = locale("ui.grid_connection_description"),
                        disabled = disableFunction("grid_connection", success.grid_connection),
                        colorScheme = 'blue',
                        progress = success.grid_connection * 100,
                        onSelect = function()
                            if success.grid_connection >= 1 then
                                lib.notify({
                                    title = locale("ui.windmill_manager"),
                                    description = locale("ui.grid_connection_description2"),
                                    type = 'error',
                                    duration = 5000,
                                    showDuration = true
                                })
                                return
                            end
                            local alert = lib.alertDialog({
                                header = locale("ui.grid_connection_header"),
                                content = locale("ui.grid_connection_content",
                                    formatWithCommas(Config.Upgrades["grid_connection"][success.grid_connection + 1]
                                        .cost)),
                                centered = true,
                                cancel = true
                            })

                            if alert == 'confirm' then
                                local grid_connectionUpgraded = lib.callback.await('lsn-voltage:server:upgradeTurbine',
                                    false, ownedTurbine.id, "grid_connection")
                                if grid_connectionUpgraded == 'upgraded' then
                                    lib.notify({
                                        title = locale("ui.windmill_manager"),
                                        description = locale("ui.upgraded_notify_description_grid_connection",
                                            success.grid_connection + 1),
                                        type = 'success',
                                        icon = 'fas fa-money-bill-transfer',
                                        duration = 5000,
                                        showDuration = true
                                    })
                                elseif grid_connectionUpgraded == 'nomoney' then
                                    lib.notify({
                                        title = locale("ui.windmill_manager"),
                                        description = locale("ui.nomoney_notify_description_grid_connection",
                                            formatWithCommas(Config.Upgrades["grid_connection"]
                                                [success.grid_connection + 1].cost)),
                                        type = 'error',
                                        duration = 5000,
                                        showDuration = true
                                    })
                                end
                            end
                        end,
                        metadata = {
                            locale("ui.grid_connection_metadata", success.grid_connection),
                        }
                    },
                    {
                        title = locale("ui.security_title"),
                        icon = 'fas fa-gear',
                        iconAnimation = 'spin',
                        description = locale("ui.security_description"),
                        disabled = disableFunction("security", success.security),
                        colorScheme = 'blue',
                        progress = success.security * (100 / 3),
                        onSelect = function()
                            if success.security >= 3 then
                                lib.notify({
                                    title = locale("ui.windmill_manager"),
                                    description = locale("ui.security_description2"),
                                    type = 'error',
                                    duration = 5000,
                                    showDuration = true
                                })
                                return
                            end
                            local alert = lib.alertDialog({
                                header = locale("ui.security_header"),
                                content = locale("ui.security_content",
                                    formatWithCommas(Config.Upgrades["security"][success.security + 1].cost)),
                                centered = true,
                                cancel = true
                            })

                            if alert == 'confirm' then
                                local securityUpgraded = lib.callback.await('lsn-voltage:server:upgradeTurbine', false,
                                    ownedTurbine.id, "security")
                                if securityUpgraded == 'upgraded' then
                                    lib.notify({
                                        title = locale("ui.windmill_manager"),
                                        description = locale("ui.upgraded_notify_description_security",
                                            success.security + 1),
                                        type = 'success',
                                        icon = 'fas fa-money-bill-transfer',
                                        duration = 5000,
                                        showDuration = true
                                    })
                                elseif securityUpgraded == 'nomoney' then
                                    lib.notify({
                                        title = locale("ui.windmill_manager"),
                                        description = locale("ui.nomoney_notify_description_security",
                                            formatWithCommas(Config.Upgrades["security"][success.security + 1].cost)),
                                        type = 'error',
                                        duration = 5000,
                                        showDuration = true
                                    })
                                end
                            end
                        end,
                        metadata = {
                            locale("ui.security_metadata", success.security),
                        }
                    },
                }
            })

            lib.showContext('windmill_' .. ownedTurbine.id)
        else
            lib.notify({
                title = locale("ui.windmill_manager"),
                description = locale("ui.not_owning_windmill"),
                type = 'error',
                duration = 5000,
                showDuration = true
            })
        end
    else
        dbug("canceled")
    end
end

local function sellBatterys()
    local itemCount = exports.ox_inventory:GetItemCount(Config.energyItemName)
    if itemCount <= 0 then
        lib.notify({
            title = locale("ui.batteries_buyer"),
            description = locale("ui.sold_batteries_description"),
            type = 'error',
            icon = 'fas fa-cart-shopping',
            duration = 5000,
            showDuration = true
        })
        return
    end
    if lib.progressCircle({
            duration = 2000,
            position = 'bottom',
            label = locale("progresscircle.selling_batteries"),
            useWhileDead = false,
            canCancel = true,
            disable = {
                move = true,
                car = true,
                mouse = false,
                combat = true,
            },
            anim = {
                dict = 'misscarsteal4@actor',
                clip = 'actor_berating_loop',
            },
        })
    then
        local input = lib.inputDialog(locale("ui.sold_batteries_title"), {
            {
                type = 'slider',
                label = locale("ui.sold_batteries_type_label"),
                description = locale("ui.sold_batteries_type_description"),
                required = true,
                min = 1,
                max = itemCount,
                default = itemCount,
                step = 1,
                icon = 'fas fa-battery-three-quarters'
            },
            {
                type = 'select',
                icon = 'fas fa-credit-card',
                default = 'bank',
                label = locale("ui.sold_batteries_type_label2"),
                description = locale("ui.sold_batteries_type_description2"),
                options = {
                    { label = locale("ui.sold_batteries_cash"), value = 'cash' },
                    { label = locale("ui.sold_batteries_bank"), value = 'bank' }
                },
                required = true
            },
        })

        if not input then return end
        local batteries = input[1]
        local paymentOption = input[2]
        local soldBatteries, price = lib.callback.await('lsn-voltage:server:sellBatteries', false, batteries,
            paymentOption)
        if soldBatteries == 'sold' then
            lib.notify({
                title = locale("ui.batteries_buyer"),
                description = locale("ui.sold_batterys_notify_description", batteries, price),
                type = 'success',
                icon = 'fas fa-cart-shopping',
                duration = 5000,
                showDuration = true
            })
        end
    else
        dbug("canceled")
    end
end

local function CreateManageMenu(turbineData, energyGain)
    if lib.progressCircle({
            duration = 1500,
            position = 'bottom',
            label = locale("progresscircle.manage_menu"),
            useWhileDead = false,
            canCancel = true,
            disable = {
                move = true,
                car = true,
                mouse = false,
                combat = true,
            },
            anim = {
                dict = 'anim@amb@carmeet@checkout_car@male_c@idles',
                clip = 'idle_a',
            },
        })
    then
        local success = lib.callback.await('lsn-voltage:server:getUpgrades', false, turbineData.id)

        local maxEnergyGain = (Config.MaxProduction * Config.Upgrades["efficiency"][success.efficiency].effect) *
            Config.EnergyMultiplier
        local productionPercentage = (energyGain / maxEnergyGain) * 100

        local function GetProductionColor()
            if productionPercentage < 33 then
                return 'red'
            elseif productionPercentage < 66 then
                return 'orange'
            end
            return 'green'
        end

        local function GetDurabilityColor(durabilityPercentage)
            local percentage = durabilityPercentage
            if percentage < 33.33 then
                return 'red'
            elseif percentage < 66.66 then
                return 'orange'
            else
                return 'green'
            end
        end

        local addedCapacity = Config.Upgrades["max_capacity"][success.max_capacity].effect
        local title = locale("ui.energy_stored", turbineData.energy_amount)
        if turbineData.energy_amount >= Config.DefaultStorage + addedCapacity then
            title = locale("ui.energy_stored_max", turbineData.energy_amount)
        end

        local maxDurability = 100 + Config.Upgrades["durability"][success.durability].effect
        local durabilityPercentage = (turbineData.durability / maxDurability) * 100

        lib.registerContext({
            id = 'windmill_' .. turbineData.id,
            title = locale("ui.windmill") .. turbineData.id,
            options = {
                {
                    title = title,
                    icon = 'fas fa-warehouse',
                    description = locale("ui.manage_description"),
                    metadata = {
                        locale("ui.manage_metadata", Config.DefaultStorage + addedCapacity)
                    }
                },
                {
                    title = locale("ui.production_title"),
                    icon = 'fas fa-gear',
                    iconAnimation = 'spin',
                    description = locale("ui.production_description", energyGain),
                    colorScheme = GetProductionColor(),
                    progress = productionPercentage,
                    metadata = {
                        locale("ui.production_metadata", math.floor(maxEnergyGain)),
                    }
                },
                {
                    title = locale("ui.durability_title_manage"),
                    icon = 'fas fa-wrench',
                    description = locale("ui.durability_description_manage", turbineData.durability),
                    colorScheme = GetDurabilityColor(durabilityPercentage),
                    progress = durabilityPercentage,
                    onSelect = function()
                        if turbineData.durability >= maxDurability then
                            lib.notify({
                                title = locale("ui.windmill_manager"),
                                description = locale("ui.cant_repair"),
                                type = 'error',
                                duration = 5000,
                                showDuration = true
                            })
                            return
                        end
                        local cost = lib.callback.await('lsn-voltage:server:repairTurbineCost', false, turbineData.id)
                        local alert = lib.alertDialog({
                            header = locale("ui.windmill_manager"),
                            content = locale("ui.want_to_repair", formatWithCommas(cost)),
                            centered = true,
                            cancel = true
                        })

                        if alert == 'confirm' then
                            local turbineRepaired, cost = lib.callback.await('lsn-voltage:server:repairTurbine', false,
                                turbineData.id)
                            if turbineRepaired == 'repaired' then
                                lib.notify({
                                    title = locale("ui.windmill_manager"),
                                    description = locale("ui.repaired_turbine", formatWithCommas(cost)),
                                    type = 'success',
                                    icon = 'fas fa-money-bill-transfer',
                                    duration = 5000,
                                    showDuration = true
                                })
                            elseif turbineRepaired == 'nomoney' then
                                lib.notify({
                                    title = locale("ui.windmill_manager"),
                                    description = locale("ui.nomoney_turbine", formatWithCommas(cost)),
                                    type = 'error',
                                    duration = 5000,
                                    showDuration = true
                                })
                            end
                        end
                    end,
                    metadata = {
                        locale("ui.durability_metadata_manage", math.floor(maxDurability))
                    }
                },
                {
                    title = locale("ui.selltoplayer_turbine_title"),
                    icon = 'fas fa-person-rays',
                    description = locale("ui.selltoplayer_turbine_description"),
                    onSelect = function()
                        local input = lib.inputDialog(locale("ui.selltoplayer_turbine_header") .. turbineData.id, {
                            {
                                type = "input",
                                label = locale("ui.citzienid_label"),
                                description = locale("ui.citzienid_description"),
                                placeholder = "XYZ12345",
                                icon = 'fas fa-user-tag',
                                required = true
                            },
                            {
                                type = "number",
                                label = locale("ui.price_label"),
                                description = locale("ui.price_description"),
                                placeholder = "50000",
                                icon = 'fas fa-dollar-sign',
                                required = true,
                                min = 1,
                                max = 1000000,
                            }
                        })

                        if not input or not input[1] or not input[2] then return end
                        local targetCid = tostring(input[1])
                        local sellingPrice = tonumber(input[2])

                        local alert = lib.alertDialog({
                            header = locale("ui.windmill_manager"),
                            content = locale("ui.selltoplayer_confirm_content",
                                formatWithCommas(math.floor(sellingPrice)), targetCid),
                            centered = true,
                            cancel = true
                        })

                        if alert == 'confirm' then
                            local turbineSold = lib.callback.await('lsn-voltage:server:sellTurbineToPlayer', false,
                                turbineData.id, targetCid, sellingPrice)

                            if turbineSold == 'sold' then
                                deleteBlips(true)
                                lib.notify({
                                    title = locale("ui.windmill_manager"),
                                    description = locale("ui.selltoplayer_sold_description", turbineData.id,
                                        formatWithCommas(math.floor(sellingPrice)), targetCid),
                                    type = 'success',
                                    icon = 'fas fa-money-bill-transfer',
                                    duration = 5000,
                                    showDuration = true
                                })
                            elseif turbineSold == 'no_money' then
                                lib.notify({
                                    title = locale("ui.windmill_manager"),
                                    description = locale("ui.selltoplayer_no_money_description"),
                                    type = 'error',
                                    icon = 'fas fa-exclamation-triangle',
                                    duration = 5000,
                                    showDuration = true
                                })
                            elseif turbineSold == 'not_found' then
                                lib.notify({
                                    title = locale("ui.windmill_manager"),
                                    description = locale("ui.selltoplayer_not_found_description"),
                                    type = 'error',
                                    icon = 'fas fa-exclamation-triangle',
                                    duration = 5000,
                                    showDuration = true
                                })
                            elseif turbineSold == 'owned' then
                                lib.notify({
                                    title = locale("ui.windmill_manager"),
                                    description = locale("error.buyer_already_own_turbine", targetCid),
                                    type = 'error',
                                    duration = 5000,
                                    showDuration = true
                                })
                            end
                        end
                    end
                },
                {
                    title = locale("ui.sell_turbine_title"),
                    icon = 'fas fa-money-bill-transfer',
                    description = locale("ui.sell_turbine_description"),
                    onSelect = function()
                        local cost, totalCost = lib.callback.await("lsn-voltage:server:sellTurbineCost", false,
                            turbineData.id)
                        local alert = lib.alertDialog({
                            header = locale("ui.windmill_manager"),
                            content = locale("ui.sell_turbine_content", formatWithCommas(totalCost),
                                formatWithCommas(math.floor(cost))),
                            centered = true,
                            cancel = true
                        })

                        if alert == 'confirm' then
                            local turbineSold = lib.callback.await('lsn-voltage:server:sellTurbine', false,
                                turbineData.id)
                            if turbineSold == 'sold' then
                                deleteBlips(true)
                                lib.notify({
                                    title = locale("ui.windmill_manager"),
                                    description = locale("ui.sold_turbine_description", turbineData.id,
                                        formatWithCommas(math.floor(cost))),
                                    type = 'success',
                                    icon = 'fas fa-money-bill-transfer',
                                    duration = 5000,
                                    showDuration = true
                                })
                            end
                        end
                    end
                },
            }
        })

        lib.showContext('windmill_' .. turbineData.id)
    else
        dbug("canceled")
    end
end

local function createPed()
    for _, ped in ipairs(Config.pedData) do
        lib.requestModel(ped.model, 10000)

        local pedPositions = type(ped.coords) == "table" and ped.coords or { ped.coords }

        if not pedSpawnPositions[ped.model] then
            pedSpawnPositions[ped.model] = pedPositions[math.random(1, #pedPositions)]
        end

        local coords = pedSpawnPositions[ped.model]

        local windmillPed = CreatePed(26, ped.model, coords.x, coords.y, coords.z - 1, coords.w, false, false)
        SetModelAsNoLongerNeeded(ped.model)
        TaskStartScenarioInPlace(windmillPed, ped.scenario, 0, false)
        SetEntityInvincible(windmillPed, true)
        SetBlockingOfNonTemporaryEvents(windmillPed, true)
        FreezeEntityPosition(windmillPed, true)

        exports.ox_target:addLocalEntity(windmillPed, {
            name = ped.model .. '_ped',
            label = ped.target.label or dbug("ped.target.label not set"),
            icon = ped.target.icon or dbug("ped.target.icon not set"),
            event = ped.target.event or dbug("ped.target.event not set"),
            distance = ped.target.distance or dbug("ped.target.distance not set"),
        })

        table.insert(spawnedPeds, windmillPed)
    end
end

local function removePed()
    for _, ped in ipairs(spawnedPeds) do
        if DoesEntityExist(ped) then
            exports.ox_target:removeLocalEntity(ped)
            DeletePed(ped)
        end
    end

    spawnedPeds = {}
end

local function ManageWindmill(turbineId)
    local turbineData, energyGain = lib.callback.await('lsn-voltage:server:getTurbineData', false, turbineId)
    if turbineData == nil then
        lib.notify({
            title = locale("ui.windmill_manager"),
            description = locale("error.went_wrong"),
            type = 'error',
            duration = 5000,
            showDuration = true
        })
    end
    if ESX.GetPlayerData().identifier ~= turbineData.owner then
        lib.notify({
            title = locale("ui.windmill_manager"),
            description = locale("error.not_owned"),
            type = 'error',
            duration = 5000,
            showDuration = true
        })
        return
    end

    CreateManageMenu(turbineData, energyGain)
end

local function BuyWindmill(turbineId)
    if lib.progressCircle({
            duration = 5000,
            position = 'bottom',
            label = locale("progresscircle.buying_windmill"),
            useWhileDead = false,
            canCancel = true,
            disable = {
                move = true,
                car = true,
                mouse = false,
                combat = true,
            },
            anim = {
                dict = 'random@shop_tattoo',
                clip = '_idle_a',
            },
        })
    then
        local alert = lib.alertDialog({
            header = locale("ui.windmill_manager"),
            content = locale("ui.buy_turbine", formatWithCommas(Config.buyPrice)),
            centered = true,
            cancel = true
        })

        if alert == 'confirm' then
            local canBuyTurbine = lib.callback.await('lsn-voltage:server:buyTurbine', false, turbineId)
            if canBuyTurbine == 'owned' then
                lib.notify({
                    title = locale("ui.windmill_manager"),
                    description = locale("error.already_owned"),
                    type = 'error',
                    duration = 5000,
                    showDuration = true
                })
                return
            end
            if not canBuyTurbine then
                lib.notify({
                    title = locale("ui.windmill_manager"),
                    description = locale("error.missing_money"),
                    type = 'error',
                    duration = 5000,
                    showDuration = true
                })
                return
            end
            if canBuyTurbine then
                createBlips()
            end
        end
    else
        dbug("canceled")
    end
end

local function createWindMill()
    local turbines = lib.callback.await('lsn-voltage:server:getAllTurbines', false)

    if not turbines then return end

    for i = 1, #turbines do
        local coords = json.decode(turbines[i].coords)

        local targetTable = {}

        if turbines[i].owner == '0' then
            targetTable = {
                name = 'turbine_' .. turbines[i].id,
                coords = coords,
                radius = 4,
                debug = Config.Debug,
                options = {
                    icon = 'fas fa-credit-card',
                    label = locale("target.buy_windmill"),
                    onSelect = function()
                        BuyWindmill(turbines[i].id)
                    end,
                    distance = 5.0
                }
            }
        else
            targetTable = {
                name = 'turbine_' .. turbines[i].id,
                coords = coords,
                radius = 4,
                debug = Config.Debug,
                options = {
                    icon = 'fas fa-toolbox',
                    label = locale("target.manage_windmill"),
                    onSelect = function()
                        ManageWindmill(turbines[i].id)
                    end,
                    distance = 5.0
                }
            }
        end

        exports.ox_target:addSphereZone(targetTable)
    end
end

local function createNewWindMill()
    local creatingWind = true
    local showUI = false
    local lastEntity

    while creatingWind do
        Wait(0)
        local hit, ent, coords = lib.raycast.fromCamera(16, 4, 25.0)
        local plrCoords = GetEntityCoords(PlayerPedId())
        if ent ~= 0 then
            DrawLine(plrCoords.x, plrCoords.y, plrCoords.z, coords.x, coords.y, coords.z, 255, 255, 255, 255)
        end
        if DoesEntityExist(ent) and hit then
            lastEntity = ent

            local entModel = GetEntityArchetypeName(ent)

            if Config.WindTurbine[entModel] then
                SetEntityDrawOutlineColor(0, 255, 0, 255)
                if not showUI then
                    lib.showTextUI('[E] - Import Windmill into DB')
                    SetEntityDrawOutline(ent, true)
                    showUI = true
                end
                if IsControlJustReleased(0, 46) then
                    local entCoords = GetEntityCoords(ent)
                    local success = lib.callback.await('lsn-voltage:server:createTurbine', false, entCoords)

                    if success == "already_exist" then
                        showUI = false
                        lib.hideTextUI()
                        SetEntityDrawOutline(lastEntity, false)
                        return
                    end

                    showUI = false
                    lib.hideTextUI()
                    SetEntityDrawOutline(lastEntity, false)

                    local turbines = lib.callback.await('lsn-voltage:server:getAllTurbines', false)
                    exports.ox_target:addSphereZone({
                        name = 'turbine_' .. turbines[#turbines].id,
                        coords = entCoords,
                        radius = 4,
                        debug = Config.Debug,
                        options = {
                            icon = 'fas fa-credit-card',
                            label = 'Buy Windmill',
                            onSelect = function()
                                BuyWindmill(turbines[#turbines].id)
                            end,
                            distance = 5.0
                        },
                    })
                    return
                end
            end
        else
            showUI = false
            lib.hideTextUI()
            SetEntityDrawOutline(lastEntity, false)
        end
    end
end

--------------------------------------[[ EVENTS ]]--------------------------------------

RegisterNetEvent('lsn-voltage:client:getTurbineData', function(turbine)
    local coords = json.decode(turbine.coords)

    local targetTable = {}

    exports.ox_target:removeZone('turbine_' .. turbine.id)

    if turbine.owner == '0' then
        targetTable = {
            name = 'turbine_' .. turbine.id,
            coords = coords,
            radius = 4,
            debug = Config.Debug,
            options = {
                icon = 'fas fa-credit-card',
                label = locale("target.buy_windmill"),
                onSelect = function()
                    BuyWindmill(turbine.id)
                end,
                distance = 5.0
            }
        }
    else
        targetTable = {
            name = 'turbine_' .. turbine.id,
            coords = coords,
            radius = 4,
            debug = Config.Debug,
            options = {
                icon = 'fas fa-toolbox',
                label = locale("target.manage_windmill"),
                onSelect = function()
                    ManageWindmill(turbine.id)
                end,
                distance = 5.0
            }
        }
    end

    exports.ox_target:addSphereZone(targetTable)
end)

RegisterNetEvent('lsn-voltage:client:confirmTurbinePurchase', function(src, turbineId, price)
    local confirm = lib.alertDialog({
        header = locale("ui.windmill_manager"),
        content = locale("ui.selltoplayer_finalize", formatWithCommas(price)),
        centered = true,
        cancel = true
    })

    if confirm == 'confirm' then
        TriggerServerEvent('lsn-voltage:server:finalizeTurbinePurchase', src, turbineId, price)
    else
        TriggerServerEvent('lsn-voltage:server:cancelTurbinePurchase', src)
    end
end)

RegisterNetEvent('lsn-voltage:client:sellBatterys', function()
    sellBatterys()
end)

RegisterNetEvent('lsn-voltage:client:openWindMillPedMenu', function()
    windmillPedMenu()
end)

RegisterNetEvent('lsn-voltage:client:createNewWindmill', function()
    createNewWindMill()
end)

RegisterNetEvent('lsn-voltage:client:startRobbing', function(closestTurbine)
    local coords = GetEntityCoords(PlayerPedId())
    if lib.progressCircle({
            duration = 8000,
            position = 'bottom',
            label = locale("robbing.cutting_wires"),
            useWhileDead = false,
            canCancel = true,
            disable = {
                move = true,
                car = true,
                mouse = false,
                combat = true,
            },
            anim = {
                dict = 'mini@repair',
                clip = 'fixing_a_ped',
            },
        })
    then
        local success = lib.skillCheck(Config.hackingDifficulty, Config.hackingKeys)
        local id = closestTurbine.id
        local upgrades = lib.callback.await('lsn-voltage:server:getUpgrades', false, id)
        if success then
            local energy_amount = closestTurbine.energy_amount
            local src = source
            TriggerServerEvent("lsn-voltage:server:getRewards", id, energy_amount)
        else
            lib.notify({
                title = locale("robbing.windmill_robbing"),
                description = locale("robbing.failed"),
                type = 'error',
                duration = 5000,
                showDuration = true
            })
        end
        if Config.policeAlertType == 'client' then
            local chance = math.random(1, 100)
            if Config.Upgrades["security"][upgrades.security].callChance < chance then
                dbug(Config.Upgrades["security"][upgrades.security].callChance .. " kleiner als " .. chance)
                alertPolice(coords)
            end
        end
    else
        dbug('canceled')
    end
end)

RegisterNetEvent("lsn-voltage:client:windmillActions", function(data)
    lib.registerContext({
        id = 'windmill_actions',
        title = "⚙️ **Windmill #" .. data.id .. "**",
        menu = "windmill_menu",
        options = {
            {
                title = "📌 **Teleport**",
                description = "Teleport to this windmill's location",
                icon = "fas fa-location-arrow",
                event = "lsn-voltage:client:tpToWindmill",
                args = data.coords
            }
        }
    })
    lib.showContext("windmill_actions")
end)

RegisterNetEvent("lsn-voltage:client:tpToWindmill", function(coords)
    local ped = PlayerPedId()
    DoScreenFadeOut(500)
    Wait(500)
    SetEntityCoords(ped, coords.x, coords.y, coords.z + 1.0, false, false, false, false)
    Wait(500)
    DoScreenFadeIn(500)
    lib.notify({ title = "Teleport", description = "You have been teleported to the windmill!", type = "success" })
end)

RegisterNetEvent("lsn-voltage:client:windmillAdminMenu", function()
    lib.notify({ title = "Windmill Admin", description = "Loading Data...", type = "info", duration = 4000 })

    local turbines = lib.callback.await('lsn-voltage:server:getAllTurbines', false)
    if not turbines or #turbines == 0 then
        lib.notify({ title = "No Windmills", description = "No windmills found.", type = "warning" })
        return
    end

    local menuEntries = {}

    for i = 1, #turbines do
        local turbine = turbines[i]
        local coords = json.decode(turbine.coords)

        local owner = turbine.owner ~= "0" and ("🟢 **Owner**: " .. turbine.owner) or "🔴 **Unowned**"

        local upgrades = lib.callback.await('lsn-voltage:server:getUpgrades', false, turbine.id) or {}
        local upgradeList = nil

        if type(upgrades) == "table" and next(upgrades) ~= nil then
            local upgradeNames = {}

            for upgradeName, level in pairs(upgrades) do
                local formattedName = upgradeName:gsub("^%l", string.upper)
                table.insert(upgradeNames, "‎ ‎ ‎ ‎ ‎ ‎ ‎ ● **" .. formattedName .. "** [ Lv. " .. level .. " ]")
            end

            upgradeList = "\n" .. table.concat(upgradeNames, "\n")
        end

        local location = "📍 **Location**: " .. math.floor(coords.x) .. ", " .. math.floor(coords.y)

        table.insert(menuEntries, {
            title = "🌪️ **Windmill #" .. turbine.id .. "**",
            description = owner .. "\n🔧 **Upgrades**: " .. upgradeList .. "\n" .. location,
            icon = "fas fa-wind",
            arrow = true,
            event = "lsn-voltage:client:windmillActions",
            args = { id = turbine.id, coords = coords }
        })
    end

    lib.registerContext({
        id = 'windmill_menu',
        title = '🌬️ **Windmill Overview**',
        options = menuEntries
    })
    lib.showContext('windmill_menu')
end)
--------------------------------------[[ EVENT HANDLERS ]]--------------------------------------

AddEventHandler('onResourceStart', function(resourceName)
    if (GetCurrentResourceName() ~= resourceName) then return end
    createPed()
    createBlips()
    createWindMill()
end)

AddEventHandler('esx:playerLoaded', function()
    createPed()
    createBlips()
    createWindMill()
end)

AddEventHandler('esx:onPlayerLogout', function()
    removePed()
    deleteBlips()
end)

AddEventHandler('onResourceStop', function(resourceName)
    if (GetCurrentResourceName() ~= resourceName) then return end
    removePed()
    deleteBlips()
end)

--------------------------------------[[ THREAD & COMMAND ]]--------------------------------------

--Removes fencegate next to the ped
CreateThread(function()
    while true do
        local x, y, z = 2126.230, 1939.710, 92.815
        local ent = GetClosestObjectOfType(x, y, z, 2.0, `prop_fnclink_02gate3`, false, false, false)

        if DoesEntityExist(ent) then
            NetworkRequestControlOfEntity(ent)
            while not NetworkHasControlOfEntity(ent) do
                Wait(10)
            end
            SetEntityAsMissionEntity(ent, true, true)
            DeleteObject(ent)
        end

        Wait(5000)
    end
end)
