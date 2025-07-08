#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <colors>
#define L4D2UTIL_STOCKS_ONLY
#include <l4d2util>


#define MAX_PINNED_DISPLAY 12
#define TANK_CHECK_INTERVAL 0.3
#define PINNED_ANNOUNCE_COOLDOWN 0.2
#define PINNED_CHECK_INTERVAL 0.2
#define PINNED_CHECK_THRESHOLD 0.1

enum struct InfectedState {
    int victimCount;
    bool victims[MAXPLAYERS+1];
    bool isActive;
    Handle timer;
}

InfectedState g_Charger[MAXPLAYERS+1];
InfectedState g_Boomer[MAXPLAYERS+1];
InfectedState g_Tank[MAXPLAYERS+1];

bool g_bIsCarryingSurvivor[MAXPLAYERS+1];
static int g_iPlayerLastHealth[MAXPLAYERS+1];

static float g_fLastPinnedAnnounce;
static float g_fLastPinnedCheck;
static int g_iMaxPinnedCount;

Handle g_hPinnedCheckTimer = null;
bool g_bIsCheckingPinned = false;

public Plugin myinfo = 
{
    name = "L4D2 Special Infected Highlights",
    author = "Hana",
    description = "Announce special infected highlights",
    version = "2.3",
    url = "https://steamcommunity.com/profiles/76561197983870853/"
};

public void OnPluginStart()
{
    HookEvent("round_start", Event_RoundStart);
    HookEvent("player_spawn", Event_PlayerSpawn);
    HookEvent("player_death", Event_PlayerDeath);
    HookEvent("player_hurt", Event_PlayerHurt);
    
    HookEvent("charger_charge_start", Event_ChargeStart);
    HookEvent("charger_impact", Event_ChargerImpact);
    HookEvent("charger_carry_start", Event_ChargeCarryStart);
    HookEvent("charger_carry_end", Event_ChargeCarryEnd);
    
    HookEvent("player_now_it", Event_BoomerVomit);
    
    HookEvent("tongue_grab", Event_SpecialInfectedGrab);
    HookEvent("choke_start", Event_SpecialInfectedGrab);
    HookEvent("lunge_pounce", Event_SpecialInfectedGrab);
    HookEvent("jockey_ride", Event_SpecialInfectedGrab);
    HookEvent("charger_carry_start", Event_ChargerGrab);
    HookEvent("charger_pummel_start", Event_ChargerGrab);
    HookEvent("player_incapacitated", Event_PlayerIncapacitated);
    
    HookEvent("tongue_release", Event_PinnedEnd);
    HookEvent("pounce_end", Event_PinnedEnd);
    HookEvent("jockey_ride_end", Event_PinnedEnd);
    HookEvent("charger_carry_end", Event_PinnedEnd);
    HookEvent("charger_pummel_end", Event_PinnedEnd);
    
    InitializeVariables();
}

public void OnMapStart()
{
    ResetAllClients();
    ResetPinnedCheckTimer();
}

public void OnClientPutInServer(int client)
{
    SDKHook(client, SDKHook_OnTakeDamage, OnTakeDamage);
}

public void OnClientDisconnect(int client)
{
    SDKUnhook(client, SDKHook_OnTakeDamage, OnTakeDamage);
}

Action OnTakeDamage(int victim, int &attacker, int &inflictor, float &damage, int &damagetype)
{
    if (!IsValidEntity(victim) || !IsValidEntity(attacker)) return Plugin_Continue;
    if (!attacker || attacker > MaxClients) return Plugin_Continue;
    if (!IsSurvivor(victim) || !IsTank(attacker)) return Plugin_Continue;
    
    int playerHealth = GetSurvivorPermanentHealth(victim) + GetSurvivorTemporaryHealth(victim);
    
    if (RoundToFloor(damage) >= playerHealth)
    {
        g_iPlayerLastHealth[victim] = playerHealth;
        
        char classname[64];
        GetEdictClassname(inflictor, classname, sizeof(classname));
        
        if (StrEqual(classname, "weapon_tank_claw") && !g_Tank[attacker].victims[victim])
        {
            if (!IsIncapacitated(victim))
            {
                ProcessTankPunch(attacker, victim);
            }
        }
    }
    
    return Plugin_Continue;
}

