/*
    l4d_tnak_control_eq 必须是本库的
    创建bot从哈利的插件里copy
    copy 这个东西你知道的呀.
*/
#include <sourcemod>
#include <left4dhooks>
#include <colors>
#include <dhooks>
#undef REQUIRE_PLUGIN
#include <l4d_tank_control_eq>
#define REQUIRE_PLUGIN

#pragma semicolon 1
#pragma newdecls required

#define TEAM_SPECTATOR 1
#define TEAM_SURVIVOR 2
#define TEAM_INFECTED 3

ConVar g_cvSurvivorLimit;
ConVar g_cvInfectedLimit;
ConVar g_cvGameSurvivorLimit;
ConVar g_cvGameInfectedLimit;
ConVar g_cvPluginEnabled;
ConVar g_cvTankCount;
ConVar g_cvTankSpawnDelay;

float g_fInitialTankPos[3];
float g_fInitialTankAng[3];
int g_iSpawnedTankCount = 0;
bool g_bSecondTankSpawned = false;

Handle g_hSDK_NextBotCreatePlayerBot;
Handle g_hSDK_RespawnPlayer;

bool g_bIsSacrificeFinale;
bool g_bFinalLeaving;
int g_iSurvivorCount;

public Plugin myinfo = {
    name = "L4D2 Multiplayer Versus",
    author = "Hana",
    description = "支持Multiplayer的基础插件,包含多坦克机制",
    version = "1.8",
    url = "https://steamcommunity.com/profiles/76561197983870853/"
};

public void OnPluginStart()
{
    g_cvPluginEnabled = CreateConVar("l4d_superversus_enabled", "1", "启用插件 (1: 启用, 0: 禁用)", FCVAR_NOTIFY, true, 0.0, true, 1.0);

    g_cvSurvivorLimit = CreateConVar("l4d_survivor_limit", "4", "幸存者数量上限", FCVAR_NOTIFY, true, 1.0, true, 14.0);
    g_cvInfectedLimit = CreateConVar("l4d_infected_limit", "4", "感染者数量上限", FCVAR_NOTIFY, true, 1.0, true, 14.0);

    g_cvTankCount = CreateConVar("l4d_tank_count", "1", "每回合刷新的坦克数量", FCVAR_NOTIFY, true, 1.0, true, 5.0);
    g_cvTankSpawnDelay = CreateConVar("l4d_tank_spawn_delay", "3.5", "额外坦克刷新延迟(秒)", FCVAR_NOTIFY, true, 0.0, true, 30.0);
    
    g_cvGameSurvivorLimit = FindConVar("survivor_limit");
    g_cvGameInfectedLimit = FindConVar("z_max_player_zombies");

    SetConVarBounds(g_cvGameSurvivorLimit, ConVarBound_Upper, false);
    SetConVarBounds(g_cvGameInfectedLimit, ConVarBound_Upper, false);
    
    HookConVarChange(g_cvSurvivorLimit, OnLimitChange);
    HookConVarChange(g_cvInfectedLimit, OnLimitChange);
    
    RegConsoleCmd("sm_sur", Command_JoinSurvivor, "加入生还者");
    RegConsoleCmd("sm_inf", Command_JoinInfected, "加入感染者");
    
    GameData hGameData = LoadGameConfigFile("l4d2_MultiplayerVersus");
    if( hGameData == null ) SetFailState("Could not find gamedata file at addons/sourcemod/gamedata/l4d2_MultiplayerVersus.txt");

    StartPrepSDKCall(SDKCall_Player);
    if( PrepSDKCall_SetFromConf(hGameData, SDKConf_Signature, "CTerrorPlayer::RoundRespawn") == false )
        SetFailState("Failed to find signature: CTerrorPlayer::RoundRespawn");
    g_hSDK_RespawnPlayer = EndPrepSDKCall();
    if( g_hSDK_RespawnPlayer == null ) SetFailState("Failed to create SDKCall: CTerrorPlayer::RoundRespawn");

    StartPrepSDKCall(SDKCall_Static);
    Address addr = hGameData.GetAddress("NextBotCreatePlayerBot<SurvivorBot>");
    if( addr == Address_Null ) SetFailState("Failed to find signature: NextBotCreatePlayerBot<SurvivorBot>");
    int iOS = hGameData.GetOffset("OS");
    if( iOS == 1 )
    {
        Address offset = view_as<Address>(LoadFromAddress(addr + view_as<Address>(1), NumberType_Int32));
        addr += offset + view_as<Address>(5);
    }
    if( PrepSDKCall_SetAddress(addr) == false ) SetFailState("Failed to find signature: NextBotCreatePlayerBot<SurvivorBot>");
    PrepSDKCall_AddParameter(SDKType_String, SDKPass_Pointer);
    PrepSDKCall_SetReturnInfo(SDKType_CBasePlayer, SDKPass_Pointer);
    g_hSDK_NextBotCreatePlayerBot = EndPrepSDKCall();
    if( g_hSDK_NextBotCreatePlayerBot == null ) SetFailState("Failed to create SDKCall: NextBotCreatePlayerBot<SurvivorBot>");
    
    // Add rescue vehicle fix detour
    Handle hDetour = DHookCreateFromConf(hGameData, "CTerrorGameRules::CalculateSurvivalMultiplier");
    if(!hDetour)
        SetFailState("Failed to find 'CTerrorGameRules::CalculateSurvivalMultiplier' signature");
    
    if(!DHookEnableDetour(hDetour, true, CalculateSurvivalMultiplier_Post))
        SetFailState("Failed to detour 'CTerrorGameRules::CalculateSurvivalMultiplier'");

    delete hDetour;
    delete hGameData;

    // Add rescue vehicle events
    HookEvent("finale_vehicle_leaving", Event_FinaleVehicleLeaving, EventHookMode_Pre);
}

