#include <sourcemod>
#include <sdktools>

#pragma semicolon 1
#pragma newdecls required

ConVar g_cvFFEnabled;
ConVar g_cvDirectorReady;

int g_iDamageCache[MAXPLAYERS+1][MAXPLAYERS+1];
Handle g_hFFTimer[MAXPLAYERS+1];
bool g_bFFActive[MAXPLAYERS+1];

public Plugin myinfo =
{
    name = "L4D FF Announce Plugin",
    description = "有点傲娇的友伤提示",
    author = "Frustian & Hana",
    version = "1.0",
    url = ""
};

public void OnPluginStart()
{
    g_cvFFEnabled = CreateConVar("l4d_ff_announce_enable", "1", "Enable Announcing Friendly Fire", FCVAR_NOTIFY);
    g_cvDirectorReady = FindConVar("director_ready_duration");

    HookEvent("player_hurt_concise", Event_HurtConcise);
    HookEvent("player_death", Event_PlayerDeath);

    //AutoExecConfig(true, "l4dffannounce");
}

public Action Event_HurtConcise(Event event, const char[] name, bool dontBroadcast)
{
    int attacker = event.GetInt("attackerentid");
    int victim = GetClientOfUserId(event.GetInt("userid"));
    
    if (!g_cvFFEnabled.BoolValue || 
        !g_cvDirectorReady.IntValue ||
        attacker <= 0 || 
        attacker > MaxClients ||
        !IsClientInGame(attacker) ||
        !IsClientInGame(victim) ||
        GetClientTeam(attacker) != 2 ||
        GetClientTeam(victim) != 2)
        return Plugin_Continue;

    int damage = event.GetInt("dmg_health");

    if (g_bFFActive[attacker])
    {
        g_iDamageCache[attacker][victim] += damage;
        delete g_hFFTimer[attacker];
        DataPack pack;
        g_hFFTimer[attacker] = CreateDataTimer(1.0, Timer_AnnounceFF, pack);
        pack.WriteCell(attacker);
    }
    else
    {
        g_iDamageCache[attacker][victim] = damage;
        g_bFFActive[attacker] = true;
        
        DataPack pack;
        g_hFFTimer[attacker] = CreateDataTimer(1.0, Timer_AnnounceFF, pack);
        pack.WriteCell(attacker);

        for (int i = 1; i <= MaxClients; i++)
        {
            if (i != victim && i != attacker)
                g_iDamageCache[attacker][i] = 0;
        }
    }

    return Plugin_Continue;
}

public Action Timer_AnnounceFF(Handle timer, DataPack pack)
{
    pack.Reset();
    int attacker = pack.ReadCell();
    g_bFFActive[attacker] = false;

    char sVictim[MAX_NAME_LENGTH], sAttacker[MAX_NAME_LENGTH];
    
    if (IsClientInGame(attacker))
        GetClientName(attacker, sAttacker, sizeof(sAttacker));
    else
        strcopy(sAttacker, sizeof(sAttacker), "Disconnected Player");

    for (int i = 1; i <= MaxClients; i++)
    {
        if (g_iDamageCache[attacker][i] > 0 && i != attacker)
        {
            if (!IsClientInGame(i))
                continue;

            GetClientName(i, sVictim, sizeof(sVictim));

            if (IsClientInGame(attacker))
                PrintToChat(attacker, "\x01[\x05!\x01] \x01哼！才不是故意打 \x03%s\x01 的 \x04%d \x01点伤害呢，笨蛋！", sVictim, g_iDamageCache[attacker][i]);
            if (IsClientInGame(i))
                PrintToChat(i, "\x01[\x05!\x01] \x03%s \x01说：别、别误会！这 \x04%d \x01点伤害只是意外啦！", sAttacker, g_iDamageCache[attacker][i]);

            g_iDamageCache[attacker][i] = 0;
        }
    }
    return Plugin_Continue;
}

public void Event_PlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
    int victim = GetClientOfUserId(event.GetInt("userid"));
    if (!victim || !IsClientInGame(victim))
        return;
        
    int attacker = GetClientOfUserId(event.GetInt("attacker"));
    if (!attacker || !IsClientInGame(attacker))
        return;
        
    if (GetClientTeam(attacker) == 2 && GetClientTeam(victim) == 2 && attacker != victim)
    {
        PrintToChatAll("\x01[\x04!\x01] \x05%N \x01哼！才、才不是故意击倒 \x04%N\x01 的呢，笨蛋！", attacker, victim);
    }
}