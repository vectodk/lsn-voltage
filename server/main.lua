--------------------------------------[[ VARIABLE ]]--------------------------------------

local energyGain = 0
local windmillCooldowns = {}

--------------------------------------[[ FUNCTION ]]--------------------------------------

local function GetUpgrades(turbineId)
  local result = exports.oxmysql:fetchSync('SELECT upgrades FROM `lsn-voltage` WHERE id = ?', { turbineId })
  if result and result[1] then
    return json.decode(result[1].upgrades)
  end
  return nil
end

local function setEnergyGain(turbineId)
  local upgrades = GetUpgrades(turbineId)
  local windMultiplier = math.random(Config.MinProduction, Config.MaxProduction) *
      Config.Upgrades["efficiency"][upgrades.efficiency].effect

  energyGain = windMultiplier * Config.EnergyMultiplier

  return energyGain
end

local function transferTurbineOwnership(turbineId, buyerSrc)
  local xPlayer = ESX.GetPlayerFromId(buyerSrc)
  if not xPlayer then
    print("Error: Buyer not found (Source: " .. tostring(buyerSrc) .. ")")
    return
  end

  local buyerIdentifier = xPlayer.identifier

  local updateSuccess = MySQL.update.await('UPDATE `lsn-voltage` SET `owner` = ? WHERE `id` = ?',
    { buyerIdentifier, turbineId })

  if updateSuccess and updateSuccess > 0 then
    local newTurbine = MySQL.single.await('SELECT * FROM `lsn-voltage` WHERE `id` = ?', { turbineId })

    if newTurbine then
      TriggerClientEvent('lsn-voltage:client:getTurbineData', -1, newTurbine)
    else
      print("Error: Could not fetch turbine data after ownership transfer (Windmill ID: " .. turbineId .. ")")
    end
  else
    print("Error: Ownership transfer failed for Windmill ID: " .. turbineId)
  end
end

local function RobWindmill(src)
  local playerPed = GetPlayerPed(src)

  local playerCoords = GetEntityCoords(playerPed)

  local turbines = MySQL.query.await('SELECT * FROM `lsn-voltage`', {})
  local closestTurbine = nil
  local closestDistance = 5

  for i = 1, #turbines do
    local coords = json.decode(turbines[i].coords)
    local distance = #(playerCoords - vector3(coords.x, coords.y, coords.z))

    if distance < closestDistance then
      closestTurbine = turbines[i]
      closestDistance = distance
    end
  end

  if closestTurbine.owner == '0' then return end

  local xPlayer = ESX.GetPlayerFromId(src)
  local identifier = xPlayer.identifier
  if closestTurbine.owner == identifier then
    TriggerClientEvent('ox_lib:notify', src, {
      title = locale("robbing.windmill_robbing"),
      type = 'error',
      description = locale("robbing.robbing_own"),
      duration = 5000,
      showDuration = true
    })
    return
  end

  if not closestTurbine then
    TriggerClientEvent('ox_lib:notify', src, {
      title = locale("robbing.windmill_robbing"),
      type = 'error',
      description = locale("robbing.no_windmill"),
      duration = 5000,
      showDuration = true
    })
    return
  end

  local turbineID = closestTurbine.id

  if windmillCooldowns[turbineID] and (GetGameTimer() - windmillCooldowns[turbineID]) < 600000 then
    TriggerClientEvent('ox_lib:notify', src, {
      title = locale("robbing.windmill_robbing"),
      type = 'error',
      description = locale("robbing.already_robbed"),
      duration = 5000,
      showDuration = true
    })
    return
  end

  local hasToolkit = xPlayer.getInventoryItem(Config.secondHackingTool).count > 0

  if not hasToolkit then
    TriggerClientEvent('ox_lib:notify', src, {
      title = locale("robbing.windmill_robbing"),
      type = 'error',
      description = locale("robbing.item_missing"),
      duration = 5000,
      showDuration = true
    })
    return
  end

  TriggerClientEvent("lsn-voltage:client:startRobbing", src, closestTurbine)
  if Config.policeAlertType == 'server' then
    local upgrades = GetUpgrades(turbineID)
    local chance = math.random(1, 100)
    if Config.Upgrades["security"][upgrades.security].callChance < chance then
      dbug(Config.Upgrades["security"][upgrades.security].callChance .. " kleiner als " .. chance)
      alertPolice(playerCoords, src)
    end
  end