public void OnMapStart()
{
    if (!g_cvPluginEnabled.BoolValue)
        return;
    
    g_iSpawnedTankCount = 0;
    g_bSecondTankSpawned = false;
    CreateTimer(1.0, Timer_CreateSurvivorBots);
    g_bFinalLeaving = false;
    g_iSurvivorCount = 0;
    g_bIsSacrificeFinale = false;
}

/*--------------------- 牛魔bot生成相关的 ---------------------*/
public Action Timer_SetFinalLimit(Handle timer, any desiredLimit)
{
    SetConVarBounds(g_cvGameSurvivorLimit, ConVarBound_Upper, false);
    g_cvGameSurvivorLimit.IntValue = desiredLimit;
    return Plugin_Stop;
}

public void OnLimitChange(ConVar convar, const char[] oldValue, const char[] newValue)
{
    if (!g_cvPluginEnabled.BoolValue)
        return;
        
    if (convar == g_cvSurvivorLimit)
    {
        SetConVarBounds(g_cvGameSurvivorLimit, ConVarBound_Upper, false);
        g_cvGameSurvivorLimit.IntValue = g_cvSurvivorLimit.IntValue;
    }
    else if (convar == g_cvInfectedLimit)
    {
        SetConVarBounds(g_cvGameInfectedLimit, ConVarBound_Upper, false);
        g_cvGameInfectedLimit.IntValue = g_cvInfectedLimit.IntValue;
    }
}

public Action Timer_CreateSurvivorBots(Handle timer)
{
    int currentSurvivorCount = 0;
    for (int i = 1; i <= MaxClients; i++)
    {
        if (IsClientInGame(i) && GetClientTeam(i) == TEAM_SURVIVOR)
        {
            currentSurvivorCount++;
        }
    }
    
    int botsNeeded = g_cvSurvivorLimit.IntValue - currentSurvivorCount;
    for (int i = 0; i < botsNeeded; i++)
    {
        if (CreateSurvivorBot() == -1)
        {
            LogError("Failed to create survivor bot (%d/%d)", i + 1, botsNeeded);
            break;
        }
    }

    return Plugin_Stop;
}

/*--------------------- 玩家加入队伍 ---------------------*/
public Action Command_JoinSurvivor(int client, int args)
{
    if (!g_cvPluginEnabled.BoolValue)
        return Plugin_Continue;
        
    if (!client || !IsClientInGame(client))
        return Plugin_Handled;
        
    if (GetClientTeam(client) == TEAM_SURVIVOR)
    {
        CPrintToChat(client, "{blue}[{default}!{blue}] {default}你已经在生还者队伍中了!");
        return Plugin_Handled;
    }
    
    int targetBot = -1;
    for (int i = 1; i <= MaxClients; i++)
    {
        if (IsClientInGame(i) && IsFakeClient(i) && GetClientTeam(i) == TEAM_SURVIVOR && IsPlayerAlive(i))
        {
            targetBot = i;
            break;
        }
    }
    
    if (targetBot == -1)
    {
        CPrintToChat(client, "{blue}[{default}!{blue}] {default}生还者队伍已满!");
        return Plugin_Handled;
    }
    
    L4D_SetHumanSpec(targetBot, client);
    L4D_TakeOverBot(client);
    
    CPrintToChatAll("{blue}[{default}!{blue}] {olive}%N {default}加入了生还者队伍", client);
    return Plugin_Handled;
}