void Event_RoundStart(Event event, const char[] name, bool dontBroadcast)
{
    ResetAllClients();
    InitializeVariables();
}

void Event_PlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
    int client = GetClientOfUserId(event.GetInt("userid"));
    if (client > 0)
    {
        ResetClientStats(client);
    }
}

void Event_PlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
    int client = GetClientOfUserId(event.GetInt("userid"));
    if (client > 0)
    {
        ResetClientStats(client);
    }
}

void Event_PlayerHurt(Event event, const char[] name, bool dontBroadcast)
{
    int victim = GetClientOfUserId(event.GetInt("userid"));
    int attacker = GetClientOfUserId(event.GetInt("attacker"));
    char weapon[64];
    event.GetString("weapon", weapon, sizeof(weapon));
    
    if (!attacker || !victim || !IsClientInGame(attacker) || !IsClientInGame(victim))
        return;
    
    if (IsTank(attacker) && IsSurvivor(victim))
    {
        if (strcmp(weapon, "tank_rock") == 0)
        {
            if (!IsIncapacitated(victim))
            {
                CPrintToChatAll("{olive}%N{default}({red}Tank{default}) {red}投掷石头命中 {olive}%N", attacker, victim);
            }
            return;
        }
        
        if (strcmp(weapon, "tank_claw") == 0)
        {
            if (!g_Tank[attacker].isActive)
            {
                InitializeTankState(attacker);
            }
            
            if (!IsIncapacitated(victim) && !g_Tank[attacker].victims[victim])
            {
                ProcessTankPunch(attacker, victim);
            }
        }
    }
}

void Event_ChargeStart(Event event, const char[] name, bool dontBroadcast)
{
    int client = GetClientOfUserId(event.GetInt("userid"));
    
    if (!IsCharger(client))
        return;
        
    ResetClientStats(client);
    g_Charger[client].isActive = true;
}

void Event_ChargerImpact(Event event, const char[] name, bool dontBroadcast)
{
    int client = GetClientOfUserId(event.GetInt("userid"));
    int victim = GetClientOfUserId(event.GetInt("victim"));
    
    if (!IsCharger(client) || !IsSurvivor(victim) || !IsPlayerAlive(victim))
        return;
        
    if (g_Charger[client].isActive && !g_Charger[client].victims[victim])
    {
        g_Charger[client].victims[victim] = true;
        g_Charger[client].victimCount++;
        
        int totalVictims = g_bIsCarryingSurvivor[client] ? g_Charger[client].victimCount + 1 : g_Charger[client].victimCount;
        
        if (totalVictims >= 2)
        {
            ShowMessage(client, totalVictims, "Charger", "一撞");
        }
    }
}

void Event_ChargeCarryStart(Event event, const char[] name, bool dontBroadcast)
{
    int client = GetClientOfUserId(event.GetInt("userid"));
    int victim = GetClientOfUserId(event.GetInt("victim"));
    
    if (!IsCharger(client) || !IsSurvivor(victim) || !IsPlayerAlive(victim))
        return;
        
    g_bIsCarryingSurvivor[client] = true;
}

void Event_ChargeCarryEnd(Event event, const char[] name, bool dontBroadcast)
{
    int client = GetClientOfUserId(event.GetInt("userid"));
    if (IsCharger(client))
    {
        g_bIsCarryingSurvivor[client] = false;
        g_Charger[client].isActive = false;
    }
}

void Event_BoomerVomit(Event event, const char[] name, bool dontBroadcast)
{
    int attacker = GetClientOfUserId(event.GetInt("attacker"));
    int victim = GetClientOfUserId(event.GetInt("userid"));
    
    if (!IsBoomer(attacker) || !IsSurvivor(victim))
        return;
        
    if (!g_Boomer[attacker].victims[victim])
    {
        g_Boomer[attacker].victims[victim] = true;
        g_Boomer[attacker].victimCount++;
        
        if (g_Boomer[attacker].victimCount >= 2)
        {
            ShowMessage(attacker, g_Boomer[attacker].victimCount, "Boomer", "一喷");
        }
    }
}

void Event_SpecialInfectedGrab(Event event, const char[] name, bool dontBroadcast)
{
    RequestPinnedCheck();
}

void Event_ChargerGrab(Event event, const char[] name, bool dontBroadcast)
{
    RequestPinnedCheck();
}