end


--------------------------------------[[ CALLBACKS ]]--------------------------------------

lib.callback.register('lsn-voltage:server:getUpgrades', function(source, turbineId)
  local result = exports.oxmysql:fetchSync('SELECT upgrades FROM `lsn-voltage` WHERE id = ?', { turbineId })
  if result and result[1] then
    return json.decode(result[1].upgrades)
  end
  return nil
end)

lib.callback.register('lsn-voltage:server:upgradeTurbine', function(source, turbineId, type)
  if not turbineId or not type then
    dbug('Error: no turbineid or type received')
    return false, "Turbine ID or Type needed"
  end

  local xPlayer = ESX.GetPlayerFromId(source)
  if not xPlayer then
    dbug('Player not found for source: ' .. source)
    return false
  end

  local identifier = xPlayer.identifier
  local turbine = MySQL.single.await('SELECT * FROM `lsn-voltage` WHERE `id` = ?', { turbineId })
  if not turbine then
    dbug('Windmill with ID ' .. turbineId .. ' not found')
    return false
  end

  if turbine.owner ~= identifier then
    print(
      '\n^8[CHEATING ALERT]^7 lsn-voltage:server:upgradeTurbine was executed incorrectly!',
      '\n^8[CHEATING ALERT]^7 Player Name: ' .. GetPlayerName(source),
      '\n^8[CHEATING ALERT]^7 ' .. GetPlayerIdentifier(source, 0),
      '\n^8[CHEATING ALERT]^7 This Player tried to trigger an upgrade event, which is not correct'
    )
    return false
  end

  local upgrades = turbine.upgrades and json.decode(turbine.upgrades) or
      { durability = 0, efficiency = 0, max_capacity = 0, grid_connection = 0, security = 0 }
  local currentLevel = upgrades[type] or 0

  if type == "grid_connection" then
    if currentLevel >= 1 then
      return false
    end
  end

  if currentLevel >= 3 then
    return false
  end

  local nextLevel = currentLevel + 1
  local upgradeConfig = Config.Upgrades[type] and Config.Upgrades[type][nextLevel]
  if not upgradeConfig then
    return false
  end

  local cost = upgradeConfig.cost
  if xPlayer.getAccount('bank').money >= cost then
    xPlayer.removeAccountMoney('bank', cost)
  else
    dbug('Player ' .. identifier .. ' is missing money! (' .. cost .. '$)')
    return "nomoney"
  end

  upgrades[type] = nextLevel
  MySQL.update.await('UPDATE `lsn-voltage` SET `upgrades` = ? WHERE `id` = ?', { json.encode(upgrades), turbineId })

  return "upgraded"
end)

lib.callback.register('lsn-voltage:server:emptyStorage', function(source, turbineId)
  if not turbineId then
    dbug('Error: no turbineid received')
    return false, "Turbine ID needed"
  end

  local xPlayer = ESX.GetPlayerFromId(source)
  if not xPlayer then
    dbug('Player not found for source: ' .. source)
    return false
  end

  local identifier = xPlayer.identifier
  local turbine = MySQL.single.await('SELECT * FROM `lsn-voltage` WHERE `id` = ?', { turbineId })
  if not turbine then
    dbug('Windmill with ID ' .. turbineId .. ' not found')
    return false
  end

  if turbine.owner ~= identifier then
    print(
      '\n^8[CHEATING ALERT]^7 lsn-voltage:server:upgradeTurbine was executed incorrectly!',
      '\n^8[CHEATING ALERT]^7 Player Name: ' .. GetPlayerName(source),
      '\n^8[CHEATING ALERT]^7 ' .. GetPlayerIdentifier(source, 0),
      '\n^8[CHEATING ALERT]^7 This Player tried to trigger an upgrade event, which is not correct'
    )
    return false
  end

  local amountToAdd = exports.ox_inventory:CanCarryAmount(source, Config.energyItemName)
  if amountToAdd <= 0 then return 'no_space' end

  if amountToAdd * 5 > turbine.energy_amount then
    amountToAdd = math.floor(turbine.energy_amount / 5)
  end

  exports.ox_inventory:AddItem(source, Config.energyItemName, amountToAdd)

  MySQL.update.await('UPDATE `lsn-voltage` SET `energy_amount` = `energy_amount` - ? WHERE `id` = ?',
    { amountToAdd * 5, turbineId })

  return "gotitems", amountToAdd
end)