public Action Command_JoinInfected(int client, int args)
{
    if (!g_cvPluginEnabled.BoolValue)
        return Plugin_Continue;
        
    if (!client || !IsClientInGame(client))
        return Plugin_Handled;
        
    if (GetClientTeam(client) == TEAM_INFECTED)
    {
        CPrintToChat(client, "{blue}[{default}!{blue}] {default}你已经在感染者队伍中了!");
        return Plugin_Handled;
    }
    
    int currentInfected = 0;
    for (int i = 1; i <= MaxClients; i++)
    {
        if (IsClientInGame(i) && !IsFakeClient(i) && GetClientTeam(i) == TEAM_INFECTED)
            currentInfected++;
    }
    
    if (currentInfected >= g_cvInfectedLimit.IntValue)
    {
        CPrintToChat(client, "{blue}[{default}!{blue}] {default}感染者队伍已满!");
        return Plugin_Handled;
    }
    
    ChangeClientTeam(client, TEAM_INFECTED);
    CPrintToChatAll("{blue}[{default}!{blue}] {olive}%N {default}加入了感染者队伍", client);
    return Plugin_Handled;
}

/*--------------------- 小b坦克生成相关 ---------------------*/
public Action L4D_OnSpawnTank(const float vecPos[3], const float vecAng[3])
{
    if (g_bSecondTankSpawned && g_iSpawnedTankCount >= g_cvTankCount.IntValue)
    {
        g_iSpawnedTankCount = 0;
        g_bSecondTankSpawned = false;
    }
    
    if (g_iSpawnedTankCount == 0)
    {
        g_fInitialTankPos = vecPos;
        g_fInitialTankAng = vecAng;
    }
    
    g_iSpawnedTankCount++;
    
    if (g_iSpawnedTankCount > g_cvTankCount.IntValue)
    {
        return Plugin_Handled;
    }
    
    return Plugin_Continue;
}

public void L4D_OnSpawnTank_Post(int client, const float vecPos[3], const float vecAng[3])
{
    if (g_iSpawnedTankCount == 1 && g_cvTankCount.IntValue > 1)
    {
        CreateTimer(g_cvTankSpawnDelay.FloatValue, Timer_SpawnExtraTank);
    }
}

public Action Timer_SpawnExtraTank(Handle timer)
{
    char steamId[64];
    
    ArrayList tankQueue = GetTankQueue();
    bool foundPlayer = false;
    
    if (tankQueue != null && tankQueue.Length > 0)
    {
        tankQueue.GetString(0, steamId, sizeof(steamId));
        int client = GetClientBySteamId(steamId);
        
        if (client > 0)
        {
            foundPlayer = true;
            char name[MAX_NAME_LENGTH];
            GetClientName(client, name, sizeof(name));
            
            RemoveFromTankQueue(steamId);
            SetTank(steamId);
            
            DataPack dp = new DataPack();
            dp.WriteString(steamId);
            RequestFrame(Frame_SpawnTank, dp);
        }
    }
    delete tankQueue;
    
    if (!foundPlayer)
    {
        ArrayList nonTankPlayers = GetWhosNotHadTank();
        
        if (nonTankPlayers == null || nonTankPlayers.Length == 0)
        {
            char currentTankSteamId[64];
            int currentTank = GetTankSelection();
            
            if (currentTank > 0)
            {
                GetClientAuthId(currentTank, AuthId_Steam2, currentTankSteamId, sizeof(currentTankSteamId));
            }
            
            ClearWhosHadTank();
            
            delete nonTankPlayers;
            nonTankPlayers = new ArrayList(ByteCountToCells(64));
            
            for (int i = 1; i <= MaxClients; i++)
            {
                if (IsClientInGame(i) && !IsFakeClient(i) && GetClientTeam(i) == TEAM_INFECTED)
                {
                    char playerSteamId[64];
                    GetClientAuthId(i, AuthId_Steam2, playerSteamId, sizeof(playerSteamId));
                    
                    if (!StrEqual(playerSteamId, currentTankSteamId))
                    {
                        nonTankPlayers.PushString(playerSteamId);
                    }
                }
            }
        }
        
        if (nonTankPlayers.Length > 0)
        {
            int randomIndex = GetRandomInt(0, nonTankPlayers.Length - 1);
            nonTankPlayers.GetString(randomIndex, steamId, sizeof(steamId));
            
            int client = GetClientBySteamId(steamId);
            if (client > 0)
            {
                char name[MAX_NAME_LENGTH];
                GetClientName(client, name, sizeof(name));
                
                SetTank(steamId);
                DataPack dp = new DataPack();
                dp.WriteString(steamId);
                RequestFrame(Frame_SpawnTank, dp);
            }
        }
        else
        {
            PrintToAdmins("{blue}[{default}!{blue}] {default}错误：没有可分配坦克的玩家");
        }
        
        delete nonTankPlayers;
    }
    
    return Plugin_Stop;
}

