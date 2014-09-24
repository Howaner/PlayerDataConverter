JSON = (loadfile "Plugins/PlayerDataConverter/JSON.lua")()
PLUGIN = nil
CachedPlayerData = {}

function Initialize(Plugin)
	PLUGIN = Plugin
	PLUGIN:SetName("PlayerDataConverter")
	PLUGIN:SetVersion(1)

	LOG("Initialised " .. PLUGIN:GetName() .. " v." .. PLUGIN:GetVersion())

	LOGINFO("------------ Begin Convert! ------------")
	StartConvert()
	LOGINFO("----------------------------------------")

	return true
end

function OnDisable()
	LOG(PLUGIN:GetName() .. " is shutting down...")
end

function StartConvert()
	LoadDataToCache("players")

	local NumberPlayerDatas = 0
	for PlayerName, FileContent in pairs(CachedPlayerData) do
		NumberPlayerDatas = NumberPlayerDatas + 1
	end
	if (NumberPlayerDatas == 0) then
		LOGWARNING("No user datas are available to convert!")
		return
	end

	-- Rename the players folder to oldPlayers
	if (cFile:Exists("oldPlayers")) then
		LOGWARNING("Please delete your oldPlayers folder!")
		return
	end
	cFile:Rename("players", "oldPlayers")

	-- Save the new player files
	SaveCachedPlayerDatas()
end

function LoadDataToCache(FilePath)
	if (cFile:IsFolder(FilePath)) then
		local FolderContents = cFile:GetFolderContents(FilePath)
		for Idx, Name in ipairs(FolderContents) do
			if ((Name ~= "") and (Name ~= ".") and (Name ~= "..")) then
				LoadDataToCache(FilePath .. "/" .. Name)
			end
		end
	elseif (cFile:IsFile(FilePath)) then
		local FileName = FilePath
		local LastSlashIndex = FilePath:match(".*%/()")
		if (LastSlashIndex ~= nil) then
			FileName = string.sub(FilePath, LastSlashIndex)
		end

		local NameLength = string.len(FileName)
		if ((NameLength ~= 39) or (string.sub(FileName, 35) ~= ".json")) then
			-- This isn't a valid player file
			return
		end

		-- Load the file text
		local FileContent = cFile:ReadWholeFile(FilePath)
		if (FileContent == "") then
			LOGWARNING("Can't load \"" .. FileName .. "\"")
			return
		end

		-- Decode json text
		local JsonRoot = JSON:decode(FileContent, FilePath)
		if (JsonRoot == nil) then
			-- Decode failed
			return
		end

		-- Get the player name
		local PlayerName = JsonRoot["lastknownname"]
		if (PlayerName == nil) then
			LOGWARNING("JSON: Decode from file \"" .. FilePath .. "\" failed: No lastknownname entry")
			return
		end

		CachedPlayerData[PlayerName] = FileContent
	end
end

function SaveCachedPlayerDatas()
	-- Create a new players folder:
	cFile:CreateFolder("players")

	for PlayerName, FileContent in pairs(CachedPlayerData) do
		local UUID = FindPlayerUUID(PlayerName)
		if ((UUID == nil) or (UUID == "")) then
			LOGWARNING("Can't load UUID from \"" .. PlayerName .. "\"!")
		else
			local DashedUUID = cMojangAPI:MakeUUIDDashed(UUID)

			-- Create the folder for the uuid
			local FolderName = "players/" .. string.sub(UUID, 0, 2)
			if (not cFile:IsFolder(FolderName)) then
				cFile:CreateFolder(FolderName)
			end

			-- Create the player file
			local FilePath = FolderName .. "/" .. string.sub(DashedUUID, 3) .. ".json"
			if (not cFile:IsFile(FilePath)) then
				local FileStream, State = io.open(FilePath, "w")
				if (FileStream == nil) then
					LOGWARNING("Can't create a stream for file \"" .. FilePath .. "\": " .. State)
				else
					FileStream:write(FileContent)
					FileStream:close()
					LOGINFO("Converted player " .. PlayerName .. "!")
				end
			end
		end
	end
end

function FindPlayerUUID(PlayerName)
	if (cRoot:Get():GetServer():ShouldAuthenticate()) then
		-- Return online uuid
		return cMojangAPI:GetUUIDFromPlayerName(PlayerName, false)
	else
		-- Return offline uuid
		return cClientHandle:GenerateOfflineUUID(PlayerName)
	end
end

function JSON:onDecodeError(Message, Text, Location, Etc)
	LOGWARNING("JSON: Decode from file \"" .. Etc .. "\" failed: " .. Message)
end
