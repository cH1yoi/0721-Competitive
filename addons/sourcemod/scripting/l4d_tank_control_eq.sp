#pragma semicolon 1
#pragma newdecls required

#include <colors>
#include <readyup>
#include <sourcemod>
#include <left4dhooks>

#define TEAM_SPECTATOR          1
#define TEAM_INFECTED           3
#define ZOMBIECLASS_TANK        8
#define IS_SPECTATOR(%1)        (GetClientTeam(%1) == TEAM_SPECTATOR)
#define IS_INFECTED(%1)         (GetClientTeam(%1) == TEAM_INFECTED)
#define IS_VALID_INFECTED(%1)   (IsClientInGame(%1) && IS_INFECTED(%1))
#define IS_VALID_SPECTATOR(%1)  (IsClientInGame(%1) && IS_SPECTATOR(%1))

int g_iTankControlPass[MAXPLAYERS + 1] = { 1, ... };

ArrayList h_whosHadTank;
ArrayList h_tankQueue;

ConVar 
    hTankPrint,
    hTankWindow, 
    hTankDebug;

char 
    queuedTankSteamId[64],
    tankInitiallyChosen[64];

float 
    fTankGrace,
    initialTankLeft,
    gotTankAt;

int dcedTankFrustration = -1;

bool g_bRoundStarted;

Handle g_hForwardOnTryOfferingTankBot;
Handle g_hForwardOnTankSelection;
Handle g_hForwardOnQueueChanged;

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
    RegPluginLibrary("l4d_tank_control_eq");

    CreateNative("GetTankSelection", Native_GetTankSelection);
    CreateNative("GetWhosHadTank", Native_GetWhosHadTank);
    CreateNative("GetWhosNotHadTank", Native_GetWhosNotHadTank);
    CreateNative("ClearWhosHadTank", Native_ClearWhosHadTank);
    CreateNative("GetTankPool", Native_GetTankPool);
    CreateNative("SetTank", Native_SetTank);
    CreateNative("GetTankQueue", Native_GetTankQueue);
    CreateNative("AddToTankQueue", Native_AddToTankQueue);
    CreateNative("RemoveFromTankQueue", Native_RemoveFromTankQueue);
    CreateNative("GetTankPassedCount", Native_GetTankPassedCount);

    CreateGlobalForward("OnTankControlReset", ET_Ignore);
    CreateGlobalForward("OnChooseTank", ET_Event, Param_String);
    CreateGlobalForward("OnTankGiven", ET_Ignore, Param_String);

    g_hForwardOnTryOfferingTankBot = new GlobalForward("TankControl_OnTryOfferingTankBot", ET_Ignore, Param_String);
    g_hForwardOnTankSelection = new GlobalForward("TankControl_OnTankSelection", ET_Ignore, Param_String);
    g_hForwardOnQueueChanged = CreateGlobalForward("OnTankQueueChanged", ET_Ignore);

    return APLRes_Success;
}

int Native_GetTankSelection(Handle plugin, int numParams) { return getInfectedPlayerBySteamId(queuedTankSteamId); }

public Plugin myinfo = 
{
    name = "L4D2 Tank Control",
    author = "arti, (Contributions by: Sheo, Sir, Altair-Sossai, Hana, Nepkey(技))",
    description = "Distributes the role of the tank evenly throughout the team, allows for overrides. (Includes forwards)",
    version = "0.0.29",
    url = "https://github.com/SirPlease/L4D2-Competitive-Rework"
}