public void L4D_OnTankControlTake(int client)
{
    if(client <= 0 || !IsClientInGame(client) || IsFakeClient(client))
        return;
        
    char steamId[64];
    if(!GetClientAuthId(client, AuthId_Steam2, steamId, sizeof(steamId)))
        return;
        
    SetTank(steamId);
    RemoveFromTankQueue(steamId);
    
    char name[MAX_NAME_LENGTH];
    GetClientName(client, name, sizeof(name));
}

public void Frame_SpawnTank(DataPack dp)
{
    dp.Reset();
    char steamId[64];
    dp.ReadString(steamId, sizeof(steamId));
    delete dp;
    
    int tank = L4D2_SpawnTank(g_fInitialTankPos, g_fInitialTankAng);
    if (tank > 0 && IsValidEntity(tank))
    {
        int client = GetClientBySteamId(steamId);
        if (client > 0)
        {
            L4D_TakeOverZombieBot(client, tank);
            g_bSecondTankSpawned = true;
            
            RemoveFromTankQueue(steamId);
            
            if (!HasPlayerHadTank(steamId))
            {
                AddTankToList(steamId);
            }
            
            char name[MAX_NAME_LENGTH];
            GetClientName(client, name, sizeof(name));
        }
    }
}

/*--------------------- 修牛魔 ---------------------*/

// 留着以后调试输出给管理员的调试信息
void PrintToAdmins(const char[] format, any ...)
{
    char buffer[254];
    VFormat(buffer, sizeof(buffer), format, 2);
    
    for (int i = 1; i <= MaxClients; i++)
    {
        if (IsClientInGame(i) && !IsFakeClient(i) && CheckCommandAccess(i, "sm_admin", ADMFLAG_GENERIC))
        {
            CPrintToChat(i, buffer);
        }
    }
}

int GetClientBySteamId(const char[] steamId)
{
    char clientSteamId[64];
    
    for (int i = 1; i <= MaxClients; i++)
    {
        if (IsClientInGame(i) && !IsFakeClient(i))
        {
            GetClientAuthId(i, AuthId_Steam2, clientSteamId, sizeof(clientSteamId));
            if (strcmp(steamId, clientSteamId) == 0)
            {
                return i;
            }
        }
    }
    
    return -1;
}

int CreateSurvivorBot()
{
    if (GetClientCount(false) >= MaxClients)
    {
        return -1;
    }

    int bot = SDKCall(g_hSDK_NextBotCreatePlayerBot, "I am Bot");
    if( bot > 0 && IsValidEntity(bot) )
    {
        ChangeClientTeam(bot, 2);
        
        if( !IsPlayerAlive(bot) )
        {
            SDKCall(g_hSDK_RespawnPlayer, bot);
        }
        return bot;
    }

    return -1;
}

bool HasPlayerHadTank(const char[] steamId)
{
    ArrayList hadTankList = GetWhosHadTank();
    bool hadTank = (hadTankList.FindString(steamId) != -1);
    delete hadTankList;
    return hadTank;
}

