local PlayersDiceData = {}
local ModDataCommands = {}

--***************************
--* Main syncing functions

---Gets a FULL table from a client. Extremely heavy
---@param playerObj IsoPlayer
---@param args {data : table, username : string}
function ModDataCommands.UpdatePlayerStats(playerObj, args)
	print("DiceSystem: Syncing player data for " .. args.username)
	if PlayersDiceData == nil then return end
	if args == nil then
		args = {
			data = {},
			username = playerObj:getUsername()
		}
	end

	PlayersDiceData[args.username] = args.data
	ModData.add(DICE_SYSTEM_MOD_STRING, PlayersDiceData)

	-- NO NO NO NO NEVER DO THIS IF WE'RE GONNA USE IT ON BIG SERVERS!!!!
	--ModData.transmit(DICE_SYSTEM_MOD_STRING)
end

---Force reset a certain player dice data on the server and send a force reset on the selected client
---@param args table
function ModDataCommands.ResetServerDiceData(_, args)
	local receivingPl = getPlayerByOnlineID(args.userID)

	-- TODO This is not working correctly

	PlayersDiceData[args.username] = {}
	ModData.add(DICE_SYSTEM_MOD_STRING, PlayersDiceData) -- Force update just to be sure that it's synced
	sendServerCommand(receivingPl, DICE_SYSTEM_MOD_STRING, "ResetClientDiceData", { forceSync = false})
end

---Similiar to ResetServerDiceData, but we'll skip the destroying part. We just notify the client that their data has been changed elsewhere
---@param args table userID=number
function ModDataCommands.NotifyAdminChangedClientData(_, args)
	--print("NotifyAdminChangedClientData")
	--print(args.userID)
	local receivingPl = getPlayerByOnlineID(args.userID)
	sendServerCommand(receivingPl, DICE_SYSTEM_MOD_STRING, "ResetClientDiceData", { forceSync = true })
end

---Send the full status effects table to a certain player
---@param playerObj IsoPlayer The player that requested the update and whom shall receive the updated table
---@param args table username=string, userID=number
function ModDataCommands.RequestUpdatedStatusEffects(playerObj, args)
	if args.username and args.userID and PlayersDiceData[args.username] then
		local statusEffectsTable = PlayersDiceData[args.username].statusEffects
		local userID = args.userID
		sendServerCommand(playerObj, DICE_SYSTEM_MOD_STRING, 'ReceiveUpdatedStatusEffects',
			{ userID = userID, statusEffectsTable = statusEffectsTable })
	end
end

--***************************
--* Player initialization methods

---Set the max health for a player
---@param args table maxHealth=number, username=string
function ModDataCommands.SetMaxHealth(_, args)
	local maxHealth = args.maxHealth
	PlayersDiceData[args.username].maxHealth = maxHealth
end

---Set the skills table
---@param args table skillsTable=table, username=string
function ModDataCommands.SetSkills(_, args)
	local skillsTable = args.skillsTable
	PlayersDiceData[args.username].skills = skillsTable
end

---Set occupation and related bonus points
---@param args table occupation=string, skillsBonus=table
function ModDataCommands.SetOccupation(_, args)
	local occupation = args.occupation
	local skillsBonus = args.skillsBonus

	PlayersDiceData[args.username].occupation = occupation
	PlayersDiceData[args.username].skillsBonus = skillsBonus
end

--***************************
--* Player updates functions
-- These can be run after a player has been initialized


---@param args { stat : string, currentVal : string, username : string}
function ModDataCommands.UpdateCurrentStat(_, args)
	local currentVal = args.currentVal
	local stat = args.stat
	PlayersDiceData[args.username]['current' .. stat] = currentVal
end

function ModDataCommands.UpdateCurrentHealth(_, args)
	local currentHealth = args.currentHealth
	PlayersDiceData[args.username].currentHealth = currentHealth
end

function ModDataCommands.UpdateCurrentMovement(_, args)
	local currentMovement = args.currentMovement
	PlayersDiceData[args.username].currentMovement = currentMovement
end

function ModDataCommands.UpdateMaxMovement(_, args)
	local maxMovement = args.maxMovement
	PlayersDiceData[args.username].maxMovement = maxMovement
end

function ModDataCommands.UpdateMovementBonus(_, args)
	local movementBonus = args.movementBonus
	PlayersDiceData[args.username].movementBonus = movementBonus
end

function ModDataCommands.UpdateArmorBonus(_, args)
	local armorBonus = args.armorBonus
	PlayersDiceData[args.username].armorBonus = armorBonus
end

function ModDataCommands.UpdateStatusEffect(_, args)
	--print("Update status effect")

	local isActive = args.isActive
	local statusEffect = args.statusEffect
	local userID = args.userID
	-- print(statusEffect)
	-- print(isActive)
	PlayersDiceData[args.username].statusEffects[statusEffect] = isActive

	if userID then
		sendServerCommand(DICE_SYSTEM_MOD_STRING, 'ReceiveUpdatedStatusEffects',
			{ statusEffectsTable = PlayersDiceData[args.username].statusEffects, userID = userID })
	--else
		--print("Couldn't find " .. args.username)
	end



	--print(PlayersDiceData[args.username].statusEffects[statusEffect])
end

--****************************************************-

local function OnClientCommand(module, command, playerObj, args)
	if module ~= DICE_SYSTEM_MOD_STRING then return end
	--print("Received ModData command " .. command)
	if ModDataCommands[command] and PlayersDiceData ~= nil then
		ModDataCommands[command](playerObj, args)
		ModData.add(DICE_SYSTEM_MOD_STRING, PlayersDiceData)
	end
end

Events.OnClientCommand.Add(OnClientCommand)


------------------------------
-- Handle Global Mod Data

local function OnInitGlobalModData()
	--print("Initializing global mod data")
	PlayersDiceData = ModData.getOrCreate(DICE_SYSTEM_MOD_STRING)
end
Events.OnInitGlobalModData.Add(OnInitGlobalModData)