public void OnPluginStart()
{
    LoadTranslation("l4d_tank_control_eq.phrases");
    LoadTranslations("common.phrases");
    
    // Event hooks
    HookEvent("player_left_start_area", PlayerLeftStartArea_Event, EventHookMode_PostNoCopy);
    HookEvent("round_start", RoundStart_Event, EventHookMode_PostNoCopy);
    HookEvent("round_end", RoundEnd_Event, EventHookMode_PostNoCopy);
    HookEvent("player_team", PlayerTeam_Event, EventHookMode_Post);
    HookEvent("player_death", PlayerDeath_Event, EventHookMode_Post);
    
    // Initialise the tank arrays/data values
    h_whosHadTank = new ArrayList(ByteCountToCells(64));
    h_tankQueue = new ArrayList(ByteCountToCells(64));

    // Admin commands
    RegAdminCmd("sm_tankshuffle", TankShuffle_Cmd, ADMFLAG_SLAY, "Re-picks at random someone to become tank.");
    RegAdminCmd("sm_givetank", GiveTank_Cmd, ADMFLAG_SLAY, "Gives the tank to a selected player");
    RegAdminCmd("sm_addtankpool", AddTankPool_Cmd, ADMFLAG_SLAY, "Adds selected player to tank pool.");
    RegAdminCmd("sm_queuetank", AddTankPool_Cmd, ADMFLAG_SLAY, "Adds selected player to tank pool.");
    RegAdminCmd("sm_removetankpool", RemoveTankPool_Cmd, ADMFLAG_SLAY, "Removes selected player from tank pool.");
    RegAdminCmd("sm_dequeuetank", RemoveTankPool_Cmd, ADMFLAG_SLAY, "Removes selected player from tank pool.");

    // Register the boss commands
    RegConsoleCmd("sm_tank", Tank_Cmd, "Shows who is becoming the tank.");
    RegConsoleCmd("sm_boss", Tank_Cmd, "Shows who is becoming the tank.");
    RegConsoleCmd("sm_witch", Tank_Cmd, "Shows who is becoming the tank.");
    
    // Cvars
    hTankPrint  = CreateConVar("tankcontrol_print_all", "0", "Who gets to see who will become the tank? (0 = Infected, 1 = Everyone)");
    hTankWindow = CreateConVar("tankcontrol_force_window", "0.0", "Give player that was initially going to be Tank (or was Tank and dced) back the Tank this long after Tank was given to somebody else (0 = Off)");
    hTankDebug  = CreateConVar("tankcontrol_debug", "0", "Whether or not to debug to console");
}

public void OnMapStart()
{
    for (int i = 1; i <= MaxClients; i++)
    {
        g_iTankControlPass[i] = 1;
    }
}

/*=========================================================================
|                            Left4Dhooks                                  |
=========================================================================*/


public void L4D2_OnTankPassControl(int iOldTank, int iNewTank, int iPassCount)
{
    /*
    * As the Player switches to AI on disconnect/team switch, we have to make sure we're only checking this if the old Tank was AI.
    * Then apply the previous' Tank's Frustration and Grace Period (if it still had Grace)
    */
    if (dcedTankFrustration != -1 && IsFakeClient(iOldTank))
    {
        SetTankFrustration(iNewTank, dcedTankFrustration);
        CTimer_Start(GetFrustrationTimer(iNewTank), fTankGrace);
    }

    gotTankAt = GetGameTime();
    if (hTankDebug.BoolValue)
        PrintToConsoleAll("[TC] gotTankAt set to %f (iOldTank: %N - iNewTank: %N)", GetGameTime(), iOldTank, iNewTank);
}

/**
 * Make sure we give the tank to our queued player.
 */
public Action L4D_OnTryOfferingTankBot(int tank_index, bool &enterStatis)
{
    // Reset the tank's frustration if need be
    if (!IsFakeClient(tank_index)) 
    {
        if (g_iTankControlPass[tank_index] < 2)
        {
            PrintHintText(tank_index, "%t", "HintText");
            for (int i = 1; i <= MaxClients; i++) 
            {
                if (!IS_VALID_INFECTED(i) && !IS_VALID_SPECTATOR(i))
                    continue;

                if (tank_index == i) 
                    CPrintToChat(i, "%t %t", "TagRage", "RefilledBot");
                else 
                    CPrintToChat(i, "%t %t", "TagRage", "Refilled", tank_index);
            }
            
            SetTankFrustration(tank_index, 100);
            g_iTankControlPass[tank_index]++;
            return Plugin_Handled;
        }
        else
        {
            L4D_ReplaceWithBot(tank_index);
            return Plugin_Handled;
        }
    }

    // Allow third party plugins to override tank selection
    char sOverrideTank[64];
    sOverrideTank[0] = '\0';
    Call_StartForward(g_hForwardOnTryOfferingTankBot);
    Call_PushStringEx(sOverrideTank, sizeof(sOverrideTank), SM_PARAM_STRING_UTF8, SM_PARAM_COPYBACK);
    Call_Finish();

    if (!StrEqual(sOverrideTank, ""))
        strcopy(queuedTankSteamId, sizeof(queuedTankSteamId), sOverrideTank);
    
    // If we don't have a queued tank, choose one
    if (StrEqual(queuedTankSteamId, ""))
        chooseTank(0);
    
    // Mark the player as having had tank
    if (!StrEqual(queuedTankSteamId, ""))
    {
        setTankTickets(queuedTankSteamId, 20000);

        if (h_whosHadTank.FindString(queuedTankSteamId) == -1)
            h_whosHadTank.PushString(queuedTankSteamId);

        int index = h_tankQueue.FindString(queuedTankSteamId);
        if (index != -1)
            h_tankQueue.Erase(index);
    }
    
    return Plugin_Continue;
}

