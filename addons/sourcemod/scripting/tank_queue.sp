/*
    应该会支持在游戏内部分事件节点主动输出
    也许会打算支持更多调整谁使用坦克的功能
*/
#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <colors>
#undef REQUIRE_PLUGIN
#include <l4d_tank_control_eq>
#define REQUIRE_PLUGIN

public Plugin myinfo =
{
	name = "L4D2 Tank Queue",
	author = "栗子, Hana",
	description = "Show Tank Queue and more",
	version = "1.0",
	url = "https://steamcommunity.com/profiles/76561198150278610/"
};

bool g_bTceqAvailable = false;

public void OnAllPluginsLoaded()
{
    CreateTimer(0.1,Timer_later);
    g_bTceqAvailable= LibraryExists("l4d_tank_control_eq");
}

public void OnLibraryAdded(const char[] name)
{
    if (StrEqual(name, "l4d_tank_control_eq"))
    {
        g_bTceqAvailable= true;
    }
}

public void OnLibraryRemoved(const char[] name)
{
    if (StrEqual(name, "l4d_tank_control_eq"))
    {
        g_bTceqAvailable = false;
    }
}

public Action Timer_later(Handle timer)
{
    
    return Plugin_Handled;
}

public void OnPluginStart()
{
    // Register sm_tankinfo
    RegConsoleCmd("sm_tankpool", TankPool, "坦克队列");
    //Register sm_tanklist
    RegConsoleCmd("sm_tanklist", TankList, "谁玩过克了");
}

// Get Tankinfo which players are in list 
public Action TankPool(int client,int args)
{
    if (!client)
        return Plugin_Handled;

    if (!g_bTceqAvailable)
    {
        return Plugin_Handled;
    }
    //use the GetTankQueue to get Tankinfo    
    ArrayList tankQueue = GetTankQueue();
    
    if (tankQueue == null){
        return Plugin_Handled;
    }
    CPrintToChat(client, "{default}━━━━━━━━ {green}坦克队列{default} ━━━━━━━━");
    // show player who is in tanklist 
    char steamId[64], playerName[MAX_NAME_LENGTH];
    int count = 0;
    for (int i = 0; i < tankQueue.Length; i++)
    {
        tankQueue.GetString(i, steamId, sizeof(steamId));
        int target = GetClientBySteamId(steamId);
        if (target != -1)
        {
            count++;
            GetClientName(target, playerName, sizeof(playerName));
            CPrintToChat(client, " {olive}%d. {default}%s", count, playerName);
        }
    }
    
    if (count == 0) {
        CPrintToChat(client, " {red}当前没有玩家在队列中");
    }
    CPrintToChat(client, "{default}━━━━━━━━━━━━━━━━━━━━━━");
    
    delete tankQueue;
    return Plugin_Handled;
}

//Get TankList which players will are to play tank
public Action TankList(int client, int args)
{
    if (!client){
        return Plugin_Handled;
    }

    if (!g_bTceqAvailable)
    {
        return Plugin_Handled;
    }
    //Get WHO was play the tank and who was not play the tank
    ArrayList hadTank = GetWhosHadTank();
    ArrayList notHadTank = GetWhosNotHadTank();

    if (hadTank == null || notHadTank == null){
        return Plugin_Handled;
    }
    CPrintToChat(client, "{default}━━━━━━━━ {green}坦克状态{default} ━━━━━━━━");
    CPrintToChat(client, "{blue}已经当过坦克的玩家:");
    
    int hadCount = PrintPlayerList(client, hadTank);
    if (hadCount == 0) {
        CPrintToChat(client, " {olive}暂无");
    }
    
    CPrintToChat(client, "{default}━━━━━━━━━━━━━━━━━━━━━━");
    
    delete hadTank;
    delete notHadTank;
    return Plugin_Handled;
}

//Get player SteamID
int GetClientBySteamId(const char[] steamId)
{
    char tempSteamId[64];
    for (int i = 1; i <= MaxClients; i++)
    {
        if (IsClientInGame(i) && !IsFakeClient(i))
        {
            GetClientAuthId(i, AuthId_Steam2, tempSteamId, sizeof(tempSteamId));
            if (StrEqual(steamId, tempSteamId))
            {
                return i;
            }
        }
    }
    return -1;
}

//Simplified PrintPlayerList
int PrintPlayerList(int client, ArrayList list)
{
    char steamId[64], playerName[MAX_NAME_LENGTH];
    int count = 0;
    
    for (int i = 0; i < list.Length; i++)
    {
        list.GetString(i, steamId, sizeof(steamId));
        int target = GetClientBySteamId(steamId);
        
        if (target != -1)
        {
            count++;
            GetClientName(target, playerName, sizeof(playerName));
            CPrintToChat(client, " {olive}❀ {green}%s", playerName);
        }
    }
    return count;
}