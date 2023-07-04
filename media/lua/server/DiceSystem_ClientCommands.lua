local PlayersDiceData = {}

local function OnClientCommand(module, command, playerObj, args)
	if module ~= DICE_SYSTEM_MOD_STRING then return end

	if command == "updatePlayerStats" then
		if PlayersDiceData == nil then return end
		if args == nil then
			args = {
				data = nil,
				username = playerObj:getUsername()
			}
		end

		PlayersDiceData[args.username] = args.data
		ModData.add(DICE_SYSTEM_MOD_STRING, PlayersDiceData)
		ModData.transmit(DICE_SYSTEM_MOD_STRING)
	elseif command == "resetDiceData" then
		local receivingPl = getPlayerByOnlineID(args.userID)
		sendServerCommand(receivingPl, DICE_SYSTEM_MOD_STRING, "receiveResetDiceData", {})
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