public void L4D_OnLeaveStasis(int tank)
{
    // Tank is always AI here, delay by a frame.
    RequestFrame(L4D_OnLeaveStasis_Post, GetClientUserId(tank));
}

void L4D_OnLeaveStasis_Post(int userid)
{
    int tank = GetClientOfUserId(userid);
    // Tank passed from AI to a player, nothing to do here.
    if (!tank || !IsClientInGame(tank))
        return;
    
    // @Forgetest: 
    //   AI Tank may have committed suicide at the moment
    if (!IsPlayerAlive(tank) || GetEntProp(tank, Prop_Send, "m_isIncapacitated")) // Thanks to @sheo for noting the tank incap
        return;

    if (hTankDebug.BoolValue)
        PrintToConsoleAll("[TC] Tank was not properly assigned to a player, trying to re-assign...");

    int newTank = getInfectedPlayerBySteamId(queuedTankSteamId);

    // Still no candidates, give up.
    if (newTank == -1)
    {
        if (hTankDebug.BoolValue)
            PrintToConsoleAll("[TC] Tried to assign Tank to another player, but there's no one available?");

        return;
    }

    if (hTankDebug.BoolValue)
        PrintToConsoleAll("[TC] Assigned tank to %N.", newTank);

    L4D_ReplaceTank(tank, newTank);
}

/*=========================================================================
|                                 Events                                  |
=========================================================================*/


/**
 * When a new game starts, reset the tank pool.
 */
void RoundStart_Event(Event hEvent, const char[] eName, bool dontBroadcast)
{
    CreateTimer(10.0, newGame);
    dcedTankFrustration = -1;
    gotTankAt = 0.0;
    tankInitiallyChosen = "";
    g_bRoundStarted = true;
}

Action newGame(Handle timer)
{
    int teamAScore = L4D2Direct_GetVSCampaignScore(0);
    int teamBScore = L4D2Direct_GetVSCampaignScore(1);

    // If it's a new game, reset the tank pool
    if (teamAScore == 0 && teamBScore == 0)
    {
        h_whosHadTank.Clear();
        h_tankQueue.Clear();
        queuedTankSteamId = "";
        tankInitiallyChosen = "";
    }

    return Plugin_Stop;
}

/**
 * When the round ends, reset the active tank.
 */
void RoundEnd_Event(Event hEvent, const char[] eName, bool dontBroadcast)
{
    queuedTankSteamId = "";
    tankInitiallyChosen = "";
    g_bRoundStarted = false;
}

/**
 * When a player leaves the start area, choose a tank and output to all.
 */
void PlayerLeftStartArea_Event(Event hEvent, const char[] eName, bool dontBroadcast)
{
    tankInitiallyChosen = "";

    chooseTank(0);
    outputTankToAll(0);
}

/**
 * When the queued tank switches teams, choose a new one
 */
void PlayerTeam_Event(Event hEvent, const char[] name, bool dontBroadcast)
{
    int team = hEvent.GetInt("team");
    int oldTeam = hEvent.GetInt("oldteam");
    int client = GetClientOfUserId(hEvent.GetInt("userid"));
    char tmpSteamId[64];

    if (client < 1 || client > MaxClients)
        return;

    if (oldTeam == TEAM_INFECTED || team == TEAM_INFECTED)
    {
        RequestFrame(CleanTankQueue);
    }

    if (oldTeam == TEAM_INFECTED)
    {
        /*
        * Triggers for disconnects as well as forced-swaps and whatnot.
        * Allows us to always reliably detect when the current Tank player loses control due to unnatural reasons.
        */
        if (!IsFakeClient(client))
        {
            int zombieClass = GetEntProp(client, Prop_Send, "m_zombieClass");
            if (zombieClass == ZOMBIECLASS_TANK)
            {
                dcedTankFrustration = GetTankFrustration(client);
                fTankGrace = CTimer_GetRemainingTime(GetFrustrationTimer(client));

                // Slight fix due to the timer seemingly always getting stuck between 0.5s~1.2s even after Grace period has passed.
                // CTimer_IsElapsed still returns false as well.
                if (fTankGrace < 0.0 || dcedTankFrustration < 100) 
                    fTankGrace = 0.0;
            }
        }

        GetClientAuthId(client, AuthId_Steam2, tmpSteamId, sizeof(tmpSteamId));

        if (StrEqual(tankInitiallyChosen, tmpSteamId))
            initialTankLeft = GetGameTime();

        if (StrEqual(queuedTankSteamId, tmpSteamId))
        {
            RequestFrame(chooseTank, 0);
            RequestFrame(outputTankToAll, 0);
        }
    }

    if (team == TEAM_INFECTED && !IsFakeClient(client) && !StrEqual(tankInitiallyChosen, ""))
    {
        GetClientAuthId(client, AuthId_Steam2, tmpSteamId, sizeof(tmpSteamId));
        if (StrEqual(tankInitiallyChosen, tmpSteamId))
        {
            /* Not touching multiple tanks with a ten-foot pole.
            Could technically be done though.. TODO? */
            int tank = getTankPlayer();

            if (hTankDebug.BoolValue)
                PrintToConsoleAll("[TC] Tank: %N - L4D2_GetTankCount: %i - initialTankLeft: %f - gotTankAt: %f", tank, L4D2_GetTankCount(), initialTankLeft, gotTankAt);

            float window = hTankWindow.FloatValue;
            if (window > 0.0 && L4D2_GetTankCount() == 1 && tank != -1 && (gotTankAt - initialTankLeft) < window)
            {
                // Delay by a frame as player needs to "settle in"
                RequestFrame(ReplaceTank, client);
            }
            else
            {
                strcopy(queuedTankSteamId, sizeof(queuedTankSteamId), tankInitiallyChosen);
                RequestFrame(outputTankToAll, 0);
            }
        }
    }
}