void AddTankToList(const char[] steamId)
{
    ArrayList hadTankList = GetWhosHadTank();
    if (hadTankList.FindString(steamId) == -1)
    {
        hadTankList.PushString(steamId);
    }
    delete hadTankList;
}

// 分数修复相关
public void OnEntityCreated(int entity, const char[] classname)
{
    if (strncmp(classname, "trigger_finale", 14) == 0)
    {
        RequestFrame(OnNextFrame_trigger_finale, EntIndexToEntRef(entity));
    }
}

void OnNextFrame_trigger_finale(int entityRef)
{
    int entity = EntRefToEntIndex(entityRef);
    if (entity == INVALID_ENT_REFERENCE)
        return;

    HookSingleEntityOutput(entity, "FinaleEscapeStarted", OnFinaleEscapeStarted);
}

void OnFinaleEscapeStarted(const char[] output, int caller, int activator, float delay)
{
    g_bIsSacrificeFinale = view_as<bool>(GetEntProp(caller, Prop_Data, "m_bIsSacrificeFinale"));
}

void Event_FinaleVehicleLeaving(Event event, const char[] name, bool dontBroadcast)
{
    g_bFinalLeaving = true;
    g_iSurvivorCount = 0;

    for(int i = 1; i <= MaxClients; i++)
    {
        if(!IsClientInGame(i) || GetClientTeam(i) != TEAM_SURVIVOR)
            continue;

        if(IsPlayerAlive(i))
        {
            if(IsPlayerIncapacitated(i) || IsPlayerHangingFromLedge(i))
            {
                if(L4D_HasPlayerControlledZombies()) 
                    ForcePlayerSuicide(i);
                continue;
            }
            g_iSurvivorCount++;

            if(!g_bIsSacrificeFinale) 
                SDKHook(i, SDKHook_OnTakeDamage, SurvivorOnTakeDamage);
        }
    }

    // Handle extra survivor positions
    int entity = FindEntityByClassname(MaxClients + 1, "info_survivor_position");
    if(IsValidEntity(entity))
    {
        float vOrigin[3];
        GetEntPropVector(entity, Prop_Send, "m_vecOrigin", vOrigin);

        int iSurvivor = 0;
        static const char sOrder[][] = {"1", "2", "3", "4"};
        for(int i = 1; i <= MaxClients; i++)
        {
            if(!IsClientInGame(i) || GetClientTeam(i) != TEAM_SURVIVOR)
                continue;
                
            if(++iSurvivor < 4)
                continue;
                
            entity = CreateEntityByName("info_survivor_position");
            if(entity > 2000) 
            {
                RemoveEntity(entity);
                break;
            }

            DispatchKeyValue(entity, "Order", sOrder[iSurvivor - RoundToFloor(iSurvivor / 4.0) * 4]);
            TeleportEntity(entity, vOrigin, NULL_VECTOR, NULL_VECTOR);
            DispatchSpawn(entity);
        }
    }
}

Action SurvivorOnTakeDamage(int victim, int &attacker, int &inflictor, float &damage, int &damagetype)
{
    if (!IsClientInGame(victim) || GetClientTeam(victim) != TEAM_SURVIVOR) 
        return Plugin_Continue;

    return Plugin_Handled;
}

MRESReturn CalculateSurvivalMultiplier_Post(Address pThis, Handle hParams)
{
    if(!g_bFinalLeaving) return MRES_Ignored;
    if(!L4D_HasPlayerControlledZombies()) return MRES_Ignored;

    int iTeamFliped = GameRules_GetProp("m_bAreTeamsFlipped");
    int iOrininalSurvivorCount = GameRules_GetProp("m_iVersusSurvivalMultiplier", 4, iTeamFliped);

    if(iOrininalSurvivorCount < g_iSurvivorCount)
    {
        GameRules_SetProp("m_iVersusSurvivalMultiplier", g_iSurvivorCount, 4, iTeamFliped, true);
    }

    return MRES_Ignored;
}

bool IsPlayerIncapacitated(int client)
{
    return view_as<bool>(GetEntProp(client, Prop_Send, "m_isIncapacitated", 1));
}

bool IsPlayerHangingFromLedge(int client)
{
    return view_as<bool>(GetEntProp(client, Prop_Send, "m_isHangingFromLedge") || GetEntProp(client, Prop_Send, "m_isFallingFromLedge"));
}