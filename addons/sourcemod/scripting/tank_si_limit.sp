#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>

public Plugin myinfo = 
{
    name = "TankSpawn SI Limit Manager",
    author = "HANA",
    description = "给克局设定其他特感数量",
    version = "1.1",
    url = "https://github.com/cH1yoi"
};

ConVar g_hHunterLimit;
ConVar g_hBoomerLimit;
ConVar g_hSmokerLimit;
ConVar g_hJockeyLimit;
ConVar g_hChargerLimit;

int g_iOriginalHunterLimit;
int g_iOriginalBoomerLimit;
int g_iOriginalSmokerLimit;
int g_iOriginalJockeyLimit;
int g_iOriginalChargerLimit;

ConVar g_hCustomHunterLimit;
ConVar g_hCustomBoomerLimit;
ConVar g_hCustomSmokerLimit;
ConVar g_hCustomJockeyLimit;
ConVar g_hCustomChargerLimit;
ConVar g_hEnablePlugin;

bool g_bTankIsAlive = false;
int g_iTankClient = 0;
bool g_bOriginalValuesStored = false;

public void OnPluginStart()
{
    g_hEnablePlugin = CreateConVar("tank_si_manager_enable", "1", "Enable/disable the Tank SI Limit Manager plugin", FCVAR_NOTIFY, true, 0.0, true, 1.0);

    g_hCustomHunterLimit = CreateConVar("tank_hunter_limit", "2", "Hunter limit when tank is active", FCVAR_NOTIFY, true, 0.0, true, 4.0);
    g_hCustomBoomerLimit = CreateConVar("tank_boomer_limit", "1", "Boomer limit when tank is active", FCVAR_NOTIFY, true, 0.0, true, 4.0);
    g_hCustomSmokerLimit = CreateConVar("tank_smoker_limit", "2", "Smoker limit when tank is active", FCVAR_NOTIFY, true, 0.0, true, 4.0);
    g_hCustomJockeyLimit = CreateConVar("tank_jockey_limit", "2", "Jockey limit when tank is active", FCVAR_NOTIFY, true, 0.0, true, 4.0);
    g_hCustomChargerLimit = CreateConVar("tank_charger_limit", "3", "Charger limit when tank is active", FCVAR_NOTIFY, true, 0.0, true, 4.0);
    
    g_hHunterLimit = FindConVar("z_versus_hunter_limit");
    g_hBoomerLimit = FindConVar("z_versus_boomer_limit");
    g_hSmokerLimit = FindConVar("z_versus_smoker_limit");
    g_hJockeyLimit = FindConVar("z_versus_jockey_limit");
    g_hChargerLimit = FindConVar("z_versus_charger_limit");
    
    CreateTimer(5.0, Timer_StoreOriginalValues);
    
    HookEvent("tank_spawn", Event_TankSpawn);
    HookEvent("player_death", Event_PlayerDeath);
    HookEvent("round_start", Event_RoundStart);
    HookEvent("round_end", Event_RoundEnd);
}

public Action Timer_StoreOriginalValues(Handle timer)
{
    StoreOriginalValues();
    return Plugin_Continue;
}

public void OnPluginEnd()
{
    if (g_bTankIsAlive)
    {
        RestoreOriginalLimits();
    }
}

public void OnMapStart()
{
    CreateTimer(3.0, Timer_OnMapStartDelay);
}

public Action Timer_OnMapStartDelay(Handle timer)
{
    g_bTankIsAlive = false;
    g_iTankClient = 0;
    
    StoreOriginalValues();
    return Plugin_Continue;
}

public void OnClientDisconnect_Post(int client)
{
    if (!g_bTankIsAlive || client != g_iTankClient) return;
    
    CreateTimer(0.5, Timer_CheckTank, client);
}