/**
 * Replaces the current tank with the initially chosen Tank.
 * And requeues the old Tank.
 * 
 * @param deservingTank
 *      The player to give the Tank to.
 */
void ReplaceTank(int deservingTank)
{
    int oldTank = getTankPlayer();

    if (oldTank != -1 && IS_INFECTED(deservingTank))
    {
        if (hTankDebug.BoolValue)
            PrintToConsoleAll("[TC] Tank: %N being replaced by %N", oldTank, deservingTank);

        L4D_ReplaceTank(oldTank, deservingTank);

        char steamId[64];

        // Requeue the old tank        
        GetClientAuthId(oldTank, AuthId_Steam2, steamId, sizeof(steamId));
        if (h_tankQueue.FindString(steamId) == -1)
        {
            h_tankQueue.ShiftUp(0);
            h_tankQueue.SetString(0, steamId);
        }

        int index = h_whosHadTank.FindString(steamId);
        if (index != -1)
            h_whosHadTank.Erase(index);

        // Remove the deserving tank from the queue if they're in it
        GetClientAuthId(deservingTank, AuthId_Steam2, steamId, sizeof(steamId));
        index = h_tankQueue.FindString(steamId);
        if (index != -1)
            h_tankQueue.Erase(index);

        index = h_whosHadTank.FindString(steamId);
        if (index == -1)
            h_whosHadTank.PushString(steamId);                
    }
    else if (hTankDebug.BoolValue)
        PrintToConsoleAll("[TC] oldTank: %i and deservingTank: is%s valid", oldTank, IS_INFECTED(deservingTank) ? "" : " NOT");
}

/**
 * When the tank dies, requeue a player to become tank (for finales)
 */
void PlayerDeath_Event(Event hEvent, const char[] eName, bool dontBroadcast)
{
    int victim = GetClientOfUserId(hEvent.GetInt("userid"));
    
    if (victim && IS_VALID_INFECTED(victim) && gotTankAt > 0.0)
    {
        int zombieClass = GetEntProp(victim, Prop_Send, "m_zombieClass");
        if (zombieClass == ZOMBIECLASS_TANK) 
        {
            if (hTankDebug.BoolValue)
                PrintToConsoleAll("[TC] Tank died (player_death), choosing a new tank");

            tankInitiallyChosen = "";
            chooseTank(0);
            gotTankAt = 0.0;
            dcedTankFrustration = -1;
        }
    }
}

/*=========================================================================
|                               Commands                                  |
=========================================================================*/


/**
 * When a player wants to find out whos becoming tank,
 * output to them.
 */
Action Tank_Cmd(int client, int args)
{
    // Only output if client is in-game and we have a queued tank
    if (!IsClientInGame(client) || StrEqual(queuedTankSteamId, ""))
        return Plugin_Handled;
    
    int tankClientId = getInfectedPlayerBySteamId(queuedTankSteamId);

    if (tankClientId != -1 && (hTankPrint.BoolValue || IS_INFECTED(client) || IS_SPECTATOR(client)))
    {
        if (client == tankClientId) 
            CPrintToChat(client, "%t %t", "TagSelection", "YouBecomeTank");
        else 
            CPrintToChat(client, "%t %t", "TagSelection", "BecomeTank", tankClientId);
    }
    
    return Plugin_Handled;
}