lib.callback.register('lsn-voltage:server:getAllTurbines', function(source)
  local turbines = MySQL.query.await('SELECT * FROM `lsn-voltage`', {})

  return turbines
end)

lib.callback.register('lsn-voltage:server:getOwnedTurbine', function(source)
  local xPlayer = ESX.GetPlayerFromId(source)

  if not xPlayer then
    dbug('Player not found for source: ' .. source)
    return nil
  end

  local identifier = xPlayer.identifier
  local turbine = MySQL.single.await('SELECT * FROM `lsn-voltage` WHERE `owner` = ?', { identifier })

  if turbine then
    return turbine, energyGain
  else
    return nil
  end
end)

lib.callback.register('lsn-voltage:server:getTurbineData', function(source, id)
  local turbine = nil

  if id == nil then
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then
      dbug('Player not found for source: ' .. source)
      return
    end

    local identifier = xPlayer.identifier
    turbine = MySQL.single.await('SELECT * from `lsn-voltage` WHERE `owner` = ?', { identifier })
  else
    turbine = MySQL.single.await('SELECT * from `lsn-voltage` WHERE `id` = ?', { id })
  end

  if turbine then
    return turbine, energyGain
  else
    dbug(
      '^8[DATABASE ERROR]^7 Weird request for id: ' .. id
    )
    return nil
  end
end)

lib.callback.register('lsn-voltage:server:buyTurbine', function(source, turbineId)
  if not turbineId then
    dbug('Error: NO ID FOUND')
    return false
  end
  local xPlayer = ESX.GetPlayerFromId(source)
  if not xPlayer then
    dbug('Player not found for source: ' .. source)
    return
  end

  local identifier = xPlayer.identifier
  local alreadyOwned = MySQL.single.await('SELECT `id` FROM `lsn-voltage` WHERE `owner` = ?', { identifier })
  if alreadyOwned then
    return 'owned'
  end

  local function buyTurbine()
    MySQL.update.await('UPDATE `lsn-voltage` SET `owner` = ? WHERE `id` = ?', { identifier, turbineId })
    local turbine = MySQL.single.await('SELECT * FROM `lsn-voltage` WHERE `id` = ?', { turbineId })

    TriggerClientEvent('lsn-voltage:client:getTurbineData', -1, turbine)

    TriggerClientEvent('ox_lib:notify', source, {
      title = locale("ui.windmill_manager"),
      type = 'success',
      description = locale("server.bought_turbine", formatWithCommas(Config.buyPrice)),
      duration = 5000,
      showDuration = true
    })
  end

  if xPlayer.getAccount('bank').money >= Config.buyPrice then
    xPlayer.removeAccountMoney('bank', Config.buyPrice)
    buyTurbine()
    return true
  else
    return false
  end
end)

lib.callback.register('lsn-voltage:server:createTurbine', function(source, coords)
  local turbines = MySQL.single.await('SELECT `coords` from `lsn-voltage` WHERE `coords` = ?', { json.encode(coords) })

  if turbines then
    TriggerClientEvent('ox_lib:notify', source, {
      title = 'Windmill Creator',
      type = 'error',
      description = 'U cant create that Windmill because it already exists',
      duration = 2500,
      showDuration = true
    })
    return "already_exist"
  else
    TriggerClientEvent('ox_lib:notify', source, {
      title = 'Windmill Creator',
      type = 'success',
      description = 'Windmill got added!',
      duration = 2500,
      showDuration = true
    })

    MySQL.insert.await('INSERT INTO `lsn-voltage` (coords) VALUES (?)', { json.encode(coords) })

    return "success"
  end
end)

