-- Auteur : https://www.linkedin.com/in/spilerstheo/

local debugMode = true -- Activer/Désactiver le mode debug

local JetModel = GetHashKey("lazer")
local PilotModel = GetHashKey("s_m_y_pilot_01")
local jets = {}
local lastWarningTime = 0
local lastCheckTime = 0
local baseMilitaryStart = {x = -2090.0, y = 2906.0, z = 32.0, heading = 53.85} -- Début de la piste
local baseMilitaryEnd = {x = -2592.0, y = 3196.0, z = 32.0, heading = 53.85} -- Fin de la piste

function debugPrint(msg)
    if debugMode then
        print("[DEBUG] " .. msg)
    end
end

function spawnJets()
    debugPrint("Lancement du spawn des avions.")
    local playerCoords = GetEntityCoords(PlayerPedId())
    RequestModel(JetModel)
    RequestModel(PilotModel)
    while not HasModelLoaded(JetModel) or not HasModelLoaded(PilotModel) do
        Wait(10)
    end

    for i = 1, 2 do -- Spawner 2 avions de chasse à la base militaire et les faire rouler sur la piste avant de décoller
        local jet = CreateVehicle(JetModel, baseMilitaryStart.x + (i * 10.0), baseMilitaryStart.y + (i * 10.0), baseMilitaryStart.z, baseMilitaryStart.heading, true, true)
        local pilot = CreatePedInsideVehicle(jet, 4, PilotModel, -1, true, true)
        debugPrint("Avion de chasse spawn à la base militaire")
    
        -- Faire rouler l'avion sur la piste
        TaskVehicleDriveToCoordLongrange(pilot, jet, baseMilitaryEnd.x, baseMilitaryEnd.y, baseMilitaryEnd.z, 100.0, 262144, 2.0)
        Citizen.Wait(15000) -- Temps de roulage avant décollage

        TaskPlaneMission(pilot, jet, 0, PlayerPedId(), 0.0, 0.0, 0.0, 6, 500.0, 0, -1.0, 0, 30.0)
        debugPrint("Avion de chasse en mission de poursuite")
        
        -- Competence de IA
        SetRelationshipBetweenGroups(5, GetPedRelationshipGroupHash(pilot), GetPedRelationshipGroupHash(PlayerPedId())) -- IA hait le joueur 5 niv max
        SetPedCombatAttributes(pilot, 46, true) -- Rendre l'IA agressive
        SetPedCombatAttributes(pilot, 46, true) -- Dog Fight
        SetPedCombatAttributes(pilot, 5, true)  -- Toujours attaquer
        SetPedCombatAbility(pilot, 2)           -- Meilleur niveau de compétence
        SetPedAccuracy(pilot, 100)              -- Précision maximale
        SetPedCombatRange(pilot, 2)             -- Portée de combat élevée
        SetPedCombatMovement(pilot, 3)          -- IA extrêmement mobile
        SetPedFleeAttributes(pilot, 0, false)   -- Ne jamais fuir

        -- Perf avion IA
        SetVehicleEnginePowerMultiplier(jet, 3.0)  -- Plus de puissance moteur
        SetVehicleEngineTorqueMultiplier(jet, 3.0) -- Plus de couple moteur
        SetVehicleForwardSpeed(jet, 500.0) -- Accélérer encore plus

        table.insert(jets, {jet = jet, pilot = pilot})
    end
end

Citizen.CreateThread(function()
    while true do
        Citizen.Wait(5000)
        local ped = PlayerPedId()
        if IsPedInAnyVehicle(ped, false) then
            local veh = GetVehiclePedIsIn(ped, false)
            local vehClass = GetVehicleClass(veh)

            if vehClass == 15 or vehClass == 16 then -- Avion ou Hélicoptère
                local hasFlyCard = exports.ox_inventory:Search('count', 'flycard') > 0 --Changer ici item que vous voulez choisir comme licence de vol
                debugPrint("Joueur dans un aéronef. Carte de vol : " .. tostring(hasFlyCard))

                -- Si le joueur a la flycard, on ne fait pas spawn les avions
                if hasFlyCard then
                    TriggerEvent('chat:addMessage', {
                        color = {0, 255, 0},
                        multiline = true,
                        args = {"Militaire", "Licence de vol reconnue, bon vol à vous !"}
                    })
                    goto continue -- Sauter le reste du code de spawn de jets
                end

                if #jets == 0 then
                    TriggerEvent('chat:addMessage', {
                        color = {255, 0, 0},
                        multiline = true,
                        args = {"Militaire", "Posez-vous immédiatement, où vous serez abattu !"}
                    })
                    Citizen.Wait(10000) -- Attente de 10 secondes avant de spawn les avions
                    spawnJets()
                    lastCheckTime = GetGameTimer()
                end

                -- Vérifier si un jet est détruit et en respawner un
                for i, v in ipairs(jets) do
                    if not DoesEntityExist(v.jet) or IsEntityDead(v.jet) then
                        debugPrint("Avion de chasse détruit, respawn en cours.")
                        table.remove(jets, i)
                        spawnJets()
                        break
                    end
                end

                -- Vérifier si les avions sont trop éloignés après 3 minutes
                local currentTime = GetGameTimer()
                if currentTime - lastCheckTime > 180000 then -- 3 minutes écoulées
                    debugPrint("Vérification de la distance des avions.")
                    local playerCoords = GetEntityCoords(PlayerPedId())
                    local jetsTooFar = true
                    for _, v in pairs(jets) do
                        if DoesEntityExist(v.jet) and #(GetEntityCoords(v.jet) - playerCoords) < 1000.0 then
                            jetsTooFar = false
                            break
                        end
                    end
                    if jetsTooFar then
                        debugPrint("Les avions sont trop loin, suppression et respawn.")
                        Citizen.Wait(5000)
                        for _, v in pairs(jets) do
                            if DoesEntityExist(v.jet) then
                                DeleteEntity(v.jet)
                            end
                            if DoesEntityExist(v.pilot) then
                                DeleteEntity(v.pilot)
                            end
                        end
                        jets = {}
                        spawnJets()
                        lastCheckTime = currentTime
                    end
                end

                ::continue::
            end
        else
            debugPrint("Le joueur a quitté son aéronef. Suppression des avions.")
            for _, v in pairs(jets) do
                if DoesEntityExist(v.jet) then
                    DeleteEntity(v.jet)
                end
                if DoesEntityExist(v.pilot) then
                    DeleteEntity(v.pilot)
                end
            end
            jets = {}
        end
    end
end)