/**
 * Shuffle the tank (randomly give to another player in
 * the pool.
 */
Action TankShuffle_Cmd(int client, int args)
{
    tankInitiallyChosen = "";

    chooseTank(0);
    outputTankToAll(0);
    
    return Plugin_Handled;
}

/**
 * Give the tank to a specific player.
 */
Action GiveTank_Cmd(int client, int args)
{    
    // Who are we targetting?
    char arg1[32];
    GetCmdArg(1, arg1, sizeof(arg1));
    
    // Try and find a matching player
    int target = FindTarget(client, arg1);

    if (target == -1 || !IsClientInGame(target) || IsFakeClient(target))
    {
        CPrintToChat(client, "%t %t", "TagControl", "InvalidTarget");
        return Plugin_Handled;
    }

    // Checking if on our desired team
    if (!IS_INFECTED(target))
    {
        CPrintToChat(client, "%t %t", "TagControl", "NoInfected", target);
        return Plugin_Handled;
    }
    
    // Set the tank
    char steamId[64];
    GetClientAuthId(target, AuthId_Steam2, steamId, sizeof(steamId));

    strcopy(queuedTankSteamId, sizeof(queuedTankSteamId), steamId);
    strcopy(tankInitiallyChosen, sizeof(tankInitiallyChosen), steamId);

    outputTankToAll(0);
    
    return Plugin_Handled;
}

public Action AddTankPool_Cmd(int client, int args)
{
    if (args < 1)
    {
        ReplyToCommand(client, "[SM] Usage: sm_addtankpool <player>");
        return Plugin_Handled;
    }

    char arg[MAX_NAME_LENGTH];
    GetCmdArg(1, arg, sizeof(arg));

    int target = FindTarget(client, arg);
    if (target == -1)
        return Plugin_Handled;

    char steamId[64];
    GetClientAuthId(target, AuthId_Steam2, steamId, sizeof(steamId));

    if (h_tankQueue.FindString(steamId) != -1)
    {
        CPrintToChatAll("%t", "PlayerAlreadyInQueue", target);
        return Plugin_Handled;
    }

    if (StrEqual(queuedTankSteamId, ""))
    {
        strcopy(queuedTankSteamId, sizeof(queuedTankSteamId), steamId);
        strcopy(tankInitiallyChosen, sizeof(tankInitiallyChosen), steamId);
        outputTankToAll(0);
    }
    else
    {
        h_tankQueue.PushString(steamId);
    }
    
    CPrintToChatAll("%t", "PlayerAddedToQueue", target);
    Call_StartForward(g_hForwardOnQueueChanged);
    Call_Finish();

    return Plugin_Handled;
}

public Action RemoveTankPool_Cmd(int client, int args)
{
    if (args < 1)
    {
        ReplyToCommand(client, "[SM] Usage: sm_removetankpool <player>");
        return Plugin_Handled;
    }
    
    char arg[MAX_NAME_LENGTH];
    GetCmdArg(1, arg, sizeof(arg));
    
    int target = FindTarget(client, arg);
    if (target == -1)
        return Plugin_Handled;
        
    char steamId[64];
    GetClientAuthId(target, AuthId_Steam2, steamId, sizeof(steamId));

    bool wasCurrentTank = StrEqual(queuedTankSteamId, steamId);
    int queueIndex = h_tankQueue.FindString(steamId);
    
    if (queueIndex != -1)
    {
        h_tankQueue.Erase(queueIndex);
        CPrintToChatAll("%t", "PlayerRemovedFromQueue", target);
    }
    
    if (wasCurrentTank)
    {
        queuedTankSteamId = "";
        tankInitiallyChosen = "";
        
        if (h_tankQueue.Length > 0)
        {
            char nextTankSteamId[64];
            h_tankQueue.GetString(0, nextTankSteamId, sizeof(nextTankSteamId));
            strcopy(queuedTankSteamId, sizeof(queuedTankSteamId), nextTankSteamId);
            strcopy(tankInitiallyChosen, sizeof(tankInitiallyChosen), nextTankSteamId);
            h_tankQueue.Erase(0);
        }
        else
        {
            chooseTank(0);
        }
        
        outputTankToAll(0);
        CPrintToChatAll("%t", "PlayerRemovedFromCurrent", target);
    }
    
    if (queueIndex == -1 && !wasCurrentTank)
    {
        CPrintToChatAll("%t", "PlayerNotInQueue", target);
        return Plugin_Handled;
    }
    
    Call_StartForward(g_hForwardOnQueueChanged);
    Call_Finish();
    
    return Plugin_Handled;
}