lib.callback.register('lsn-voltage:server:sellTurbine', function(source, turbineId)
  if not turbineId then
    return false
  end
  local xPlayer = ESX.GetPlayerFromId(source)
  if not xPlayer then
    dbug('Player not found for source: ' .. source)
    return
  end

  local identifier = xPlayer.identifier
  local turbine = MySQL.single.await('SELECT * from `lsn-voltage` WHERE `id` = ?', { turbineId })

  if turbine.owner ~= identifier then
    print(
      '\n^8[CHEATING ALERT]^7 lsn-voltage:server:sellTurbine was executed incorrectly!',
      '\n^8[CHEATING ALERT]^7 Player Name: ' .. GetPlayerName(source),
      '\n^8[CHEATING ALERT]^7 ' .. GetPlayerIdentifier(source, 0),
      '\n^8[CHEATING ALERT]^7 This Player tried to trigger a sell event, which is not correct'
    )
    return
  end

  local upgrades = GetUpgrades(turbineId)
  local totalCost = Config.buyPrice

  for _, v in pairs({ "durability", "efficiency", "max_capacity", "grid_connection", "security" }) do
    if upgrades[v] > 0 then
      totalCost = totalCost + Config.Upgrades[v][upgrades[v]].cost
    end
  end

  xPlayer.addAccountMoney('bank', totalCost * 0.75)
  local resetUpgrades = json.encode({ durability = 0, efficiency = 0, max_capacity = 0, grid_connection = 0, security = 0 })
  MySQL.update.await('UPDATE `lsn-voltage` SET `owner` = ?, `durability` = ?, `upgrades` = ? WHERE `id` = ?',
    { '0', 100, resetUpgrades, turbineId })
  local newTurbine = MySQL.single.await('SELECT * from `lsn-voltage` WHERE `id` = ?', { turbineId })
  TriggerClientEvent('lsn-voltage:client:getTurbineData', -1, newTurbine)
  return 'sold'
end)

lib.callback.register('lsn-voltage:server:sellBatteries', function(source, batteries, paymentOption)
  local xPlayer = ESX.GetPlayerFromId(source)
  if not xPlayer then
    dbug('Player not found for source: ' .. source)
    return
  end

  local price = batteries * Config.priceForEnergy
  xPlayer.addAccountMoney(paymentOption, price)
  xPlayer.removeInventoryItem(Config.energyItemName, batteries)
  return 'sold', price
end)

lib.callback.register('lsn-voltage:server:sellTurbineCost', function(source, turbineId)
  if not turbineId then
    return false
  end
  local xPlayer = ESX.GetPlayerFromId(source)
  if not xPlayer then
    dbug('Player not found for source: ' .. source)
    return
  end

  local identifier = xPlayer.identifier
  local turbine = MySQL.single.await('SELECT * from `lsn-voltage` WHERE `id` = ?', { turbineId })

  if turbine.owner ~= identifier then
    print(
      '\n^8[CHEATING ALERT]^7 lsn-voltage:server:sellTurbine was executed incorrectly!',
      '\n^8[CHEATING ALERT]^7 Player Name: ' .. GetPlayerName(source),
      '\n^8[CHEATING ALERT]^7 ' .. GetPlayerIdentifier(source, 0),
      '\n^8[CHEATING ALERT]^7 This Player tried to trigger a sell event, which is not correct'
    )
    return
  end

  local upgrades = GetUpgrades(turbineId)
  local totalCost = Config.buyPrice

  for _, v in pairs({ "durability", "efficiency", "max_capacity", "grid_connection", "security" }) do
    if upgrades[v] > 0 then
      totalCost = totalCost + Config.Upgrades[v][upgrades[v]].cost
    end
  end
  local cost = totalCost * 0.75

  return cost, totalCost
end)

lib.callback.register('lsn-voltage:server:sellTurbineToPlayer',
  function(source, turbineId, targetIdentifier, sellingPrice)
    if not turbineId then return false end

    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then
      dbug('Player not found for source: ' .. source)
      return
    end

    local buyer = ESX.GetPlayerFromIdentifier(targetIdentifier)

    if not buyer then
      return 'not_found'
    end

    local alreadyOwned = MySQL.single.await('SELECT `id` FROM `lsn-voltage` WHERE `owner` = ?', { targetIdentifier })
    if alreadyOwned then
      return 'owned'
    end

    TriggerClientEvent('lsn-voltage:client:confirmTurbinePurchase', buyer.source, source, turbineId, sellingPrice)

    return 'pending'
  end)