void Event_PinnedEnd(Event event, const char[] name, bool dontBroadcast)
{
    RequestPinnedCheck();
}

void Event_PlayerIncapacitated(Event event, const char[] name, bool dontBroadcast)
{
    int victim = GetClientOfUserId(event.GetInt("userid"));
    int attacker = GetClientOfUserId(event.GetInt("attacker"));
    char weapon[64];
    event.GetString("weapon", weapon, sizeof(weapon));
    
    if (!attacker || !IsClientInGame(attacker))
        return;
        
    if (!IsTank(attacker) || !IsSurvivor(victim))
        return;
        
    if (strcmp(weapon, "prop_physics") == 0)
    {
        CPrintToChatAll("{olive}%N{default}({red}Tank{default}) {red}打铁命中 {olive}%N", attacker, victim);
        return;
    }
    
    if (strcmp(weapon, "tank_claw") == 0)
    {
        if (!g_Tank[attacker].isActive)
        {
            InitializeTankState(attacker);
        }
        
        if (!g_Tank[attacker].victims[victim])
        {
            ProcessTankPunch(attacker, victim);
        }
    }
    else if (strcmp(weapon, "tank_rock") == 0)
    {
        CPrintToChatAll("{olive}%N{default}({red}Tank{default}) {red}投掷石头命中 {olive}%N", attacker, victim);
    }
}

public Action Timer_CheckTankMultiPunch(Handle timer, any attacker)
{
    if (!IsTank(attacker) || !IsPlayerAlive(attacker))
    {
        g_Tank[attacker].timer = null;
        return Plugin_Stop;
    }
    
    if (g_Tank[attacker].victimCount >= 2)
    {
        ShowMessage(attacker, g_Tank[attacker].victimCount, "Tank", "一拍");
    }
    
    ResetTankState(attacker);
    return Plugin_Stop;
}

public Action Timer_CheckPinned(Handle timer)
{
    CheckPinnedCount();
    return Plugin_Stop;
}

public Action Timer_DelayedPinnedCheck(Handle timer)
{
    g_hPinnedCheckTimer = null;
    g_bIsCheckingPinned = false;
    
    CheckPinnedCount();
    return Plugin_Stop;
}

void InitializeVariables()
{
    g_fLastPinnedAnnounce = 0.0;
    g_fLastPinnedCheck = 0.0;
    g_iMaxPinnedCount = 0;
}

void ResetAllClients()
{
    for (int i = 1; i <= MaxClients; i++)
    {
        if (g_Charger[i].timer != null)
        {
            KillTimer(g_Charger[i].timer);
            g_Charger[i].timer = null;
        }
        ResetClientStats(i);
    }
}

void ResetPinnedCheckTimer()
{
    if (g_hPinnedCheckTimer != null)
    {
        KillTimer(g_hPinnedCheckTimer);
        g_hPinnedCheckTimer = null;
    }
    g_bIsCheckingPinned = false;
}

void ResetClientStats(int client)
{
    g_Charger[client].victimCount = 0;
    g_Boomer[client].victimCount = 0;
    g_Tank[client].victimCount = 0;
    
    g_bIsCarryingSurvivor[client] = false;
    g_Charger[client].isActive = false;
    g_Boomer[client].isActive = false;
    g_Tank[client].isActive = false;
    
    for (int i = 1; i <= MaxClients; i++)
    {
        g_Charger[client].victims[i] = false;
        g_Boomer[client].victims[i] = false;
        g_Tank[client].victims[i] = false;
    }
    
    if (g_Tank[client].timer != null)
    {
        KillTimer(g_Tank[client].timer);
        g_Tank[client].timer = null;
    }
    
    g_iPlayerLastHealth[client] = 0;
}

void InitializeTankState(int attacker)
{
    g_Tank[attacker].isActive = true;
    g_Tank[attacker].victimCount = 0;
    for (int i = 1; i <= MaxClients; i++)
    {
        g_Tank[attacker].victims[i] = false;
    }
}

void ResetTankState(int attacker)
{
    g_Tank[attacker].victimCount = 0;
    g_Tank[attacker].isActive = false;
    for (int i = 1; i <= MaxClients; i++)
    {
        g_Tank[attacker].victims[i] = false;
    }
    g_Tank[attacker].timer = null;
}