/*=========================================================================
|                                 Stocks                                  |
=========================================================================*/


/**
 * Selects a player on the infected team from random who hasn't been
 * tank and gives it to them.
 */
void chooseTank(any data)
{
    // Allow other plugins to override tank selection.
    char sOverrideTank[64];
    sOverrideTank[0] = '\0';
    Call_StartForward(g_hForwardOnTankSelection);
    Call_PushStringEx(sOverrideTank, sizeof(sOverrideTank), SM_PARAM_STRING_UTF8, SM_PARAM_COPYBACK);
    Call_Finish();

    if (!StrEqual(sOverrideTank, ""))
    {
        strcopy(queuedTankSteamId, sizeof(queuedTankSteamId), sOverrideTank);
        if (StrEqual(tankInitiallyChosen, ""))
            strcopy(tankInitiallyChosen, sizeof(tankInitiallyChosen), sOverrideTank);
        return;
    }

    if (h_tankQueue.Length > 0)
    {
        char steamId[64];
        h_tankQueue.GetString(0, steamId, sizeof(steamId));
        
        int tankClient = getInfectedPlayerBySteamId(steamId);
        if (tankClient != -1 && IS_VALID_INFECTED(tankClient))
        {
            strcopy(queuedTankSteamId, sizeof(queuedTankSteamId), steamId);
            if (StrEqual(tankInitiallyChosen, ""))
                strcopy(tankInitiallyChosen, sizeof(tankInitiallyChosen), steamId);
            h_tankQueue.Erase(0);
            return;
        }
    }

    queuedTankSteamId = "";
    tankInitiallyChosen = "";

    int nextTankIndex = PeekNextTankIndexInTheQueue();

    if (nextTankIndex == -1)
    {
        EnqueueNewInfectedPlayers();
        nextTankIndex = PeekNextTankIndexInTheQueue();
    }

    if (nextTankIndex == -1)
    {
        RemoveAllInfectedFrom(h_tankQueue);
        RemoveAllInfectedFrom(h_whosHadTank);
        EnqueueNewInfectedPlayers();
        nextTankIndex = PeekNextTankIndexInTheQueue();
    }

    if (nextTankIndex == -1)
        return;

    char steamId[64];

    h_tankQueue.GetString(nextTankIndex, steamId, sizeof(steamId));

    strcopy(queuedTankSteamId, sizeof(queuedTankSteamId), steamId);

    if (StrEqual(tankInitiallyChosen, ""))
        strcopy(tankInitiallyChosen, sizeof(tankInitiallyChosen), steamId);

    if (!StrEqual(queuedTankSteamId, ""))
    {
        TriggerQueueChanged();
    }
}

/**
 * Sets the amount of tickets for a particular player, essentially giving them tank.
 */
void setTankTickets(const char[] steamId, int tickets)
{
    int tankClientId = getInfectedPlayerBySteamId(steamId);
    
    for (int i = 1; i <= MaxClients; i++)
    {
        if (IS_VALID_INFECTED(i) && !IsFakeClient(i))
            L4D2Direct_SetTankTickets(i, (i == tankClientId) ? tickets : 0);
    }
}

/**
 * Output who will become tank
 */
void outputTankToAll(any data)
{
    int tankClientId = getInfectedPlayerBySteamId(queuedTankSteamId);
    
    if (tankClientId != -1)
    {
        for (int i = 1; i <= MaxClients; i++) 
        {
            if (!IsClientInGame(i) || (!hTankPrint.BoolValue && !IS_INFECTED(i) && !IS_SPECTATOR(i)))
                continue;

            if (tankClientId == i) 
                CPrintToChat(i, "%t %t", "TagSelection", "YouBecomeTank");
            else 
                CPrintToChat(i, "%t %t", "TagSelection", "BecomeTank", tankClientId);
        }
    }
}

/**
 * Retrieves the current Tank player.
 * 
 * @return
 *     The tank's client index or -1 if not found.
 */
int getTankPlayer()
{
    for (int i = 1; i <= MaxClients; i++)
    {
        if (!IsClientInGame(i) || !IS_INFECTED(i) || IsFakeClient(i))
            continue;
        
        int zombieClass = GetEntProp(i, Prop_Send, "m_zombieClass");
        
        if (zombieClass == ZOMBIECLASS_TANK)
            return i;
    }

    return -1;
}

