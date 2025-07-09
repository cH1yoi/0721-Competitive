#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <colors>

#define TEAM_SURVIVOR 2
#define TEAM_INFECTED 3
#define SI_CLASS_TANK 8

public Plugin myinfo = {
    name        = "Tank Damage Stats",
    author      = "HANA, 改进版",
    description = "瞅瞅集火,什么! 1%  √√√×",
    version     = "1.4",
    url         = "https://steamcommunity.com/profiles/76561197983870853/"
};

enum struct TankInfo {
    int health;
    bool isAlive;
    char name[MAX_NAME_LENGTH];
    int entityId;
    int index;
    int totalDamage;
}

enum struct PlayerDamage {
    int userId;
    int damage;
}

ArrayList g_TanksList;
ArrayList g_DamageList;
bool g_bIsTankInPlay;
char g_sLastHumanTankName[MAX_NAME_LENGTH];

public void OnPluginStart()
{
    HookEvent("player_death", Event_PlayerDeath);
    HookEvent("player_hurt", Event_PlayerHurt);
    HookEvent("tank_spawn", Event_TankSpawn);
    HookEvent("round_start", Event_RoundStart, EventHookMode_PostNoCopy);
    HookEvent("round_end", Event_RoundEnd, EventHookMode_PostNoCopy);

    g_TanksList = new ArrayList(sizeof(TankInfo));
    g_DamageList = new ArrayList(sizeof(PlayerDamage));
}

public void OnMapStart()
{
    g_bIsTankInPlay = false;
    g_sLastHumanTankName[0] = '\0';
    ClearAllData();
}

void ClearAllData()
{
    g_TanksList.Clear();
    g_DamageList.Clear();
    g_bIsTankInPlay = false;
}

public void Event_RoundStart(Event event, const char[] name, bool dontBroadcast)
{
    g_bIsTankInPlay = false;
    g_sLastHumanTankName[0] = '\0';
    ClearAllData();
}

public void Event_TankSpawn(Event event, const char[] name, bool dontBroadcast)
{
    int client = GetClientOfUserId(event.GetInt("userid"));
    if (!IsValidClient(client))
        return;
        
    int existingIndex = FindTankByEntityId(client);
    if (existingIndex != -1) {
        TankInfo tank;
        g_TanksList.GetArray(existingIndex, tank);
        tank.isAlive = true;
        tank.health = GetEntProp(client, Prop_Data, "m_iHealth");
        g_TanksList.SetArray(existingIndex, tank);
        return;
    }
        
    TankInfo tank;
    tank.health = GetEntProp(client, Prop_Data, "m_iHealth");
    tank.isAlive = true;
    tank.entityId = client;
    tank.totalDamage = 0;
    
    if (!IsFakeClient(client)) {
        GetClientName(client, tank.name, MAX_NAME_LENGTH);
        strcopy(g_sLastHumanTankName, sizeof(g_sLastHumanTankName), tank.name);
    } else {
        if (g_sLastHumanTankName[0] != '\0') {
            Format(tank.name, MAX_NAME_LENGTH, "AI [%s]", g_sLastHumanTankName);
        } else {
            strcopy(tank.name, MAX_NAME_LENGTH, "AI");
        }
    }
    
    tank.index = g_TanksList.PushArray(tank);
    g_bIsTankInPlay = true;
}

public void Event_PlayerHurt(Event event, const char[] name, bool dontBroadcast)
{
    if (!g_bIsTankInPlay) return;
    
    int victim = GetClientOfUserId(event.GetInt("userid"));
    int attacker = GetClientOfUserId(event.GetInt("attacker"));
    
    if (!IsValidClient(victim) || !IsValidClient(attacker) || !IsTank(victim))
        return;
        
    int damage = event.GetInt("dmg_health");
    int tankIndex = FindTankByEntityId(victim);
    
    if (tankIndex == -1) {
        Event_TankSpawn(event, name, dontBroadcast);
        tankIndex = FindTankByEntityId(victim);
        if (tankIndex == -1) return;
    }
    
    TankInfo tank;
    g_TanksList.GetArray(tankIndex, tank);
    tank.health = GetEntProp(victim, Prop_Data, "m_iHealth");
    tank.totalDamage += damage;
    g_TanksList.SetArray(tankIndex, tank);
    
    AddPlayerDamage(attacker, victim, damage);
}

void AddPlayerDamage(int attackerClient, int tankClient, int damage)
{
    if (damage <= 0 || !IsValidClient(attackerClient))
        return;
    
    int attackerUserId = GetClientUserId(attackerClient);
    int tankIndex = FindTankByEntityId(tankClient);
    
    if (tankIndex == -1) return;
    
    bool found = false;
    for (int i = 0; i < g_DamageList.Length; i++) {
        PlayerDamage playerDmg;
        g_DamageList.GetArray(i, playerDmg);
        
        if (playerDmg.userId == attackerUserId) {
            playerDmg.damage += damage;
            g_DamageList.SetArray(i, playerDmg);
            found = true;
            break;
        }
    }
    
    if (!found) {
        PlayerDamage playerDmg;
        playerDmg.userId = attackerUserId;
        playerDmg.damage = damage;
        g_DamageList.PushArray(playerDmg);
    }
}

