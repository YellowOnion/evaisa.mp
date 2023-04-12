local steamutils = dofile_once("mods/evaisa.mp/lib/steamutils.lua")
local player = dofile("mods/evaisa.arena/files/scripts/gamemode/helpers/player.lua")
local entity = dofile("mods/evaisa.arena/files/scripts/gamemode/helpers/entity.lua")
local counter = dofile_once("mods/evaisa.arena/files/scripts/utilities/ready_counter.lua")
local countdown = dofile_once("mods/evaisa.arena/files/scripts/utilities/countdown.lua")
local json = dofile("mods/evaisa.arena/lib/json.lua")
dofile_once("mods/evaisa.arena/content/data.lua")

ArenaGameplay = {
    GetNumRounds = function()
        local holyMountainCount = tonumber(GlobalsGetValue("holyMountainCount", "0")) or 0
        return holyMountainCount
    end,
    AddRound = function()
        local holyMountainCount = tonumber(GlobalsGetValue("holyMountainCount", "0")) or 0
        holyMountainCount = holyMountainCount + 1
        GlobalsSetValue("holyMountainCount", tostring(holyMountainCount))
    end,
    RemoveRound = function()
        local holyMountainCount = tonumber(GlobalsGetValue("holyMountainCount", "0")) or 0
        holyMountainCount = holyMountainCount - 1
        GlobalsSetValue("holyMountainCount", tostring(holyMountainCount))
    end,
    SendGameData = function(lobby, data)
        steam.matchmaking.setLobbyData(lobby, "holyMountainCount", tostring(ArenaGameplay.GetNumRounds()))
        local ready_players = {}
        local members = steamutils.getLobbyMembers(lobby)
        for k, member in pairs(members)do
            if(member.id ~= steam.user.getSteamID())then
                if(data.players[tostring(member.id)] ~= nil and data.players[tostring(member.id)].ready)then
                    table.insert(ready_players, tostring(member.id))
                end
            end
        end
        steam.matchmaking.setLobbyData(lobby, "ready_players", bitser.dumps(ready_players))
    end,
    GetGameData = function(lobby, data)
        local mountainCount = tonumber(steam.matchmaking.getLobbyData(lobby, "holyMountainCount"))
        if(mountainCount ~= nil)then
            GlobalsSetValue("holyMountainCount", tostring(mountainCount))
            print("Holymountain count: "..mountainCount)
        end
        local goldCount = tonumber(steam.matchmaking.getLobbyData(lobby, "total_gold"))
        if(goldCount ~= nil)then
            data.client.first_spawn_gold = goldCount
            print("Gold count: "..goldCount)
        end
        local playerData = steamutils.GetLocalLobbyData(lobby, "player_data")--steam.matchmaking.getLobbyMemberData(lobby, steam.user.getSteamID(), "player_data")

        
        if(playerData ~= nil and playerData ~= "")then
            data.client.player_loaded_from_data = true
            data.client.serialized_player = bitser.dumps(playerData)
            print("Player data: "..data.client.serialized_player)
        end
        local ready_players_string = steam.matchmaking.getLobbyData(lobby, "ready_players")
        local ready_players = (ready_players_string ~= nil and ready_players_string ~= "null") and bitser.loads(ready_players_string) or nil
        local members = steamutils.getLobbyMembers(lobby)

        print(tostring(ready_players_string))
        if(ready_players ~= nil)then
            for k, member in pairs(members)do
                if(member.id ~= steam.user.getSteamID())then
                    if(data.players[tostring(member.id)] ~= nil and data.players[tostring(member.id)].ready)then
                        data.players[tostring(member.id)].ready = false
                    end
                end
            end
            for k, member in pairs(ready_players)do
                if(data.players[member] ~= nil)then
                    data.players[member].ready = true
                end
            end
        end
    end,
    ReadyAmount = function(data, lobby)
        local amount = data.client.ready and 1 or 0
        local members = steamutils.getLobbyMembers(lobby)
        for k, member in pairs(members)do
            if(member.id ~= steam.user.getSteamID())then
                if(data.players[tostring(member.id)] ~= nil and data.players[tostring(member.id)].ready)then
                    amount = amount + 1
                end
            end
        end
        return amount
    end,
    FindUser = function(lobby, user_string)
        local members = steamutils.getLobbyMembers(lobby)
        for k, member in pairs(members)do
            --print("Member: " .. tostring(member.id))
            if(tostring(member.id) == user_string)then
                return member.id
            end
        end
        return nil
    end,
    TotalPlayers = function(lobby)
        local amount = 0
        for k, v in pairs(steamutils.getLobbyMembers(lobby))do
            amount = amount + 1
        end
        return amount
    end,
    ReadyCounter = function(lobby, data)
        data.ready_counter = counter.create("Players ready: ", function()
            local playersReady = ArenaGameplay.ReadyAmount(data, lobby)
            local totalPlayers = ArenaGameplay.TotalPlayers(lobby)
            
            return playersReady, totalPlayers
        end, function()
            data.ready_counter = nil
        end)
    end,
    LoadPlayer = function(lobby, data)
        local current_player = EntityLoad("data/entities/player.xml", 0, 0)
        game_funcs.SetPlayerEntity(current_player)
        player.Deserialize(data.client.serialized_player, (not data.client.player_loaded_from_data))
        np.RegisterPlayerEntityId(current_player)
        GameRemoveFlagRun("player_unloaded")
    end,
    AllowFiring = function()
        GameRemoveFlagRun("no_shooting")
    end,
    PreventFiring = function()
        GameAddFlagRun("no_shooting")
    end,
    CancelFire = function(lobby, data)
        local player_entity = player.Get()
        if(player_entity ~= nil)then
            local items = GameGetAllInventoryItems( player_entity ) or {}
            for k, item in ipairs(items)do
                local abilityComponent = EntityGetFirstComponentIncludingDisabled(item, "AbilityComponent")
                if(abilityComponent ~= nil)then
                    -- set mNextFrameUsable to false
                    ComponentSetValue2(abilityComponent, "mNextFrameUsable", GameGetFrameNum() + 10)
                    -- set mReloadFramesLeft
                    ComponentSetValue2(abilityComponent, "mReloadFramesLeft", 10)
                    -- set mReloadNextFrameUsable to false
                    ComponentSetValue2(abilityComponent, "mReloadNextFrameUsable", GameGetFrameNum() + 10)
    
                end
            end
        end

        for k, v in pairs(data.players)do
            if(v.entity ~= nil)then
                local item = v.held_item
                if(item ~= nil)then
                    local abilityComponent = EntityGetFirstComponentIncludingDisabled(item, "AbilityComponent")
                    if(abilityComponent ~= nil)then
                        -- set mNextFrameUsable to false
                        ComponentSetValue2(abilityComponent, "mNextFrameUsable", GameGetFrameNum() + 10)
                        -- set mReloadFramesLeft
                        ComponentSetValue2(abilityComponent, "mReloadFramesLeft", 10)
                        -- set mReloadNextFrameUsable to false
                        ComponentSetValue2(abilityComponent, "mReloadNextFrameUsable", GameGetFrameNum() + 10)
                    end
                end
            end
        end
    end,
    DamageZoneCheck = function(x, y, max_distance, distance_cap)
        local players = EntityGetWithTag("player_unit") or {}
        for k, v in pairs(players)do
            local x2, y2 = EntityGetTransform(v)
            local distance = math.sqrt((x2 - x) ^ 2 + (y2 - y) ^ 2)
            if(distance > max_distance)then
                local healthComp = EntityGetFirstComponentIncludingDisabled(v, "DamageModelComponent")
                if(healthComp ~= nil)then
                    local health = tonumber(ComponentGetValue(healthComp, "hp"))
                    local max_health = tonumber(ComponentGetValue(healthComp, "max_hp"))
                    local base_health = 4
                    local damage_percentage = (distance - max_distance) / distance_cap
                    local damage = max_health * damage_percentage
                    EntityInflictDamage(v, damage, "DAMAGE_FALL", "Out of bounds", "BLOOD_EXPLOSION", 0, 0)
                end
            end
        end
    end,
    WinnerCheck = function(lobby, data)
        local alive = data.client.alive and 1 or 0
        local winner = steam.user.getSteamID()
        for k, v in pairs(data.players)do
            if(v.alive)then
                alive = alive + 1
                winner = v.id
            end
        end
        if(alive == 1)then
            GamePrintImportant(steam.friends.getFriendPersonaName(winner) .. " won this round!", "Prepare for the next round in your holy mountain.")



            ArenaGameplay.LoadLobby(lobby, data, false)
        elseif(alive == 0)then
            GamePrintImportant("Nobody won this round!", "Prepare for the next round in your holy mountain.")

            ArenaGameplay.LoadLobby(lobby, data, false)
        end
    end,
    KillCheck = function(lobby, data)
        if(GameHasFlagRun("player_died"))then
            local killer = ModSettingGet("killer");
            local username = steam.friends.getFriendPersonaName(steam.user.getSteamID())

            if(killer == nil)then
                
                GamePrint(tostring(username) .. " died.")
            else
                local killer_id = ArenaGameplay.FindUser(lobby, killer)
                if(killer_id ~= nil)then
                    GamePrint(tostring(username) .. " was killed by " .. steam.friends.getFriendPersonaName(killer_id))
                else
                    GamePrint(tostring(username) .. " died.")
                end
            end

            --if(data.deaths == 0)then
                GameAddFlagRun("first_death")
                GamePrint("You will be compensated for dying.")
            --end

            data.deaths = data.deaths + 1
            data.client.alive = false

            message_handler.send.Death(lobby, killer)

            GameRemoveFlagRun("player_died")

            GamePrintImportant("You died!")

            GameSetCameraFree(true)

            player.Lock()
            player.Immortal(true)
            --player.Move(-3000, -3000)

            ArenaGameplay.WinnerCheck(lobby, data)
        end
    end,
    LoadLobby = function(lobby, data, show_message, first_entry)
        show_message = show_message or false
        first_entry = first_entry or false

        if(data.client.serialized_player)then
            first_entry = false
        end

        local current_player = player.Get()

        if(current_player == nil)then
            ArenaGameplay.LoadPlayer(lobby, data)
        end

        if(first_entry and player.Get())then
            GameDestroyInventoryItems( player.Get() )
        end

        -- clean other player's data
        ArenaGameplay.CleanMembers(lobby, data)

        -- manage flags
        GameRemoveFlagRun("player_ready")
        GameRemoveFlagRun("ready_check")
        GameRemoveFlagRun("player_unloaded")

        -- destroy active tweens
        data.tweens = {}
        
        -- clean local data
        data.client.ready = false
        data.client.alive = true
        data.client.previous_wand = nil
        data.client.previous_anim = nil
        data.client.projectile_seeds = {}
        --data.client.projectile_homing = {}

        -- set state
        data.state = "lobby"

        -- clean and unlock player entity
        player.Clean(first_entry)
        player.Unlock()

        GameRemoveFlagRun("player_is_unlocked")

        -- grant immortality
        player.Immortal(true)

        -- move player to correct position
        player.Move(174, 133)

        -- get rounds
        local rounds = ArenaGameplay.GetNumRounds()

        if(data.client.player_loaded_from_data)then
            GameAddFlagRun("skip_perks")
            GameAddFlagRun("skip_health")
            ArenaGameplay.RemoveRound()
        end

        -- Give gold
        local rounds_limited = math.max(0, math.min(math.ceil(rounds / 2), 7))
        local extra_gold = 400 + (70 * (rounds_limited * rounds_limited))

        --print("First spawn gold = "..tostring(data.client.first_spawn_gold))

        print("First entry = "..tostring(first_entry))

        if(first_entry and data.client.first_spawn_gold > 0)then
            extra_gold = data.client.first_spawn_gold
        end

        GamePrint("You were granted " .. tostring(extra_gold) .. " gold for this round. (Rounds: " .. tostring(rounds) .. ")")

        if(not data.client.player_loaded_from_data)then
            player.GiveGold(extra_gold)
        end

        -- if we are the owner of the lobby
        if(steamutils.IsOwner(lobby))then
            -- get the gold count from the lobby
            local gold = tonumber(steam.matchmaking.getLobbyData(lobby, "total_gold")) or 0
            -- add the new gold
            gold = gold + extra_gold
            -- set the new gold count
            steam.matchmaking.setLobbyData(lobby, "total_gold", tostring(gold))
        end

        -- increment holy mountain count
        
        ArenaGameplay.AddRound()
       

        -- give starting gear if first entry
        if(first_entry)then
            player.GiveStartingGear()
            if(((rounds - 1) > 0))then
                player.GiveMaxHealth(0.4 * (rounds - 1))
            end
        end

        message_handler.send.Unready(lobby, true)

        -- load map
        BiomeMapLoad_KeepPlayer( "mods/evaisa.arena/files/scripts/world/map_lobby.lua", "mods/evaisa.arena/files/biome/holymountain_scenes.xml" )

        -- show message
        if(show_message)then
            GamePrintImportant("You have entered the holy mountain", "Prepare to enter the arena.")
        end

        
        -- clean other player's data again because it might have failed for some cursed reason
        ArenaGameplay.CleanMembers(lobby, data)

        -- set ready counter
        ArenaGameplay.ReadyCounter(lobby, data)

        -- print member data
        --print(json.stringify(data))
    end,
    LoadArena = function(lobby, data, show_message)
        show_message = show_message or false

        playermenu:Close()

        -- manage flags
        GameRemoveFlagRun("ready_check")
        GameRemoveFlagRun("first_death")
        GameRemoveFlagRun("in_hm")

        data.state = "arena"
        data.preparing = true
        data.players_loaded = false
        data.deaths = 0
        data.lobby_loaded = false
        data.client.player_loaded_from_data = false

        message_handler.send.SendPerks(lobby)

        ArenaGameplay.PreventFiring()

        -- load map
        local arena = arena_list[data.random.range(1, #arena_list)]
        BiomeMapLoad_KeepPlayer( arena.biome_map, arena.pixel_scenes )

        player.Lock()

        -- move player to correct position
        data.spawn_point = arena.spawn_points[data.random.range(1, #arena.spawn_points)]

        ArenaGameplay.LoadClientPlayers(lobby, data)

        GamePrint("Loading arena")
    end,
    ReadyCheck = function(lobby, data)
        return ArenaGameplay.ReadyAmount(data, lobby) >= ArenaGameplay.TotalPlayers(lobby)
    end,
    CleanMembers = function(lobby, data)
        local members = steamutils.getLobbyMembers(lobby)
        
        for _, member in pairs(members)do
            if(member.id ~= steam.user.getSteamID() and data.players[tostring(member.id)] ~= nil)then
                data.players[tostring(member.id)]:Clean(lobby)
            end
        end
    end,
    UpdateTweens = function(lobby, data)
        local members = steamutils.getLobbyMembers(lobby)
    
        local validMembers = {}
    
        for _, member in pairs(members)do
            local memberid = tostring(member.id)
            
            validMembers[memberid] = true
        end
    
        -- iterate active tweens backwards and update
        for i = #data.tweens, 1, -1 do
            local tween = data.tweens[i]
            if(tween)then
                if(validMembers[tween.id] == nil)then
                    table.remove(data.tweens, i)
                else
                    if(tween:update())then
                        table.remove(data.tweens, i)
                    end
                end
            end
        end
    end,
    LobbyUpdate = function(lobby, data)
        -- update ready counter
        if(data.ready_counter ~= nil)then
            if(not IsPaused())then
                data.ready_counter:appy_offset(9, 28)
            else
                data.ready_counter:appy_offset(9, 9)
            end


            data.ready_counter:update()
        end

        if(steamutils.IsOwner(lobby))then
            -- check if all players are ready
            if(ArenaGameplay.ReadyCheck(lobby, data))then
                ArenaGameplay.LoadArena(lobby, data, true)
                message_handler.send.EnterArena(lobby)
            end
        end

        if(GameHasFlagRun("player_ready"))then
            GameRemoveFlagRun("player_ready")
            GamePrint("You are ready")
            message_handler.send.Ready(lobby)
            data.client.ready = true
        end

        if(GameHasFlagRun("player_unready"))then
            GameRemoveFlagRun("player_unready")
            GamePrint("You are no longer ready")
            message_handler.send.Unready(lobby)
            data.client.ready = false
        end

        if(GameGetFrameNum() % 5 == 0)then
            message_handler.send.UpdateHp(lobby)
            message_handler.send.SendPerks(lobby)
        end
    end,
    UpdateHealthbars = function(data)
        for k, v in pairs(data.players)do
            if(v.hp_bar)then
                if(v.entity ~= nil and EntityGetIsAlive(v.entity))then
                    local x, y = EntityGetTransform(v.entity)
                    y = y + 10
                    v.hp_bar:update(x, y)
                end
            end
        end
    end,
    CheckAllPlayersLoaded = function(lobby, data)
        local ready = not data.preparing
        for k, v in pairs(data.players)do
            if not v.loaded then
                ready = false
                break
            end
        end
        return ready
    end,
    FightCountdown = function(lobby, data)
        player.Unlock()
        data.countdown = countdown.create({
            "mods/evaisa.arena/files/sprites/ui/countdown/ready.png",
            "mods/evaisa.arena/files/sprites/ui/countdown/3.png",
            "mods/evaisa.arena/files/sprites/ui/countdown/2.png",
            "mods/evaisa.arena/files/sprites/ui/countdown/1.png",
            "mods/evaisa.arena/files/sprites/ui/countdown/fight.png",
        }, 60, function()

            message_handler.send.Unlock(lobby)
            player.Immortal(false)
            ArenaGameplay.AllowFiring()
            data.countdown = nil
        end)
    end,
    SpawnClientPlayer = function(lobby, user, data)
        local client = EntityLoad("mods/evaisa.arena/files/entities/client.xml", -1000, -1000)
        EntitySetName(client, tostring(user))
        local usernameSprite = EntityGetFirstComponentIncludingDisabled(client, "SpriteComponent", "username")
        local name = steam.friends.getFriendPersonaName(user)
        ComponentSetValue2(usernameSprite, "text", name)
        ComponentSetValue2(usernameSprite, "offset_x", string.len(name) * (1.8))
        data.players[tostring(user)].entity = client
        data.players[tostring(user)].alive = true

        print("Spawned client player for " .. name)

        if(data.players[tostring(user)].perks)then
            for k, v in ipairs(data.players[tostring(user)].perks)do
                local perk = v.id
                local count = v.count
                local run_on_clients = v.run_on_clients
                
                if(run_on_clients)then
                    for i = 1, count do
                        entity.GivePerk(client, perk, i)
                    end
                end
            end
        end
    end,
    CheckPlayer = function(lobby, user, data)
        if(not data.players[tostring(user)].entity and data.players[tostring(user)].alive)then
            --ArenaGameplay.SpawnClientPlayer(lobby, user, data)
            return false
        end
        return true
    end,
    LoadClientPlayers = function(lobby, data)
        local members = steamutils.getLobbyMembers(lobby)
        
        for _, member in pairs(members)do
            if(member.id ~= steam.user.getSteamID() and data.players[tostring(member.id)].entity)then
                data.players[tostring(member.id)]:Clean(lobby)
            end

            --[[if(member.id ~= steam.user.getSteamID())then
                print(json.stringify(data.players[tostring(member.id)]))
            end]]

            if(member.id ~= steam.user.getSteamID() and data.players[tostring(member.id)].entity == nil)then
                --GamePrint("Loading player " .. tostring(member.id))
                ArenaGameplay.SpawnClientPlayer(lobby, member.id, data)
            end
        end
    end,
    ClosestPlayer = function(x, y)
        closest = EntityGetClosestWithTag(x, y, "client")
        if(closest ~= nil)then
            return EntityGetName(closest)
        end

        return nil
    end,
    ArenaUpdate = function(lobby, data)
        if(data.preparing)then
            local spawn_points = EntityGetWithTag("spawn_point") or {}
            if(spawn_points ~= nil and #spawn_points > 0)then
                local spawn_point = spawn_points[Random(1, #spawn_points)]
                local x, y = EntityGetTransform(spawn_point)

                data.preparing = false
                player.Move(x, y)

                GamePrint("Spawned!!")
                
                if(not steamutils.IsOwner(lobby))then
                    message_handler.send.Loaded(lobby)
                end

                message_handler.send.Health(lobby)
            else
                player.Move(data.spawn_point.x, data.spawn_point.y)
            end
        end
        local player_entities = {}
        for k, v in pairs(data.players)do
            if(v.entity ~= nil and EntityGetIsAlive(v.entity))then
                table.insert(player_entities, v.entity)
            end
        end
        if(not IsPaused())then
            game_funcs.RenderOffScreenMarkers(player_entities)
            game_funcs.RenderAboveHeadMarkers(player_entities, 0, 27)
            ArenaGameplay.UpdateHealthbars(data)
        end
        if(steamutils.IsOwner(lobby))then
            if(not data.players_loaded and ArenaGameplay.CheckAllPlayersLoaded(lobby, data))then
                data.players_loaded = true
                print("All players loaded")
                message_handler.send.StartCountdown(lobby)
                ArenaGameplay.FightCountdown(lobby, data)
            end
        end
        if(data.countdown ~= nil)then
            data.countdown:update()
        end
        if(GameGetFrameNum() % 2 == 0)then
            message_handler.send.CharacterUpdate(lobby)
        end
        if(GameGetFrameNum() % 60 == 0)then
            steamutils.sendData({type = "handshake"}, steamutils.messageTypes.OtherPlayers, lobby)
            ArenaGameplay.DamageZoneCheck(0, 0, 600, 800)
        end
        if(GameHasFlagRun("took_damage"))then
            GameRemoveFlagRun("took_damage")
            message_handler.send.Health(lobby)
        end
        if(data.players_loaded)then
            message_handler.send.WandUpdate(lobby, data)
            message_handler.send.SwitchItem(lobby, data)
            --message_handler.send.Kick(lobby, data)
            message_handler.send.AnimationUpdate(lobby, data)
            --message_handler.send.AimUpdate(lobby)
            message_handler.send.SyncControls(lobby, data)
        end
    end,
    ValidatePlayers = function(lobby, data)
        for k, v in pairs(data.players)do
            local playerid = ArenaGameplay.FindUser(lobby, k)

            if(playerid == nil)then
                print("Player " .. k .. " is not in the lobby anymore")
                v:Clean(lobby)
                data.players[k] = nil
            end
        end
    end,
    Update = function(lobby, data)
        for k, v in pairs(data.players)do
            if(v.entity ~= nil and EntityGetIsAlive(v.entity))then
                local controls = EntityGetFirstComponentIncludingDisabled(v.entity, "ControlsComponent")
                if(controls)then
 
                    ComponentSetValue2(controls, "mButtonDownKick", false)
                    ComponentSetValue2(controls, "mButtonDownFire", false)
                    ComponentSetValue2(controls, "mButtonDownFire2", false)
                    ComponentSetValue2(controls, "mButtonDownLeftClick", false)
                    ComponentSetValue2(controls, "mButtonDownRightClick", false)

                end
            end
        end


        if((not GameHasFlagRun("player_unloaded")) and player.Get() and (GameGetFrameNum() % 30 == 0))then
            data.client.serialized_player = player.Serialize()
           -- steam.matchmaking.setLobbyMemberData(lobby, "player_data", data.client.serialized_player)
            steamutils.SetLocalLobbyData(lobby, "player_data",  player.Serialize(true))
           -- print("Saving player data")
        end

        if(data.state == "lobby")then
            ArenaGameplay.LobbyUpdate(lobby, data)
        elseif(data.state == "arena")then
            ArenaGameplay.ArenaUpdate(lobby, data)
            ArenaGameplay.KillCheck(lobby, data)
        end
        if(GameHasFlagRun("no_shooting"))then
            ArenaGameplay.CancelFire(lobby, data)
        end
        ArenaGameplay.UpdateTweens(lobby, data)
        if(GameGetFrameNum() % 60 == 0)then
            ArenaGameplay.ValidatePlayers(lobby, data)
        end
    end,
    OnProjectileFired = function(lobby, data, shooter_id, projectile_id, rng, position_x, position_y, target_x, target_y, send_message)
        if(data.state == "arena")then
            local playerEntity = player.Get()
            if(playerEntity ~= nil)then
                if(playerEntity == shooter_id)then
                    local projectileComponent = EntityGetFirstComponentIncludingDisabled(projectile_id, "ProjectileComponent")

                    local who_shot = ComponentGetValue2(projectileComponent, "mWhoShot")
                    local entity_that_shot  = ComponentGetValue2(projectileComponent, "mEntityThatShot")
        
                    if(entity_that_shot == 0)then
                        --math.randomseed( tonumber(tostring(steam.user.getSteamID())) + ((os.time() + GameGetFrameNum()) / 2))
                        local rand = data.random.range(0, 100000)
                        local rng = math.floor(rand)
                        --GamePrint("Setting RNG: "..tostring(rng))
                        np.SetProjectileSpreadRNG(rng)

                        data.client.projectile_seeds[projectile_id] = rng
                        --GamePrint("generated_rng: "..tostring(rng))

  
                        message_handler.send.WandFired(lobby, rng)
             
                    else
                        if(data.client.projectile_seeds[entity_that_shot])then
                            local new_seed = data.client.projectile_seeds[entity_that_shot] + 10
                            np.SetProjectileSpreadRNG(new_seed)
                            data.client.projectile_seeds[entity_that_shot] = data.client.projectile_seeds[entity_that_shot] + 1
                            data.client.projectile_seeds[projectile_id] = new_seed
                        end
                    end
                    return
                end
            end

            if(EntityGetName(shooter_id) ~= nil and tonumber(EntityGetName(shooter_id)))then
                if(data.players[EntityGetName(shooter_id)] and data.players[EntityGetName(shooter_id)].next_rng)then
                    --GamePrint("Setting RNG: "..tostring(arenaPlayerData[EntityGetName(shooter_id)].next_rng))
                    local projectileComponent = EntityGetFirstComponentIncludingDisabled(projectile_id, "ProjectileComponent")

                    local who_shot = ComponentGetValue2(projectileComponent, "mWhoShot")
                    local entity_that_shot  = ComponentGetValue2(projectileComponent, "mEntityThatShot")
                    if(entity_that_shot == 0)then
                        np.SetProjectileSpreadRNG(data.players[EntityGetName(shooter_id)].next_rng)
                        data.client.projectile_seeds[projectile_id] = data.players[EntityGetName(shooter_id)].next_rng
                    else
                        if(data.client.projectile_seeds[entity_that_shot])then
                            local new_seed = data.client.projectile_seeds[entity_that_shot] + 10
                            np.SetProjectileSpreadRNG(new_seed)
                            data.client.projectile_seeds[entity_that_shot] = data.client.projectile_seeds[entity_that_shot] + 1
                        end
                    end
                end
                return
            end
        end
    end,
    OnProjectileFiredPost = function(lobby, data, shooter_id, projectile_id, rng, position_x, position_y, target_x, target_y, send_message)
        local homingComponents = EntityGetComponentIncludingDisabled(projectile_id, "HomingComponent")

        local shooter_x, shooter_y = EntityGetTransform(shooter_id)

        if(homingComponents ~= nil)then
            for k, v in pairs(homingComponents)do
                local target_who_shot = ComponentGetValue2(v, "target_who_shot")
                if(target_who_shot == false)then
                    if(EntityHasTag(shooter_id, "client"))then
                        -- find closest player which isn't us
                        local closest_player = nil
                        local distance = 9999999
                        local clients = EntityGetWithTag("client")
                        -- add local player to list
                        if(player.Get())then
                            table.insert(clients, player.Get())
                        end

                        for k, v in pairs(clients)do
                            if(v ~= shooter_id)then
                                if(closest_player == nil)then
                                    closest_player = v
                                else
                                    local x, y = EntityGetTransform(v)
                                    local dist = math.abs(x - shooter_x) + math.abs(y - shooter_y)
                                    if(dist < distance)then
                                        distance = dist
                                        closest_player = v
                                    end
                                end
                            end
                        end

                        if(closest_player)then
                            ComponentSetValue2(v, "predefined_target", closest_player)
                            ComponentSetValue2(v, "target_tag", "mortal")
                        end
                    else
                        local closest_player = nil
                        local distance = 9999999
                        local clients = EntityGetWithTag("client")

                        for k, v in pairs(clients)do
                            if(v ~= shooter_id)then
                                if(closest_player == nil)then
                                    closest_player = v
                                else
                                    local x, y = EntityGetTransform(v)
                                    local dist = math.abs(x - shooter_x) + math.abs(y - shooter_y)
                                    if(dist < distance)then
                                        distance = dist
                                        closest_player = v
                                    end
                                end
                            end
                        end

                        if(closest_player)then
                            ComponentSetValue2(v, "predefined_target", closest_player)
                            ComponentSetValue2(v, "target_tag", "mortal")
                        end

                    end

                end
            end
        end
    end,
    LateUpdate = function(lobby, data)
        if(data.state == "arena")then
            ArenaGameplay.KillCheck(lobby, data)
        end
        local current_player = player.Get()

        if((not GameHasFlagRun("player_unloaded")) and current_player == nil)then
            ArenaGameplay.LoadPlayer(lobby, data)
        end

        if(data.current_player ~= current_player)then
            data.current_player = current_player
            if(current_player ~= nil)then
                np.RegisterPlayerEntityId(current_player)
            end
        end

        if(GameHasFlagRun("in_hm") and current_player)then
            player.Move(174, 133)
            GameRemoveFlagRun("in_hm")
        end

        if(GameGetFrameNum() % 5 == 0)then
            -- if we are host
            if(steamutils.IsOwner(lobby))then
                ArenaGameplay.SendGameData(lobby, data)
            end
        end

        for k, v in pairs(data.players)do
            if(v.entity ~= nil and EntityGetIsAlive(v.entity))then
                local controls = EntityGetFirstComponentIncludingDisabled(v.entity, "ControlsComponent")
                if(controls)then
                    if(ComponentGetValue2(controls, "mButtonDownKick") == false)then
                        data.players[k].controls.kick = false
                    end
                    -- mButtonDownFire
                    if(ComponentGetValue2(controls, "mButtonDownFire") == false)then
                        data.players[k].controls.fire = false
                    end
                    -- mButtonDownFire2
                    if(ComponentGetValue2(controls, "mButtonDownFire2") == false)then
                        data.players[k].controls.fire2 = false
                    end
                    -- mButtonDownLeft
                    if(ComponentGetValue2(controls, "mButtonDownLeftClick") == false)then
                        data.players[k].controls.leftClick = false
                    end
                    -- mButtonDownRight
                    if(ComponentGetValue2(controls, "mButtonDownRightClick") == false)then
                        data.players[k].controls.rightClick = false
                    end
                end
            end
        end
    end,
}

return ArenaGameplay