/**
 * Retrieves a player's client index by their steam id.
 * 
 * @param steamId
 *     The steam id string to look for.
 * 
 * @return
 *     The player's client index or -1 if not found.
 */
int getInfectedPlayerBySteamId(const char[] steamId) 
{
    char tmpSteamId[64];
   
    for (int i = 1; i <= MaxClients; i++) 
    {
        if (!IS_VALID_INFECTED(i))
            continue;

        GetClientAuthId(i, AuthId_Steam2, tmpSteamId, sizeof(tmpSteamId));
        
        if (StrEqual(steamId, tmpSteamId))
            return i;
    }
    
    return -1;
}

void SetTankFrustration(int iTankClient, int iFrustration) 
{
    if (iFrustration >= 0 && iFrustration <= 100)
        SetEntProp(iTankClient, Prop_Send, "m_frustration", 100-iFrustration);
}

int GetTankFrustration(int iTankClient) 
{
    return 100 - GetEntProp(iTankClient, Prop_Send, "m_frustration");
}

CountdownTimer GetFrustrationTimer(int client)
{
    static int s_iOffs_m_frustrationTimer = -1;

    if (s_iOffs_m_frustrationTimer == -1)
        s_iOffs_m_frustrationTimer = FindSendPropInfo("CTerrorPlayer", "m_frustration") + 4;
    
    return view_as<CountdownTimer>(GetEntityAddress(client) + view_as<Address>(s_iOffs_m_frustrationTimer));
}

int PeekNextTankIndexInTheQueue()
{
    if (h_tankQueue.Length == 0)
        return -1;

    char steamId[64];

    for (int i = 0; i < h_tankQueue.Length; i++)
    {
        h_tankQueue.GetString(i, steamId, sizeof(steamId));

        int client = getInfectedPlayerBySteamId(steamId);
        if (client != -1)
            return i;
    }

    return -1;
}

void EnqueueNewInfectedPlayers()
{
    char steamId[64];

    int start = h_tankQueue.Length;
    int end = -1;

    for (int client = 1; client <= MaxClients; client++)
    {
        if (!IsClientInGame(client) || IsFakeClient(client) || GetClientTeam(client) != TEAM_INFECTED)
            continue;
        
        GetClientAuthId(client, AuthId_Steam2, steamId, sizeof(steamId));

        if (h_tankQueue.FindString(steamId) != -1 || h_whosHadTank.FindString(steamId) != -1)
            continue;

        h_tankQueue.PushString(steamId);

        end = h_tankQueue.Length - 1;
    }

    if (end != -1)
        ShuffleArray(h_tankQueue, start, end);
}

void RemoveAllInfectedFrom(ArrayList arrayList)
{
    char steamId[64];

    for (int client = 1; client <= MaxClients; client++)
    {
        if (!IsClientInGame(client) || IsFakeClient(client) || GetClientTeam(client) != TEAM_INFECTED)
            continue;
        
        GetClientAuthId(client, AuthId_Steam2, steamId, sizeof(steamId));

        int index = arrayList.FindString(steamId);
        if (index != -1)
            arrayList.Erase(index);
    }
}

void ShuffleArray(ArrayList arrayList, int start, int end)
{
    if (start == end)
        return;

    int swaps = (end - start + 1) * 2;

    for (int i = 0; i < swaps; i++)
    {
        int index1 = GetRandomInt(start, end);
        int index2 = GetRandomInt(start, end);

        if (index1 == index2)
            continue;

        arrayList.SwapAt(index1, index2);
    }
}

void AddTeamSteamIdsToArray(ArrayList steamIds, int team)
{
    char steamId[64];
   
    for (int i = 1; i <= MaxClients; i++)
    {
        if (IsClientInGame(i) && !IsFakeClient(i) && GetClientTeam(i) == team)
        {
            GetClientAuthId(i, AuthId_Steam2, steamId, sizeof(steamId));
            steamIds.PushString(steamId);
        }
    }
}

void RemoveSteamIdsFromArray(ArrayList steamIds, ArrayList steamIdsToRemove)
{
    int index;
    char steamId[64];
   
    for (int i = 0; i < steamIdsToRemove.Length; i++)
    {
        steamIdsToRemove.GetString(i, steamId, sizeof(steamId));
        index = steamIds.FindString(steamId);
       
        if (index != -1)
        {
            steamIds.Erase(index);
        }
    }
}

void TriggerQueueChanged()
{
    Call_StartForward(g_hForwardOnQueueChanged);
    Call_Finish();
}

