#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <left4dhooks>

#define PLUGIN_VERSION "2.2"
#define TEAM_INFECTED 3
#define TEAM_SURVIVOR 2
#define CMD_COOLDOWN 60.0
#define SAFE_ROOM_CHECK_INTERVAL 1.0

ConVar g_cvEnabled;
bool g_bIsVersus;
bool g_bLeftSafeRoom[MAXPLAYERS + 1];
bool g_bRoundLive;
bool g_bHasShownInitialInfo;
float g_fLastCommandTime;
Handle g_hSafeRoomTimer;

public Plugin myinfo = 
{
    name = "L4D2 Infected Info Simplified",
    author = "Your Name",
    description = "Rollback to v2.2 without readyup panel display",
    version = PLUGIN_VERSION,
    url = "https://example.com"
};

public void OnPluginStart()
{
    HookEvent("round_start", Event_RoundStart, EventHookMode_PostNoCopy);
    HookEvent("round_end", Event_RoundEnd, EventHookMode_PostNoCopy);
    HookEvent("player_team", Event_PlayerTeam);
    
    RegConsoleCmd("sm_specs", Command_Specs, "显示当前特感配置");
    RegConsoleCmd("sm_si", Command_Specs, "显示当前特感配置");
    RegConsoleCmd("sm_specinfo", Command_Specs, "显示当前特感配置(同!specs)");
    
    g_cvEnabled = CreateConVar("l4d2_infected_info_enabled", "1", "启用/禁用插件", FCVAR_NONE, true, 0.0, true, 1.0);
    
    AutoExecConfig(true, "l4d2_infected_info_simplified");
}

public void OnMapStart()
{
    g_bIsVersus = IsVersusMode();
    g_bRoundLive = false;
    g_bHasShownInitialInfo = false;
    g_fLastCommandTime = 0.0;
    ResetSafeRoomStatus();
}

public void OnMapEnd()
{
    delete g_hSafeRoomTimer;
}

public void OnClientDisconnect(int client)
{
    g_bLeftSafeRoom[client] = false;
}

public void Event_RoundStart(Event event, const char[] name, bool dontBroadcast)
{
    if (!g_cvEnabled.BoolValue || !g_bIsVersus)
        return;
    
    g_bRoundLive = false;
    g_bHasShownInitialInfo = false;
    ResetSafeRoomStatus();
    
    // Start checking for players leaving saferoom
    delete g_hSafeRoomTimer;
    g_hSafeRoomTimer = CreateTimer(SAFE_ROOM_CHECK_INTERVAL, Timer_CheckSafeRoom, _, TIMER_REPEAT);
}

public void Event_RoundEnd(Event event, const char[] name, bool dontBroadcast)
{
    g_bRoundLive = false;
    g_bHasShownInitialInfo = false;
    delete g_hSafeRoomTimer;
}

// 添加缺失的Event_PlayerTeam函数
public void Event_PlayerTeam(Event event, const char[] name, bool dontBroadcast)
{
    if (!g_cvEnabled.BoolValue || !g_bIsVersus || g_bRoundLive)
        return;
    
    int client = GetClientOfUserId(event.GetInt("userid"));
    int newTeam = event.GetInt("team");
    
    // 这里可以添加玩家换队时的处理逻辑
    // 例如: 当玩家加入特感队伍时更新信息
}

public void OnRoundIsLive()
{
    g_bRoundLive = true;
}

public Action Timer_CheckSafeRoom(Handle timer)
{
    if (g_bRoundLive)
    {
        g_hSafeRoomTimer = null;
        return Plugin_Stop;
    }
    
    for (int client = 1; client <= MaxClients; client++)
    {
        if (IsValidClient(client) && GetClientTeam(client) == TEAM_SURVIVOR && IsPlayerAlive(client) && !g_bLeftSafeRoom[client])
        {
            if (!IsPlayerInSafeRoom(client))
            {
                g_bLeftSafeRoom[client] = true;
                if (!g_bHasShownInitialInfo)
                {
                    g_bHasShownInitialInfo = true;
                    ShowInitialInfectedInfo();
                }
                break; // Only show once when first survivor leaves
            }
        }
    }
    
    return Plugin_Continue;
}

// ... [保留其他所有函数不变]

