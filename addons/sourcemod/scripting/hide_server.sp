/**
 * 自动切换tags , 感觉有说法的
 */

#include <sourcemod>
#include <sdktools>

#pragma semicolon 1
#pragma newdecls required

ConVar g_hSurvivorLimit;
ConVar g_hServerTags;
ConVar g_hDefaultTags;
ConVar g_hHiddenTags;

public Plugin myinfo = 
{
    name = "Hide Server",
    author = "Hana",
    description = "Auto switch server tags",
    version = "1.0",
    url = "https://steamcommunity.com/profiles/76561197983870853/"
};

public void OnPluginStart()
{
    g_hSurvivorLimit = FindConVar("survivor_limit");
    g_hServerTags = FindConVar("sv_tags");
    
    g_hDefaultTags = CreateConVar("server_default_tags", "versus,hana,confogl,gravity,secure", "Server Default Tags", FCVAR_NOTIFY);
    g_hHiddenTags = CreateConVar("server_hidden_tags", "hidden", "Hidden Tags", FCVAR_NOTIFY);
    
    char defaultTags[256];
    g_hDefaultTags.GetString(defaultTags, sizeof(defaultTags));
    g_hServerTags.SetString(defaultTags);
    
    HookEvent("player_connect_full", Event_PlayerConnect);
    HookEvent("player_disconnect", Event_PlayerDisconnect, EventHookMode_Pre);
    
}

public void OnMapStart()
{
    CreateTimer(60.0, Timer_CheckPlayers);
}

public Action Event_PlayerConnect(Event event, const char[] name, bool dontBroadcast)
{
    CreateTimer(5.0, Timer_CheckPlayers);
    return Plugin_Continue;
}

public Action Event_PlayerDisconnect(Event event, const char[] name, bool dontBroadcast)
{
    int client = GetClientOfUserId(event.GetInt("userid"));
    
    if (client > 0 && IsHuman(client) && (IsSurvivor(client) || IsInfected(client)))
    {
        CreateTimer(5.0, Timer_CheckPlayers);
    }
    
    return Plugin_Continue;
}

public Action Timer_CheckPlayers(Handle timer)
{
    CheckAndUpdateTags();
    return Plugin_Continue;
}

bool CheckPlayers() 
{
    int count = 0;
    
    for (int client = 1; client <= MaxClients; client++) 
    {
        if (IsSurvivor(client) || IsInfected(client)) 
        {
            count++;
        }
    }
    return count == g_hSurvivorLimit.IntValue * 2;
}

void CheckAndUpdateTags()
{
    char defaultTags[256], hiddenTags[256];
    
    g_hDefaultTags.GetString(defaultTags, sizeof(defaultTags));
    g_hHiddenTags.GetString(hiddenTags, sizeof(hiddenTags));
    
    if (CheckPlayers())
    {
        g_hServerTags.SetString(hiddenTags);
    }
    else
    {
        g_hServerTags.SetString(defaultTags);
    }
}

stock bool IsSurvivor(int client)                                                   
{                                                                               
    return IsHuman(client) && GetClientTeam(client) == 2; 
}

stock bool IsInfected(int client)                                                   
{                                                                               
    return IsHuman(client) && GetClientTeam(client) == 3; 
}

stock bool IsHuman(int client)
{
    return IsClientInGame(client) && !IsFakeClient(client);
}