/**
 * Check if the translation file exists
 *
 * @param translation	Translation name.
 * @noreturn
 */
stock void LoadTranslation(const char[] translation)
{
	char
		sPath[PLATFORM_MAX_PATH],
		sName[64];

	Format(sName, sizeof(sName), "translations/%s.txt", translation);
	BuildPath(Path_SM, sPath, sizeof(sPath), sName);
	if (!FileExists(sPath))
		SetFailState("Missing translation file %s.txt", translation);

	LoadTranslations(translation);
}

public int Native_GetWhosHadTank(Handle plugin, int numParams)
{
    return view_as<int>(CloneHandle(h_whosHadTank, plugin));
}

public int Native_GetWhosNotHadTank(Handle plugin, int numParams)
{
    ArrayList infectedPool = new ArrayList(ByteCountToCells(64));
    AddTeamSteamIdsToArray(infectedPool, TEAM_INFECTED);
   
    // Remove players who've already had tank from the pool
    RemoveSteamIdsFromArray(infectedPool, h_whosHadTank);
   
    return view_as<int>(CloneHandle(infectedPool, plugin));
}

public int Native_GetTankPool(Handle plugin, int numParams)
{
    ArrayList infectedPool = new ArrayList(ByteCountToCells(64));
    AddTeamSteamIdsToArray(infectedPool, TEAM_INFECTED);
   
    // Remove players who've already had tank from the pool
    RemoveSteamIdsFromArray(infectedPool, h_whosHadTank);
   
    // If the infected pool is empty, reset pool of players
    if (infectedPool.Length == 0)
    {
        AddTeamSteamIdsToArray(infectedPool, TEAM_INFECTED);
    }
   
    return view_as<int>(CloneHandle(infectedPool, plugin));
}

public int Native_ClearWhosHadTank(Handle plugin, int numParams)
{
    h_whosHadTank.Clear();
    return 1;
}

public int Native_SetTank(Handle plugin, int numParams)
{
    char steamId[64];
    GetNativeString(1, steamId, sizeof(steamId));
   
    int client = getInfectedPlayerBySteamId(steamId);
    if (client == -1 || !IS_VALID_INFECTED(client))
        return false;
       
    strcopy(queuedTankSteamId, sizeof(queuedTankSteamId), steamId);
   
    if (g_bRoundStarted)
        outputTankToAll(0);
       
    return true;
}

public int Native_GetTankQueue(Handle plugin, int numParams)
{
    return view_as<int>(CloneHandle(h_tankQueue, plugin));
}

public int Native_AddToTankQueue(Handle plugin, int numParams)
{
    char steamId[64];
    GetNativeString(1, steamId, sizeof(steamId));
    int position = GetNativeCell(2);
   
    if (h_tankQueue.FindString(steamId) != -1)
        return false;
       
    if (position <= 0)
        h_tankQueue.PushString(steamId);
    else
    {
        if (position > h_tankQueue.Length)
            position = h_tankQueue.Length;
        h_tankQueue.ShiftUp(position - 1);
        h_tankQueue.SetString(position - 1, steamId);
    }
   
    Call_StartForward(g_hForwardOnQueueChanged);
    Call_Finish();
    return true;
}

public int Native_RemoveFromTankQueue(Handle plugin, int numParams)
{
    char steamId[64];
    GetNativeString(1, steamId, sizeof(steamId));
   
    int index = h_tankQueue.FindString(steamId);
    if (index == -1)
        return false;
       
    h_tankQueue.Erase(index);
    Call_StartForward(g_hForwardOnQueueChanged);
    Call_Finish();
    return true;
}

public int Native_GetTankPassedCount(Handle plugin, int numParams)
{
    int client = GetNativeCell(1);
    if (IsFakeClient(client)) return 0;
    return g_iTankControlPass[client];
}

void CleanTankQueue()
{
    ArrayList validPlayers = new ArrayList(ByteCountToCells(64));
    char steamId[64];

    for (int i = 1; i <= MaxClients; i++)
    {
        if (!IsClientInGame(i) || IsFakeClient(i) || GetClientTeam(i) != TEAM_INFECTED)
            continue;

        GetClientAuthId(i, AuthId_Steam2, steamId, sizeof(steamId));
        validPlayers.PushString(steamId);
    }

    for (int i = h_tankQueue.Length - 1; i >= 0; i--)
    {
        h_tankQueue.GetString(i, steamId, sizeof(steamId));
        if (validPlayers.FindString(steamId) == -1)
        {
            h_tankQueue.Erase(i);
        }
    }

    delete validPlayers;
    
    TriggerQueueChanged();
}