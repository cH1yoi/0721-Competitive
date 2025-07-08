#pragma semicolon 1
#include <sourcemod>
#define IsValidClient(%1) 			(%1 > 0 && %1 <= MaxClients && IsClientInGame(%1))
int SInum[MAXPLAYERS+1][4];
public Plugin myinfo =
{
    name        = "survivor_damage_control",
    author      = "啥也不懂的小白",
    description = "生还者被控提示及数据统计",
    version     = "1.0",
    url         = "",
}

public void OnPluginStart()
{
    HookEvent("lunge_pounce", Event_LungePounce);//扑到人
    HookEvent("choke_start", Event_TongueGrab);//拉到人
    HookEvent("jockey_ride", Event_PlayerRided);//骑到人
    HookEvent("charger_pummel_start", Event_PlayerCharged);//压到人
    HookEvent("map_transition", Ending);
    for(int i = 1; i <= MAXPLAYERS; i++)
    {
        for(int j = 0; j <= 3; j++)
        {
            SInum[i][j] = 0;
        }
    }
}

public void OnClientPutInServer(int iClient)
{
    for(int i = 0; i <= 3; i++)
    {
       SInum[iClient][i] = 0;
    }
}

public void OnClientDisconnect(int iClient)
{
   for(int i = 0; i <= 3; i++)
   {
       SInum[iClient][i] = 0;
   }
}

public void Event_LungePounce(Event event, const char[] name, bool dontBroadcast)
{
    int SI = GetClientOfUserId(event.GetInt("userid"));
    int survivor = GetClientOfUserId(event.GetInt("victim"));
    int SIhealth = GetEntProp(SI, Prop_Send, "m_iHealth");
    SInum[survivor][0]++;
    //(survivor,"",SI,SIhealth);
}

public void Event_TongueGrab(Event event, const char[] name, bool dontBroadcast)
{
    int SI = GetClientOfUserId(event.GetInt("userid"));
    int survivor = GetClientOfUserId(event.GetInt("victim"));
    int SIhealth = GetEntProp(SI, Prop_Send, "m_iHealth");
    SInum[survivor][1]++;
    //PrintToChat(survivor,"",SI,SIhealth);
}

public void Event_PlayerRided(Event event, const char[] name, bool dontBroadcast)
{
    int SI = GetClientOfUserId(event.GetInt("userid"));
    int survivor = GetClientOfUserId(event.GetInt("victim"));
    int SIhealth = GetEntProp(SI, Prop_Send, "m_iHealth");
    SInum[survivor][2]++;
    //PrintToChat(survivor,"",SI,SIhealth);
}

public void Event_PlayerCharged(Event event, const char[] name, bool dontBroadcast)
{
    int SI = GetClientOfUserId(event.GetInt("userid"));
    int survivor = GetClientOfUserId(event.GetInt("victim"));
    int SIhealth = GetEntProp(SI, Prop_Send, "m_iHealth");
    SInum[survivor][3]++;
    //PrintToChat(survivor,"",SI,SIhealth);
}

public void Ending(Event event, const char[] name, bool dontBroadcast)
{
    for(int i = 1; i <= MaxClients; i++)
    {
        if(IsSurvivor(i))
        {
            PrintToChat(i,"\x04[RANK]\x05 %N \x01[被扑:\x05%d]\x01[被拉:\x05%d]\x01[被骑:\x05%d]\x01[被撞:\x05%d]",i,SInum[i][0],SInum[i][1],SInum[i][2],SInum[i][3]);
        }
    }
}

bool IsSurvivor(int client)
{
    if(IsValidClient(client) && IsPlayerAlive(client) && GetClientTeam(client) == 2)
    {
       return true;
    }
    return false;
}