lib.callback.register('lsn-voltage:server:repairTurbine', function(source, turbineId)
  if not turbineId then
    return false
  end
  local xPlayer = ESX.GetPlayerFromId(source)
  if not xPlayer then
    dbug('Player not found for source: ' .. source)
    return
  end

  local identifier = xPlayer.identifier
  local turbine = MySQL.single.await('SELECT * from `lsn-voltage` WHERE `id` = ?', { turbineId })

  if turbine.owner ~= identifier then
    print(
      '\n^8[CHEATING ALERT]^7 lsn-voltage:server:repairTurbine was executed incorrectly!',
      '\n^8[CHEATING ALERT]^7 Player Name: ' .. GetPlayerName(source),
      '\n^8[CHEATING ALERT]^7 ' .. GetPlayerIdentifier(source, 0),
      '\n^8[CHEATING ALERT]^7 This Player tried to trigger a repair event, which is not correct'
    )
    return
  end

  local upgrades = GetUpgrades(turbine.id)
  local setDurability = 100 + Config.Upgrades["durability"][upgrades.durability].effect

  if turbine.durability >= setDurability then return 0 end

  local lostPercent = setDurability - turbine.durability
  local cost = lostPercent * Config.repairCostPerPercent -- 100$

  if xPlayer.getAccount('bank').money >= cost then
    xPlayer.removeAccountMoney('bank', cost)
  else
    return 'nomoney', cost
  end

  MySQL.update.await('UPDATE `lsn-voltage` SET `durability` = ? WHERE `id` = ?', { setDurability, turbineId })
  return 'repaired', cost
end)

lib.callback.register('lsn-voltage:server:repairTurbineCost', function(source, turbineId)
  if not turbineId then
    return false
  end

  local turbine = MySQL.single.await('SELECT `durability` from `lsn-voltage` WHERE `id` = ?', { turbineId })
  local upgrades = GetUpgrades(turbineId)
  local setDurability = 100 + Config.Upgrades["durability"][upgrades.durability].effect

  if turbine.durability >= setDurability then return 0 end

  local lostPercent = setDurability - turbine.durability
  local cost = lostPercent * Config.repairCostPerPercent -- 100$

  return cost
end)

--------------------------------------[[ EVENTS ]]--------------------------------------

RegisterNetEvent('lsn-voltage:server:finalizeTurbinePurchase', function(src, turbineId, price)
  local buyer = ESX.GetPlayerFromId(source)
  local seller = ESX.GetPlayerFromId(src)

  if not buyer or not seller then return end

  if buyer.getAccount('bank').money < price then
    TriggerClientEvent('ox_lib:notify', buyer.source,
      { title = locale("ui.windmill_manager"), description = locale("ui.selltoplayer_nomoney"), type = 'error' })
    TriggerClientEvent('ox_lib:notify', seller.source,
      { title = locale("ui.windmill_manager"), description = locale("ui.selltoplayer_nomoney2"), type = 'error' })
    return
  end

  buyer.removeAccountMoney('bank', price)
  seller.addAccountMoney('bank', price)

  transferTurbineOwnership(turbineId, buyer.source)

  TriggerClientEvent('ox_lib:notify', seller.source, {
    title = locale("ui.windmill_manager"),
    description = locale("ui.selltoplayer_sold", formatWithCommas(price)),
    type = 'success'
  })

  TriggerClientEvent('ox_lib:notify', buyer.source, {
    title = locale("ui.windmill_manager"),
    description = locale("ui.selltoplayer_bought", formatWithCommas(price)),
    type = 'success'
  })
end)

RegisterNetEvent('lsn-voltage:server:cancelTurbinePurchase', function(src)
  local seller = ESX.GetPlayerFromId(src)
  if seller then
    TriggerClientEvent('ox_lib:notify', seller.source, {
      title = locale("ui.windmill_manager"),
      description = locale("ui.selltoplayer_declined"),
      type = 'error'
    })
  end
end)

