-- Auteur : https://www.linkedin.com/in/spilerstheo/

local debugMode = true -- Activer/Désactiver le mode debug

local JetModel = GetHashKey("lazer")
local PilotModel = GetHashKey("s_m_y_pilot_01")
local jets = {}
local jetBlips = {} 
local lastCheckTime = 0
local isPlayerInAircraft = false
local lastVehicle = nil

local baseMilitaryStart = {x = -2090.0, y = 2906.0, z = 33.0, heading = 53.85} -- Début de la piste
local baseMilitaryEnd = {x = -2592.0, y = 3196.0, z = 33.0, heading = 53.85} -- Fin de la piste

function debugPrint(msg)
    if debugMode then
        print("[DEBUG] " .. msg)
    end
end

function spawnJets()
    debugPrint("Lancement du spawn des avions.")
    RequestModel(JetModel)
    RequestModel(PilotModel)
    while not HasModelLoaded(JetModel) or not HasModelLoaded(PilotModel) do
        Wait(10)
    end

    for i = 1, 2 do
        local jet = CreateVehicle(JetModel, baseMilitaryStart.x + (i * 10.0), baseMilitaryStart.y + (i * 10.0), baseMilitaryStart.z, baseMilitaryStart.heading, true, true)
        local pilot = CreatePedInsideVehicle(jet, 4, PilotModel, -1, true, true)
        debugPrint("Avion de chasse spawn à la base militaire")

        TaskVehicleDriveToCoordLongrange(pilot, jet, baseMilitaryEnd.x, baseMilitaryEnd.y, baseMilitaryEnd.z, 200.0, 262144, 2.0)
        Citizen.Wait(8000)
        TaskPlaneMission(pilot, jet, 0, 0, baseMilitaryEnd.x, baseMilitaryEnd.y, baseMilitaryEnd.z + 200.0, 4, 400.0, 0, -1.0, 0, 30.0)
        Citizen.Wait(3000)
        TaskPlaneMission(pilot, jet, 0, PlayerPedId(), 0.0, 0.0, 0.0, 6, 500.0, 0, -1.0, 0, 30.0)
        debugPrint("Avion de chasse en mission de poursuite")

        local blip = AddBlipForEntity(jet)
        SetBlipSprite(blip, 16)
        SetBlipColour(blip, 1)
        SetBlipScale(blip, 1.0)
        BeginTextCommandSetBlipName("STRING")
        AddTextComponentString("Avion de chasse")
        EndTextCommandSetBlipName(blip)

        table.insert(jetBlips, blip)
        table.insert(jets, {jet = jet, pilot = pilot, blip = blip})
    end
end

function removeJets()
    debugPrint("Suppression des avions et blips.")
    for _, v in pairs(jets) do
        if DoesEntityExist(v.jet) then
            DeleteEntity(v.jet)
        end
        if DoesEntityExist(v.pilot) then
            DeleteEntity(v.pilot)
        end
        if DoesBlipExist(v.blip) then
            RemoveBlip(v.blip)
        end
    end
    jets = {}
    jetBlips = {}
end

Citizen.CreateThread(function()
    while true do
        Citizen.Wait(1000)
        local ped = PlayerPedId()
        local veh = GetVehiclePedIsIn(ped, false)
        local vehClass = veh and GetVehicleClass(veh) or -1
        
        if vehClass == 15 or vehClass == 16 then
            if lastVehicle ~= veh then
                debugPrint("Joueur entré dans un aéronef.")
                lastVehicle = veh
                isPlayerInAircraft = true

                local hasFlyCard = exports.ox_inventory:Search('count', 'flycard') > 0
                if hasFlyCard then
                    TriggerEvent('chat:addMessage', {
                        color = {0, 255, 0},
                        multiline = true,
                        args = {"Militaire", "Licence de vol reconnue, bon vol à vous !"}
                    })
                    removeJets()
                else
                    TriggerEvent('chat:addMessage', {
                        color = {255, 0, 0},
                        multiline = true,
                        args = {"Militaire", "Posez-vous immédiatement, ou vous serez abattu !"}
                    })
                    Citizen.Wait(10000)
                    spawnJets()
                    lastCheckTime = GetGameTimer()
                end
            end
        elseif isPlayerInAircraft then
            debugPrint("Joueur a quitté son aéronef. Suppression des avions.")
            isPlayerInAircraft = false
            lastVehicle = nil
            removeJets()
        end
    end
end)