void StoreOriginalValues()
{
    if (g_bTankIsAlive) return;
    
    g_iOriginalHunterLimit = g_hHunterLimit.IntValue;
    g_iOriginalBoomerLimit = g_hBoomerLimit.IntValue;
    g_iOriginalSmokerLimit = g_hSmokerLimit.IntValue;
    g_iOriginalJockeyLimit = g_hJockeyLimit.IntValue;
    g_iOriginalChargerLimit = g_hChargerLimit.IntValue;
    
    g_bOriginalValuesStored = true;
}

void SetCustomLimits()
{
    if (!g_hEnablePlugin.BoolValue) 
    {
        return;
    }
    
    if (!g_bOriginalValuesStored)
    {
        StoreOriginalValues();
    }
    
    SetConVarInt(g_hHunterLimit, g_hCustomHunterLimit.IntValue);
    SetConVarInt(g_hBoomerLimit, g_hCustomBoomerLimit.IntValue);
    SetConVarInt(g_hSmokerLimit, g_hCustomSmokerLimit.IntValue);
    SetConVarInt(g_hJockeyLimit, g_hCustomJockeyLimit.IntValue);
    SetConVarInt(g_hChargerLimit, g_hCustomChargerLimit.IntValue);
}

void RestoreOriginalLimits()
{
    if (!g_bOriginalValuesStored)
    {
        return;
    }
    
    SetConVarInt(g_hHunterLimit, g_iOriginalHunterLimit);
    SetConVarInt(g_hBoomerLimit, g_iOriginalBoomerLimit);
    SetConVarInt(g_hSmokerLimit, g_iOriginalSmokerLimit);
    SetConVarInt(g_hJockeyLimit, g_iOriginalJockeyLimit);
    SetConVarInt(g_hChargerLimit, g_iOriginalChargerLimit);
}

public void Event_TankSpawn(Event event, const char[] name, bool dontBroadcast)
{
    int client = GetClientOfUserId(event.GetInt("userid"));
    g_iTankClient = client;
    
    if (g_bTankIsAlive) 
    {
        return;
    }
    
    g_bTankIsAlive = true;
    SetCustomLimits();
}

public void Event_PlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
    int client = GetClientOfUserId(event.GetInt("userid"));
    
    if (client > 0 && IsTank(client))
    {
        CreateTimer(0.5, Timer_CheckTank, client);
    }
}

public Action Timer_CheckTank(Handle timer, any oldTankClient)
{
    if (g_iTankClient != oldTankClient) 
    {
        return Plugin_Continue;
    }
    
    int tankClient = FindTankClient();
    if (tankClient && tankClient != oldTankClient)
    {
        g_iTankClient = tankClient;
        return Plugin_Continue;
    }
    
    g_bTankIsAlive = false;
    g_iTankClient = 0;
    RestoreOriginalLimits();
    
    return Plugin_Continue;
}

public void Event_RoundStart(Event event, const char[] name, bool dontBroadcast)
{
    g_bTankIsAlive = false;
    g_iTankClient = 0;
    
    CreateTimer(3.0, Timer_StoreOriginalValuesOnRoundStart);
}

public Action Timer_StoreOriginalValuesOnRoundStart(Handle timer)
{
    StoreOriginalValues();
    
    int tankClient = FindTankClient();
    if (tankClient)
    {
        g_bTankIsAlive = true;
        g_iTankClient = tankClient;
        SetCustomLimits();
    }
    
    return Plugin_Continue;
}

public void Event_RoundEnd(Event event, const char[] name, bool dontBroadcast)
{
    g_bTankIsAlive = false;
    g_iTankClient = 0;
    RestoreOriginalLimits();
}

bool IsTank(int client)
{
    if (client <= 0 || client > MaxClients || !IsClientInGame(client))
        return false;
    
    return GetClientTeam(client) == 3 && GetEntProp(client, Prop_Send, "m_zombieClass") == 8;
}

int FindTankClient()
{
    for (int i = 1; i <= MaxClients; i++)
    {
        if (IsClientInGame(i) && IsPlayerAlive(i) && IsTank(i))
        {
            return i;
        }
    }
    return 0;
}