public Action Command_Specs(int client, int args)
{
    if (!g_cvEnabled.BoolValue || !g_bIsVersus)
        return Plugin_Handled;
    
    if (!IsValidClient(client) || GetClientTeam(client) != TEAM_SURVIVOR)
    {
        ReplyToCommand(client, "[SM] 只有生还者可以使用此指令");
        return Plugin_Handled;
    }
    
    float currentTime = GetEngineTime();
    if (g_fLastCommandTime > 0.0 && currentTime - g_fLastCommandTime < CMD_COOLDOWN)
    {
        float remaining = CMD_COOLDOWN - (currentTime - g_fLastCommandTime);
        
        // Notify all survivors about the cooldown
        char playerName[MAX_NAME_LENGTH];
        GetClientName(client, playerName, sizeof(playerName));
        
        for (int i = 1; i <= MaxClients; i++)
        {
            if (IsValidClient(i) && GetClientTeam(i) == TEAM_SURVIVOR && !IsFakeClient(i))
            {
                PrintToChat(i, "\x04[特感信息] \x03%s\x01 请等待 \x05%.1f秒\x01 后查看特感配置", 
                    playerName, remaining);
            }
        }
        return Plugin_Handled;
    }
    
    g_fLastCommandTime = currentTime;
    
    // Notify all survivors who triggered the command
    char playerName[MAX_NAME_LENGTH];
    GetClientName(client, playerName, sizeof(playerName));
    
    char buffer[256];
    GetInfectedInfoString(buffer, sizeof(buffer));
    
    for (int i = 1; i <= MaxClients; i++)
    {
        if (IsValidClient(i) && GetClientTeam(i) == TEAM_SURVIVOR && !IsFakeClient(i))
        {
            PrintToChat(i, "\x04[特感信息] \x03%s\x01 查看了特感配置", playerName);
            PrintToChat(i, "\x04当前特感配置：\x05%s", buffer);
        }
    }
    
    return Plugin_Handled;
}

void ShowInitialInfectedInfo()
{
    char buffer[256];
    GetInfectedInfoString(buffer, sizeof(buffer));
    
    for (int i = 1; i <= MaxClients; i++)
    {
        if (IsClientInGame(i) && !IsFakeClient(i))
        {
            PrintToChat(i, "\x04[开局提示] 特感配置：\x05%s", buffer);
        }
    }
}

void GetInfectedInfoString(char[] buffer, int maxlength)
{
    int infectedCounts[8]; // Indexes: 1=Smoker, 2=Boomer, 3=Hunter, 4=Spitter, 5=Jockey, 6=Charger, 7=Ghost
    
    for (int i = 1; i <= MaxClients; i++)
    {
        if (IsClientInGame(i) && GetClientTeam(i) == TEAM_INFECTED && IsPlayerAlive(i))
        {
            int zombieClass = GetEntProp(i, Prop_Send, "m_zombieClass");
            if (zombieClass >= 1 && zombieClass <= 7)
            {
                infectedCounts[zombieClass]++;
            }
        }
    }
    
    Format(buffer, maxlength, "");
    
    if (infectedCounts[6] > 0) Format(buffer, maxlength, "%s %d只牛", buffer, infectedCounts[6]);
    if (infectedCounts[2] > 0) Format(buffer, maxlength, "%s (%d只胖子)", buffer, infectedCounts[2]);
    if (infectedCounts[1] > 0) Format(buffer, maxlength, "%s %d只舌头", buffer, infectedCounts[1]);
    if (infectedCounts[3] > 0) Format(buffer, maxlength, "%s %d只HT", buffer, infectedCounts[3]);
    if (infectedCounts[4] > 0) Format(buffer, maxlength, "%s (%d只口水)", buffer, infectedCounts[4]);
    if (infectedCounts[5] > 0) Format(buffer, maxlength, "%s %d只猴子", buffer, infectedCounts[5]);
    
    // Check for ghost players
    int ghostCount = 0;
    for (int i = 1; i <= MaxClients; i++)
    {
        if (IsClientInGame(i) && GetClientTeam(i) == TEAM_INFECTED && IsPlayerAlive(i) && GetEntProp(i, Prop_Send, "m_isGhost"))
        {
            ghostCount++;
        }
    }
    if (ghostCount > 0) Format(buffer, maxlength, "%s %d个玩家处于灵魂状态", buffer, ghostCount);
}

bool IsPlayerInSafeRoom(int client)
{
    float origin[3];
    GetClientAbsOrigin(client, origin);
    
    // Check against both start and end saferoom entities
    int startSaferoom = FindEntityByClassname(-1, "info_survivor_position");
    int endSaferoom = FindEntityByClassname(-1, "info_survivor_position_finale");
    
    while (startSaferoom != -1)
    {
        float saferoomOrigin[3];
        GetEntPropVector(startSaferoom, Prop_Data, "m_vecOrigin", saferoomOrigin);
        
        if (GetVectorDistance(origin, saferoomOrigin) < 1000.0)
        {
            return true;
        }
        
        startSaferoom = FindEntityByClassname(startSaferoom, "info_survivor_position");
    }
    
    while (endSaferoom != -1)
    {
        float saferoomOrigin[3];
        GetEntPropVector(endSaferoom, Prop_Data, "m_vecOrigin", saferoomOrigin);
        
        if (GetVectorDistance(origin, saferoomOrigin) < 1000.0)
        {
            return true;
        }
        
        endSaferoom = FindEntityByClassname(endSaferoom, "info_survivor_position_finale");
    }
    
    return false;
}

void ResetSafeRoomStatus()
{
    for (int i = 0; i <= MaxClients; i++)
    {
        g_bLeftSafeRoom[i] = false;
    }
}

bool IsVersusMode()
{
    char gameMode[32];
    FindConVar("mp_gamemode").GetString(gameMode, sizeof(gameMode));
    return StrEqual(gameMode, "versus", false) || StrEqual(gameMode, "mutation12", false); // mutation12 is Realism Versus
}

bool IsValidClient(int client)
{
    return client > 0 && client <= MaxClients && IsClientInGame(client);
}