RegisterNetEvent('lsn-voltage:server:getRewards', function(id, energy_amount)
  local src = source
  local xPlayer = ESX.GetPlayerFromId(src)
  local upgrades = GetUpgrades(id)
  if not xPlayer then return end

  local canCarry = exports.ox_inventory:CanCarryAmount(src, Config.energyItemName)
  local amountToAdd = (energy_amount * Config.Upgrades["security"][upgrades.security].effect) / 5

  if math.floor(amountToAdd) <= canCarry then
    exports.ox_inventory:AddItem(src, Config.energyItemName, amountToAdd)
  else
    local playerPed = GetPlayerPed(src)
    local playerCoords = GetEntityCoords(playerPed)
    local finalCoords = vec3(playerCoords.x, playerCoords.y, playerCoords.z - 1)

    exports.ox_inventory:CustomDrop(Config.energyItemName, {
      { Config.energyItemName, math.floor(amountToAdd) }
    }, finalCoords, 1, 120000, nil, 'prop_battery_02')

    TriggerClientEvent('ox_lib:notify', src, {
      title = locale("robbing.windmill_robbing"),
      description = locale("robbing.no_space"),
      type = 'error'
    })
  end
  windmillCooldowns[id] = GetGameTimer()
  MySQL.update.await('UPDATE `lsn-voltage` SET `energy_amount` = `energy_amount` - ? WHERE `id` = ?',
    { amountToAdd * 5, id })
end)

--------------------------------------[[ USEABLE ITEM / COMMAND ]]--------------------------------------

if Config.allowSabotage then
  ESX.RegisterUsableItem(Config.mainHackingTool, function(source)
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer or not xPlayer.getInventoryItem(Config.mainHackingTool).count > 0 then return end

    RobWindmill(source)
  end)
end

lib.addCommand('checkwindmills', {
  help = 'Check all the Windmills that are out there.',
  restricted = 'group.admin'
}, function(source)
  TriggerClientEvent("lsn-voltage:client:windmillAdminMenu", source)
end)

lib.addCommand('createwindmill', {
  help = 'Create a new Windmill.',
  restricted = 'group.admin'
}, function(source)
  TriggerClientEvent("lsn-voltage:client:createNewWindmill", source)
end)
--------------------------------------[[ EVENTHANDLER ]]--------------------------------------

AddEventHandler('onResourceStart', function(resourceName)
  if (GetCurrentResourceName() ~= resourceName) then return end

  local turbines = MySQL.query.await('SELECT * from `lsn-voltage` WHERE NOT `owner` = ?', { '0' })

  if #turbines <= 0 then return dbug('no turbines owned') end

  local function GetDurabilityLoss()
    return math.random(5, 7)
  end

  for i = 1, #turbines do
    local newDurability = turbines[i].durability - GetDurabilityLoss()
    energyGain = math.floor(setEnergyGain(turbines[i].id))

    if newDurability < 0 then
      newDurability = 0
      return
    elseif turbines[i].durability <= 5 then
      return
    end
    local upgrades = GetUpgrades(turbines[i].id)
    local addedCapacity = Config.Upgrades["max_capacity"][upgrades.max_capacity].effect
    local completeMaxCapacity = Config.DefaultStorage + addedCapacity
    local updatedEnergy = turbines[i].energy_amount + energyGain

    while updatedEnergy > completeMaxCapacity do
      if upgrades.grid_connection > 0 then
        local energyOverflow = updatedEnergy - completeMaxCapacity
        local price = energyOverflow * Config.priceForOverflowEnergy

        local affectedRows = MySQL.update.await('UPDATE users SET bank = bank + ? WHERE identifier = ?',
          { price, turbines[i].owner })

        if affectedRows > 0 then
          dbug("added: $" .. price .. " to Player: " .. turbines[i].owner)
        else
          dbug("Player with identifier " .. turbines[i].owner .. " not found or UPDATE didnt work.")
        end
      end

      updatedEnergy = completeMaxCapacity
    end

    MySQL.update.await(
      'UPDATE `lsn-voltage` SET `energy_amount` = ?, `durability` = ? WHERE `id` = ?',
      { updatedEnergy, newDurability, turbines[i].id }
    )
  end
end)