void ProcessTankPunch(int attacker, int victim)
{
    g_Tank[attacker].victims[victim] = true;
    g_Tank[attacker].victimCount++;
    
    if (g_Tank[attacker].timer != null)
    {
        KillTimer(g_Tank[attacker].timer);
    }
    g_Tank[attacker].timer = CreateTimer(TANK_CHECK_INTERVAL, Timer_CheckTankMultiPunch, attacker);
}

void ShowMessage(int attacker, int victims, const char[] type, const char[] action)
{
    if (victims < 2 || victims > MAX_PINNED_DISPLAY)
        return;
        
    char stars[32];
    stars[0] = '\0';
    
    for (int i = 0; i < victims; i++)
    {
        StrCat(stars, sizeof(stars), "★");
    }
    
    if (IsFakeClient(attacker))
    {
        CPrintToChatAll("{red}%s {olive}AI{default}({red}%s{default}) {red}%s {olive}%d", 
            stars, type, action, victims);
    }
    else
    {
        CPrintToChatAll("{red}%s {olive}%N{default}({red}%s{default}) {red}%s {olive}%d", 
            stars, attacker, type, action, victims);
    }
}

void CheckPinnedCount()
{
    int pinned_count = 0;
    int alive_count = 0;
    
    for (int i = 1; i <= MaxClients; i++)
    {
        if (!IsClientInGame(i) || GetClientTeam(i) != 2)
            continue;
            
        if (IsPlayerAlive(i))
        {
            alive_count++;
            
            if (GetEntPropEnt(i, Prop_Send, "m_tongueOwner") > 0 ||
                GetEntPropEnt(i, Prop_Send, "m_pounceAttacker") > 0 ||
                GetEntPropEnt(i, Prop_Send, "m_carryAttacker") > 0 ||
                GetEntPropEnt(i, Prop_Send, "m_pummelAttacker") > 0 ||
                GetEntPropEnt(i, Prop_Send, "m_jockeyAttacker") > 0)
            {
                pinned_count++;
            }
        }
    }

    if (pinned_count < 2)
    {
        g_iMaxPinnedCount = 0;
        g_bIsCheckingPinned = false;
        if (g_hPinnedCheckTimer != null)
        {
            KillTimer(g_hPinnedCheckTimer);
            g_hPinnedCheckTimer = null;
        }
        return;
    }

    if (pinned_count > g_iMaxPinnedCount)
    {
        float currentTime = GetGameTime();
        if (currentTime - g_fLastPinnedAnnounce >= PINNED_ANNOUNCE_COOLDOWN)
        {
            g_iMaxPinnedCount = pinned_count;
            
            char stars[32];
            stars[0] = '\0';
            
            for (int i = 0; i < pinned_count; i++)
            {
                StrCat(stars, sizeof(stars), "★");
            }
            
            CPrintToChatAll("{red}%s {red}特感阵营达成 {olive}%d {red}控", stars, pinned_count);
            g_fLastPinnedAnnounce = currentTime;
        }
    }

    if (pinned_count == alive_count && alive_count > 0)
    {
        g_bIsCheckingPinned = false;
        if (g_hPinnedCheckTimer != null)
        {
            KillTimer(g_hPinnedCheckTimer);
            g_hPinnedCheckTimer = null;
        }
    }
}

void RequestPinnedCheck()
{
    float currentTime = GetGameTime();
    if (currentTime - g_fLastPinnedCheck < PINNED_CHECK_THRESHOLD)
        return;
    
    g_fLastPinnedCheck = currentTime;
    
    if (g_bIsCheckingPinned)
        return;
        
    g_bIsCheckingPinned = true;
    if (g_hPinnedCheckTimer != null)
    {
        KillTimer(g_hPinnedCheckTimer);
        g_hPinnedCheckTimer = null; 
    }
    
    g_hPinnedCheckTimer = CreateTimer(PINNED_CHECK_INTERVAL, Timer_DelayedPinnedCheck);
}

bool IsCharger(int client)
{
    return IsValidClient(client) && GetEntProp(client, Prop_Send, "m_zombieClass") == 6;
}

bool IsBoomer(int client)
{
    return IsValidClient(client) && GetEntProp(client, Prop_Send, "m_zombieClass") == 2;
}

bool IsValidClient(int client)
{
    return (client > 0 && client <= MaxClients && IsClientInGame(client));
}