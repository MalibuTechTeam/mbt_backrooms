local isFalling, veh = false, false
local playerCoords, playerPed, playerPed
local isNear = false
local nearestLocation

Citizen.CreateThread(function()
	Citizen.Wait(1000)
	
	while true do
		sleep = 1000

		playerPed = PlayerPedId()
	
		if IsEntityDead(playerPed) or not DoesEntityExist(playerPed) then
			Citizen.Wait(1000) 
			goto ignoring
		end
		
		isFalling = false
		veh = GetVehiclePedIsIn(playerPed, false)

		playerCoords = GetEntityCoords(playerPed)
		_, z = GetGroundZFor_3dCoord(playerCoords.x, playerCoords.y, 150.0, 0) 

        if playerCoords.z < MBT.FallingPoint then
		
			if IsPedSwimming(playerPed) or IsPedSwimmingUnderWater(playerPed) or (not IsPedFalling(playerPed) and veh == 0) then
				goto ignoring
			end

			if IsPedFalling(playerPed) then
				isFalling = true
			end

			if veh ~= 0 and IsEntityInAir(veh) then
				isFalling = true
			end

			if isFalling then
				sleep = 100
				ClearPedTasksImmediately(playerPed)
				local randomBackroom = MBT.Coords[math.random(1, #MBT.Coords)]

				teleportPlayer({
					playerPed = playerPed,
					randomBackroom = randomBackroom
				})

			end
		end
		
		::ignoring::
		Citizen.Wait(sleep)
	end
end)

Citizen.CreateThread(function()
	local currentLocation

	RegisterCommand('handleBackroomAction', function()
		if not isNear then return end
		if nearestLocation.Type == "Exit" then
			local playerPed = PlayerPedId()
			 
			math.randomseed(GetGameTimer()*math.random(30568, 90214))
			local randomChance = math.random(1, 100)
			print("randomChance: ", randomChance)
			if randomChance < 70 then
				local randomBackroom = MBT.Coords[math.random(1, #MBT.Coords)]
				teleportPlayer({
					playerPed = playerPed,
					randomBackroom = randomBackroom
				})
			else
				local randomExitPoint = MBT.RandomExitPoint[math.random(1, #MBT.RandomExitPoint)]
				teleportPlayer({
					playerPed = playerPed,
					randomBackroom = randomExitPoint
				})
			end
		elseif nearestLocation.Type == "Enter" then 
			local randomBackroom = MBT.Coords[math.random(1, #MBT.Coords)]
			teleportPlayer({
				playerPed = playerPed,
				randomBackroom = randomBackroom
			})
		end
	end, true)

	while true do
		sleep = 500
		local playerPed = PlayerPedId()
		local playerCoords = GetEntityCoords(playerPed)
		isNear = false

		for i=1, #MBT.BackRooms do
			currentLocation = MBT.BackRooms[i]
			if not isNear then
				local distance = #(playerCoords - currentLocation.Coords)
				-- print("distance is ", distance)
				isNear = true
				nearestLocation = currentLocation
				if distance > nearestLocation.Range then isNear = false; nearestLocation = nil end
			end
		end
		
		if isNear then 
			sleep = 5 
			showHelpNotification("~INPUT_CONTEXT~ "..nearestLocation.Label)
		else 
			sleep = 500
			nearestLocation = nil
		end
		Citizen.Wait(sleep)
	end
end)

RegisterKeyMapping('handleBackroomAction', 'Backroom', 'keyboard', 'E')

function teleportPlayer(data)
	FreezeEntityPosition(data.playerPed, true)
	RequestCollisionAtCoord(data.randomBackroom.x, data.randomBackroom.y, data.randomBackroom.z)
	while not HasCollisionLoadedAroundEntity(data.playerPed) do
		Wait(0)
	end
	SetEntityCoordsNoOffset(playerPed, data.randomBackroom.x, data.randomBackroom.y, data.randomBackroom.z, true, false, false)
	Wait(1200)
	FreezeEntityPosition(data.playerPed, false)
end


function showHelpNotification(text)
    BeginTextCommandDisplayHelp("THREESTRINGS")
    AddTextComponentSubstringPlayerName(text)
    EndTextCommandDisplayHelp(0, false, true, 5000)
end