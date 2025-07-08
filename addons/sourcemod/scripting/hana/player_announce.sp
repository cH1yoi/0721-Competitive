#pragma semicolon               1
#pragma newdecls                required

#include <sourcemod>
#include <steamworks>
#include <colors>
#include <exp_interface>


public Plugin myinfo = {
    name        = "PlayerAnnounce",
    author      = "TouchMe, Modified, Hana",
    description = "重构了一下",
    version     = "1.0.4",
    url         = "https://github.com/TouchMe-Inc/l4d2_player_announce"
};


#define APP_L4D2                550
#define MAX_SHOTR_NAME_LENGTH   18

bool g_bClientLostConnection[MAXPLAYERS + 1] = {false, ...};

static const char g_szTeamColor[][] = {
    "{olive}",
    "{olive}",
    "{blue}",
    "{red}"
};

/**
  * Called before OnPluginStart.
  */
public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
    if (GetEngineVersion() != Engine_Left4Dead2)
    {
        strcopy(error, err_max, "Plugin only supports Left 4 Dead 2.");
        return APLRes_SilentFailure;
    }

    return APLRes_Success;
}

public void OnPluginStart()
{
    HookEvent("player_disconnect", Event_PlayerDisconnect, EventHookMode_Pre);
    HookEvent("player_team", Event_PlayerTeam, EventHookMode_Post);

    CreateTimer(0.5, Timer_CheckTimingOut, .flags = TIMER_REPEAT);
}

Action Timer_CheckTimingOut(Handle hTimer)
{
    static char sClientName[MAX_NAME_LENGTH];

    for (int iClient = 1; iClient <= MaxClients; iClient++)
    {
        if (!IsClientInGame(iClient) || IsFakeClient(iClient)) {
            continue;
        }

        int iClientTeam = GetClientTeam(iClient);

        if (!iClientTeam) {
            continue;
        }

        if (g_bClientLostConnection[iClient] && !IsClientTimingOut(iClient))
        {
            GetClientNameFixed(iClient, sClientName, sizeof(sClientName), MAX_SHOTR_NAME_LENGTH);
            CPrintToChatAll("%s%s {default}已恢复连接", g_szTeamColor[iClientTeam], sClientName);
            g_bClientLostConnection[iClient] = false;
        }

        else if (!g_bClientLostConnection[iClient] && IsClientTimingOut(iClient))
        {
            GetClientNameFixed(iClient, sClientName, sizeof(sClientName), MAX_SHOTR_NAME_LENGTH);
            CPrintToChatAll("%s%s {default}失去连接", g_szTeamColor[iClientTeam], sClientName);
            g_bClientLostConnection[iClient] = true;
        }
    }
    
    return Plugin_Continue;
}

public void OnClientAuthorized(int iClient, const char[] sAuthId)
{
    if (iClient <= 0 || iClient > MaxClients || !IsClientConnected(iClient) || IsFakeClient(iClient)) {
        return;
    }
    
    if (sAuthId[0] == 'B' || sAuthId[9] == 'L' || strlen(sAuthId) < 3) {
        return;
    }

    if (IsClientInGame(iClient)) {
        if (!SteamWorks_RequestStats(iClient, APP_L4D2)) {
            LogError("SteamWorks_RequestStats调用失败 (客户端: %d, SteamID: %s)", iClient, sAuthId);
        }
    }
}

public void OnClientConnected(int iClient)
{
    if (IsFakeClient(iClient)) {
        return;
    }

    char sClientName[MAX_NAME_LENGTH];

    GetClientNameFixed(iClient, sClientName, sizeof(sClientName), MAX_SHOTR_NAME_LENGTH);

    CPrintToChatAll("玩家 {olive}%s {default}正在连接服务器...", sClientName);

    g_bClientLostConnection[iClient] = false;
}

public void Event_PlayerTeam(Event event, const char[] sEventName, bool bDontBroadcast)
{
    if (GetEventInt(event, "disconnect")) {
        return;
    }

    if (GetEventInt(event, "oldteam")) {
        return;
    }

    int iClientId = GetEventInt(event, "userid");

    CreateTimer(1.0, Timer_ClientInGame, iClientId, TIMER_FLAG_NO_MAPCHANGE);
}

Action Timer_ClientInGame(Handle hTimer, int iClientId)
{
    int iClient = GetClientOfUserId(iClientId);

    if (iClient <= 0 || !IsClientInGame(iClient) || IsFakeClient(iClient)) {
        return Plugin_Stop;
    }

    int iClientTeam = GetClientTeam(iClient);

    char sClientName[MAX_NAME_LENGTH];
    GetClientNameFixed(iClient, sClientName, sizeof(sClientName), MAX_SHOTR_NAME_LENGTH);

    if (strncmp(sClientName, "(S)", 3) == 0) {
        strcopy(sClientName, sizeof(sClientName), sClientName[3]);
    }

    char sSteamID[32];
    GetClientAuthId(iClient, AuthId_Steam2, sSteamID, sizeof(sSteamID));
    
    int iExp = L4D2_GetClientExp(iClient);
    int iExpRank = L4D2_GetClientExpRankLevel(iClient);
    
    int iHours = GetClientHours(iClient);
    
    if (iExp > 0) {
        CPrintToChatAll("%s%s{default}({olive}%s{default}) 加入 - 时长: {olive}%d{default}h - EXP: {olive}%d [%s]", 
            g_szTeamColor[iClientTeam], sClientName, sSteamID, iHours, iExp, EXPRankNames[iExpRank]);
    } else {
        CPrintToChatAll("%s%s{default}({olive}%s{default}) 加入 - 时长: {olive}%d{default}h - EXP: 未知", 
            g_szTeamColor[iClientTeam], sClientName, sSteamID, iHours);
    }

    return Plugin_Stop;
}

void Event_PlayerDisconnect(Event event, const char[] sEventName, bool bDontBroadcast)
{
    int iClient = GetClientOfUserId(GetEventInt(event, "userid"));

    if (iClient <= 0 || IsFakeClient(iClient)) {
        return;
    }

    SetEventBroadcast(event, true);

    int iClientTeam = IsClientInGame(iClient) ? GetClientTeam(iClient) : 0;

    char szClientName[MAX_NAME_LENGTH];
    GetClientNameFixed(iClient, szClientName, sizeof(szClientName), MAX_SHOTR_NAME_LENGTH);

    char szReason[128];
    GetEventString(event, "reason", szReason, sizeof(szReason));

    if (strcmp(szReason, "Disconnect by user.") == 0) {
        CPrintToChatAll("%s%s {default}离开了游戏", g_szTeamColor[iClientTeam], szClientName);
    } else {
        CPrintToChatAll("%s%s {default}离开了游戏 原因: %s", g_szTeamColor[iClientTeam], szClientName, szReason);
    }

    g_bClientLostConnection[iClient] = false;
}

/**
 * Returns the hours played by the player from steam statistics.
 */
int GetClientHours(int iClient)
{
    int iPlayedTime = 0;

    if (!SteamWorks_GetStatCell(iClient, "Stat.TotalPlayTime.Total", iPlayedTime)) {
        return 0;
    }

    return RoundToFloor(float(iPlayedTime) / 3600.0);
}

/**
 * Trims client name if too long.
 */
void GetClientNameFixed(int iClient, char[] name, int length, int iMaxSize)
{
    GetClientName(iClient, name, length);

    if (strlen(name) > iMaxSize)
    {
        name[iMaxSize - 3] = name[iMaxSize - 2] = name[iMaxSize - 1] = '.';
        name[iMaxSize] = '\0';
    }
}