public void Event_PlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
    int victim = GetClientOfUserId(event.GetInt("userid"));
    
    if (!IsValidClient(victim))
        return;
        
    if (IsTank(victim)) {
        int tankIndex = FindTankByEntityId(victim);
        if (tankIndex != -1) {
            TankInfo tank;
            g_TanksList.GetArray(tankIndex, tank);
            tank.isAlive = false;
            g_TanksList.SetArray(tankIndex, tank);
            
            DataPack dp = new DataPack();
            dp.WriteCell(tankIndex);
            dp.WriteCell(victim);
            CreateTimer(0.1, Timer_DisplayTankDamage, dp);
            
        }
    }
}

Action Timer_DisplayTankDamage(Handle timer, DataPack dp)
{
    dp.Reset();
    int tankIndex = dp.ReadCell();
    dp.ReadCell();
    delete dp;
    
    DisplaySpecificTankDamage(tankIndex);
    
    bool anyTankAlive = false;
    for (int i = 0; i < g_TanksList.Length; i++) {
        TankInfo tank;
        g_TanksList.GetArray(i, tank);
        if (tank.isAlive && IsValidClient(tank.entityId) && IsTank(tank.entityId)) {
            anyTankAlive = true;
            break;
        }
    }
    
    if (!anyTankAlive) {
        ClearAllData();
    }
    
    return Plugin_Stop;
}

void DisplaySpecificTankDamage(int tankIndex)
{
    if (tankIndex < 0 || tankIndex >= g_TanksList.Length)
        return;
    
    TankInfo tank;
    g_TanksList.GetArray(tankIndex, tank);
    
    ArrayList tankDamage = new ArrayList(sizeof(PlayerDamage));
    int totalDamage = 0;
    
    for (int i = 0; i < g_DamageList.Length; i++) {
        PlayerDamage playerDmg;
        g_DamageList.GetArray(i, playerDmg);
        
        if (playerDmg.damage > 0) {
            tankDamage.PushArray(playerDmg);
            totalDamage += playerDmg.damage;
        }
    }
    
    if (tankDamage.Length == 0 || totalDamage <= 0) {
        delete tankDamage;
        return;
    }
    
    SortTankDamage(tankDamage);
    
    for (int i = 1; i <= MaxClients; i++) {
        if (!IsValidClient(i) || !IsClientInGame(i))
            continue;
            
        CPrintToChat(i, "┌ <{green}Tank{default}> {olive}%s{default} 受到的伤害:", tank.name);
        
        for (int j = 0; j < tankDamage.Length; j++) {
            PlayerDamage playerDmg;
            tankDamage.GetArray(j, playerDmg);
            
            int client = GetClientOfUserId(playerDmg.userId);
            
            if (client <= 0 || !IsClientInGame(client))
                continue;
                
            int damage = playerDmg.damage;
            int percentage = RoundToNearest((float(damage) / float(totalDamage)) * 100.0);
            
            char spaces[8];
            Format(spaces, sizeof(spaces), "%s", (damage < 1000) ? "  " : "");
            
            if (j == tankDamage.Length - 1) {
                CPrintToChat(i, "└ %s{olive}%4d{default} [{green}%3d%%{default}] {blue}%N{default}", 
                    spaces, damage, percentage, client);
            } else {
                CPrintToChat(i, "├ %s{olive}%4d{default} [{green}%3d%%{default}] {blue}%N{default}", 
                    spaces, damage, percentage, client);
            }
        }
    }
    
    delete tankDamage;
}

void SortTankDamage(ArrayList damageList)
{
    int size = damageList.Length;
    
    for (int i = 0; i < size - 1; i++) {
        for (int j = 0; j < size - i - 1; j++) {
            PlayerDamage damage1, damage2;
            damageList.GetArray(j, damage1);
            damageList.GetArray(j + 1, damage2);
            
            if (damage1.damage < damage2.damage) {
                damageList.SwapAt(j, j + 1);
            }
        }
    }
}

public void Event_RoundEnd(Event event, const char[] name, bool dontBroadcast)
{
    if (g_bIsTankInPlay) {
        for (int i = 0; i < g_TanksList.Length; i++) {
            TankInfo tank;
            g_TanksList.GetArray(i, tank);
            
            if (tank.isAlive && IsValidClient(tank.entityId) && IsTank(tank.entityId)) {
                DisplaySpecificTankDamage(i);
                
                int currentHealth = GetEntProp(tank.entityId, Prop_Data, "m_iHealth");
                
                for (int client = 1; client <= MaxClients; client++) {
                    if (IsValidClient(client) && IsClientInGame(client)) {
                        CPrintToChat(client, "{default}<{green}Tank{default}> {olive}%s{default} 剩余血量: {red}%d", 
                            tank.name, currentHealth);
                    }
                }
            }
        }
    }
    ClearAllData();
}

bool IsValidClient(int client)
{
    return (client > 0 && client <= MaxClients && IsClientInGame(client));
}

bool IsTank(int client)
{
    return (GetClientTeam(client) == TEAM_INFECTED && GetEntProp(client, Prop_Send, "m_zombieClass") == SI_CLASS_TANK);
}

int FindTankByEntityId(int entityId)
{
    for (int i = 0; i < g_TanksList.Length; i++) {
        TankInfo tank;
        g_TanksList.GetArray(i, tank);
        if (tank.entityId == entityId) {
            return i;
        }
    }
    return -1;
}