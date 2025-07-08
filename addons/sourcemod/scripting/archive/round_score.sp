
#pragma semicolon               1
#pragma newdecls                required

#include <sourcemod>
#include <sdkhooks>
#include <colors>


public Plugin myinfo = {
    name = "RoundScore",
    author = "TouchMe",
    description = "The plugin displays the results of the survivor team in chat",
    version = "build_0004",
    url = "https://github.com/TouchMe-Inc/l4d2_round_score"
};


/*
 *
 */
#define WORLD_INDEX            0

/*
 * Infected Class.
 */
#define SI_CLASS_TANK           8

#define SHORT_NAME_LENGTH      18

#define TRANSLATIONS            "round_score.phrases"

/*
 * Team.
 */
#define TEAM_SURVIVOR           2
#define TEAM_INFECTED           3


/**
 * Entity-Relationship: UserVector(Userid, ...)
 */
methodmap UserVector < ArrayList {
    public UserVector(int iBlockSize = 1) {
        return view_as<UserVector>(new ArrayList(iBlockSize + 1, 0)); // extended by 1 cell for userid field
    }

    public any Get(int iIdx, int iType) {
        return GetArrayCell(this, iIdx, iType + 1);
    }

    public void Set(int iIdx, any val, int iType) {
        SetArrayCell(this, iIdx, val, iType + 1);
    }

    public int User(int iIdx) {
        return GetArrayCell(this, iIdx, 0);
    }

    public int Push(any val) {
        int iBlockSize = this.BlockSize;

        any[] array = new any[iBlockSize];
        array[0] = val;
        for (int i = 1; i < iBlockSize; i++) {
            array[i] = 0;
        }

        return this.PushArray(array);
    }

    public bool UserIndex(int iUserId, int &iIdx, bool bCreate = false) {
        if (this == null)
            return false;

        iIdx = this.FindValue(iUserId, 0);
        if (iIdx == -1) {
            if (!bCreate)
                return false;

            iIdx = this.Push(iUserId);
        }

        return true;
    }

    public bool UserReplace(int iUserId, int replacer) {
        int iIdx;
        if (!this.UserIndex(iUserId, iIdx, false))
            return false;

        SetArrayCell(this, iIdx, replacer, 0);
        return true;
    }

    public bool UserGet(int iUserId, int iType, any &val) {
        int iIdx;
        if (!this.UserIndex(iUserId, iIdx, false))
            return false;

        val = this.Get(iIdx, iType);
        return true;
    }

    public bool UserSet(int iUserId, int iType, any val, bool bCreate = false) {
        int iIdx;
        if (!this.UserIndex(iUserId, iIdx, bCreate))
            return false;

        this.Set(iIdx, val, iType);
        return true;
    }

    public bool UserAdd(int iUserId, int iType, any amount, bool bCreate = false) {
        int iIdx;
        if (!this.UserIndex(iUserId, iIdx, bCreate))
            return false;

        int val = this.Get(iIdx, iType);
        this.Set(iIdx, val + amount, iType);
        return true;
    }
}

enum {
    eKillSpecial,
    eKillCommon,
    eSpecialDamage,
    eFriendlyFire,
    eRoundScoreSize
};

UserVector g_aRoundScore;
StringMap  g_smUserNames;

int g_iLastHealth[MAXPLAYERS + 1] = { 0, ... };

bool g_bRoundIsLive = false;


/**
 * Called before OnPluginStart.
 *
 * @param myself      Handle to the plugin
 * @param bLate       Whether or not the plugin was loaded "late" (after map load)
 * @param sErr        Error message buffer in case load failed
 * @param iErrLen     Maximum number of characters for error message buffer
 * @return            APLRes_Success | APLRes_SilentFailure
 */
public APLRes AskPluginLoad2(Handle myself, bool bLate, char[] sErr, int iErrLen)
{
    if (GetEngineVersion() != Engine_Left4Dead2)
    {
        strcopy(sErr, iErrLen, "Plugin only supports Left 4 Dead 2.");
        return APLRes_SilentFailure;
    }

    return APLRes_Success;
}

/**
  * Called when the map starts loading.
  */
public void OnMapStart() {
    g_bRoundIsLive = false;
}

public void OnPluginStart()
{
    LoadTranslations(TRANSLATIONS);

    // Events.
    HookEvent("player_left_start_area", Event_PlayerLeftStartArea, EventHookMode_PostNoCopy);
    HookEvent("round_end", Event_RoundEnd, EventHookMode_PostNoCopy);
    HookEvent("player_spawn", Event_PlayerSpawn, EventHookMode_Post);
    HookEvent("player_hurt", Event_PlayerHurt, EventHookMode_Post);
    HookEvent("player_death", Event_PlayerDeath, EventHookMode_Post);
    HookEvent("infected_death", Event_InfectedDeath, EventHookMode_Post);

    // Player Commands.
    RegConsoleCmd("sm_score", Cmd_Score);
    RegConsoleCmd("sm_mvp", Cmd_Score);

    g_aRoundScore   = new UserVector(eRoundScoreSize);
    g_smUserNames = new StringMap();
}

public void OnClientDisconnect(int iClient)
{
    int iUserId = GetClientUserId(iClient);

    char szKey[16];
    IntToString(iUserId, szKey, sizeof(szKey));

    char szClientName[MAX_NAME_LENGTH];
    GetClientNameFixed(iClient, szClientName, sizeof(szClientName), SHORT_NAME_LENGTH);
    g_smUserNames.SetString(szKey, szClientName);
}

/**
 * Round start event.
 */
void Event_PlayerLeftStartArea(Event event, const char[] sName, bool bDontBroadcast)
{
    g_aRoundScore.Clear();
    g_smUserNames.Clear();

    g_bRoundIsLive = true;
}

/**
 * Round end event.
 */
void Event_RoundEnd(Event event, const char[] sName, bool bDontBroadcast)
{
    if (g_bRoundIsLive)
    {
        for (int iClient = 1; iClient <= MaxClients; iClient ++)
        {
            if (!IsClientInGame(iClient) || IsFakeClient(iClient)) {
                continue;
            }

            PrintToChatScore(iClient);
        }
    }

    g_bRoundIsLive = false;
}

void Event_PlayerSpawn(Event event, char[] sEventName, bool bDontBroadcast)
{
    int iClient = GetClientOfUserId(GetEventInt(event, "userid"));

    if (iClient <= 0 || !IsClientInfected(iClient)) {
        return;
    }

    g_iLastHealth[iClient] = GetClientHealth(iClient);
}

/**
 * Registers existing/caused damage.
 */
void Event_PlayerHurt(Event event, char[] sEventName, bool bDontBroadcast)
{
    int iAttackerId = GetEventInt(event, "attacker");
    int iAttacker   = GetClientOfUserId(iAttackerId);

    if (iAttacker <= 0 || !IsClientSurvivor(iAttacker)) {
        return;
    }

    int iVictim = GetClientOfUserId(GetEventInt(event, "userid"));

    if (iVictim <= 0 || (IsClientInfected(iVictim) && IsClientTank(iVictim))) {
        return;
    }

    int iDamage = GetEventInt(event, "dmg_health");

    if (IsClientSurvivor(iVictim))
    {
        g_aRoundScore.UserAdd(iAttackerId, eFriendlyFire, iDamage, true);
        return;
    }

    int iRemainingHealth = GetEventInt(event, "health");

    if (iRemainingHealth <= 0) {
        return;
    }

    g_iLastHealth[iVictim] = iRemainingHealth;

    g_aRoundScore.UserAdd(iAttackerId, eSpecialDamage, iDamage, true);
}

/**
 * Registers murder.
 */
void Event_PlayerDeath(Event event, const char[] name, bool bDontBroadcast)
{
    int iAttackerId = GetEventInt(event, "attacker");
    int iAttacker   = GetClientOfUserId(iAttackerId);

    if (iAttacker <= 0 || !IsClientSurvivor(iAttacker)) {
        return;
    }

    int iVictim = GetClientOfUserId(GetEventInt(event, "userid"));

    if (iVictim <= 0 || !IsClientInfected(iVictim) || IsClientTank(iVictim)) {
        return;
    }

    if (g_iLastHealth[iVictim] > 0)
    {
        g_aRoundScore.UserAdd(iAttackerId, eSpecialDamage, g_iLastHealth[iVictim], true);
        g_iLastHealth[iVictim] = 0;
    }

    g_aRoundScore.UserAdd(iAttackerId, eKillSpecial, 1, true);
}

/**
 * Surivivor Killed Common Infected.
 */
void Event_InfectedDeath(Event event, char[] sEventName, bool bDontBroadcast)
{
    int iAttackerId = GetEventInt(event, "attacker");
    int iAttacker   = GetClientOfUserId(iAttackerId);

    if (iAttacker <= 0 || !IsClientInGame(iAttacker) || !IsClientSurvivor(iAttacker)) {
        return;
    }

    g_aRoundScore.UserAdd(iAttackerId, eKillCommon, 1, true);
}

Action Cmd_Score(int iClient, int iArgs)
{
    if (!iClient) {
        return Plugin_Continue;
    }

    if (!g_bRoundIsLive)
    {
        CPrintToChat(iClient, "%T%T", "TAG", iClient, "ROUND_NOT_LIVE", iClient);
        return Plugin_Handled;
    }

    PrintToChatScore(iClient);

    return Plugin_Handled;
}

void PrintToChatScore(int iClient)
{
    int iLength = g_aRoundScore.Length;
    if (!iLength) {
        return;
    }

    g_aRoundScore.SortCustom(SortAdtDamageDesc);

    CPrintToChat(iClient, "%T%T", "BRACKET_START", iClient, "TAG", iClient);

    int iTotalDamage = 0;
    for (int iAttacker = 0; iAttacker < iLength; iAttacker++)
    {
        iTotalDamage += g_aRoundScore.Get(iAttacker, eSpecialDamage);
    }

    int iTemp = 0, iTotalDamagePct = 0;
    int iKillSpecialMaxDigits = 0,  iSpecialDamageMaxDigits = 0, iKillCommonMaxDigits = 0, iFriendlyFireMaxDigits = 0;
    for (int iAttacker = 0; iAttacker < iLength; iAttacker++)
    {
        if (iKillSpecialMaxDigits < (iTemp = GetNumberOfDigits(g_aRoundScore.Get(iAttacker, eKillSpecial)))) iKillSpecialMaxDigits = iTemp;
        if (iSpecialDamageMaxDigits < (iTemp = GetNumberOfDigits(g_aRoundScore.Get(iAttacker, eSpecialDamage)))) iSpecialDamageMaxDigits = iTemp;
        if (iKillCommonMaxDigits < (iTemp = GetNumberOfDigits(g_aRoundScore.Get(iAttacker, eKillCommon)))) iKillCommonMaxDigits = iTemp;
        if (iFriendlyFireMaxDigits < (iTemp = GetNumberOfDigits(g_aRoundScore.Get(iAttacker, eFriendlyFire)))) iFriendlyFireMaxDigits = iTemp;

        iTotalDamagePct += GetDamageAsPercent(g_aRoundScore.Get(iAttacker, eSpecialDamage), iTotalDamage);
    }

    int iPctAdjustment = 0;
    if ((iTotalDamagePct < 100) && float(iTotalDamage) > (iTotalDamage - (iTotalDamage / 200))) {
        iPctAdjustment = 100 - iTotalDamagePct;
    }

    char szKillSpecialSpace[8], szSpecialDamageSpace[8], szSpecialDamagePctSpace[8], szKillCommonSpace[8], szFriendlyFireSpace[8];
    char szClientName[MAX_NAME_LENGTH];
    int iKillSpecial, iSpecialDamage, iSpecialDamagePct, iKillCommon, iFriendlyFire;
    for (int iAttacker = 0; iAttacker < iLength; iAttacker++)
    {
        // generally needed
        GetClientNameFromUserId(g_aRoundScore.User(iAttacker), szClientName, sizeof(szClientName));

        iKillSpecial = g_aRoundScore.Get(iAttacker, eKillSpecial);
        iSpecialDamage = g_aRoundScore.Get(iAttacker, eSpecialDamage);
        iSpecialDamagePct = GetDamageAsPercent(iSpecialDamage, iTotalDamage);
        iKillCommon = g_aRoundScore.Get(iAttacker, eKillCommon);
        iFriendlyFire = g_aRoundScore.Get(iAttacker, eFriendlyFire);

        if (iPctAdjustment != 0 && iSpecialDamage > 0 && !IsExactPercent(iSpecialDamage, iTotalDamage))
        {
            int iAdjustedPctDmg = iSpecialDamagePct + iPctAdjustment;

            if (iAdjustedPctDmg <= 100)
            {
                iSpecialDamagePct = iAdjustedPctDmg;
                iPctAdjustment = 0;
            }
        }

        NumberSpace(szKillSpecialSpace, sizeof(szKillSpecialSpace), iKillSpecial, iKillSpecialMaxDigits);
        NumberSpace(szSpecialDamageSpace, sizeof(szSpecialDamageSpace), iSpecialDamage, iSpecialDamageMaxDigits);
        ProcentSpace(szSpecialDamagePctSpace, sizeof(szSpecialDamagePctSpace), iSpecialDamagePct);
        NumberSpace(szKillCommonSpace, sizeof(szKillCommonSpace), iKillCommon, iKillCommonMaxDigits);
        NumberSpace(szFriendlyFireSpace, sizeof(szFriendlyFireSpace), iFriendlyFire, iFriendlyFireMaxDigits);

        CPrintToChat(iClient, "%T%T", (iAttacker + 1) == iLength ? "BRACKET_END" : "BRACKET_MIDDLE", iClient, "SCORE", iClient,
            szKillSpecialSpace, iKillSpecial,
            szSpecialDamageSpace, iSpecialDamage,
            szSpecialDamagePctSpace, iSpecialDamagePct, szSpecialDamagePctSpace,
            szKillCommonSpace, iKillCommon,
            szFriendlyFireSpace, iFriendlyFire,
            szClientName
        );
    }
}

void NumberSpace(char[] szBuffer, int iLength, int iNumber, int iMaxDigits = 3)
{
    int iDigits = GetNumberOfDigits(iNumber);

    int iSpaces = iMaxDigits - iDigits;

    if (iSpaces < 0) {
        iSpaces = 0;
    }

    iSpaces *= 2;

    if (iSpaces > iLength)
    {
        szBuffer[iSpaces] = '\0';
        return;
    }

    for (int i = 0; i < iSpaces; i++) {
        szBuffer[i] = ' ';
    }

    szBuffer[iSpaces] = '\0';
}

void ProcentSpace(char[] szBuffer, int iLength, int iProcent)
{
    FormatEx(szBuffer, iLength, "%s",
        iProcent < 10 ? "  " : iProcent < 100 ? " " : "");
}

bool GetClientNameFromUserId(int iUserId, char[] szClientName, int iMaxLen)
{
    if (iUserId == WORLD_INDEX) {
        FormatEx(szClientName, iMaxLen, "World");
        return true;
    }

    int iClient = GetClientOfUserId(iUserId);
    if (iClient && IsClientInGame(iClient)) {
        return GetClientNameFixed(iClient, szClientName, iMaxLen, SHORT_NAME_LENGTH);
    }

    char szKey[16];
    IntToString(iUserId, szKey, sizeof(szKey));
    return g_smUserNames.GetString(szKey, szClientName, iMaxLen);
}

int SortAdtDamageDesc(int iIdx1, int iIdx2, Handle hArray, Handle hHndl)
{
    UserVector uDamagerVector = view_as<UserVector>(hArray);
    int iDamage1 = uDamagerVector.Get(iIdx1, eSpecialDamage);
    int iDamage2 = uDamagerVector.Get(iIdx2, eSpecialDamage);
    if      (iDamage1 > iDamage2) return -1;
    else if (iDamage1 < iDamage2) return  1;
    return 0;
}

int GetDamageAsPercent(int iDamage, int iTotalDamage)
{
    if (iTotalDamage == 0) {
        return 0;
    }

    return RoundToFloor((float(iDamage) / iTotalDamage) * 100.0);
}

bool IsExactPercent(int iDamage, int iMaxHealth) {
    return (FloatAbs(float(GetDamageAsPercent(iDamage, iMaxHealth)) - ((float(iDamage) / iMaxHealth) * 100.0)) < 0.001) ? true : false;
}

int GetNumberOfDigits(int iNumber)
{
    int iDigits = 0;
    do {
        iNumber /= 10;
        iDigits ++;
    } while (iNumber != 0);
    return iDigits;
}

/**
 *
 */
bool GetClientNameFixed(int iClient, char[] szClientName, int iLength, int iMaxSize)
{
    if (!GetClientName(iClient, szClientName, iLength)) {
        return false;
    }

    if (strlen(szClientName) > iMaxSize)
    {
        szClientName[iMaxSize - 3] = szClientName[iMaxSize - 2] = szClientName[iMaxSize - 1] = '.';
        szClientName[iMaxSize] = '\0';
    }

    return true;
}

/**
 * Infected team player?
 */
bool IsClientInfected(int iClient) {
    return (GetClientTeam(iClient) == TEAM_INFECTED);
}

/**
 * Gets the client L4D1/L4D2 zombie class id.
 *
 * @param iClient    Client index.
 * @return L4D1      1=SMOKER, 2=BOOMER, 3=HUNTER, 4=WITCH, 5=TANK, 6=NOT INFECTED
 * @return L4D2      1=SMOKER, 2=BOOMER, 3=HUNTER, 4=SPITTER, 5=JOCKEY, 6=CHARGER, 7=WITCH, 8=TANK, 9=NOT INFECTED
 */
int GetInfectedClass(int iClient) {
    return GetEntProp(iClient, Prop_Send, "m_zombieClass");
}

/**
 * Survivor team player?
 */
bool IsClientSurvivor(int iClient) {
    return (GetClientTeam(iClient) == TEAM_SURVIVOR);
}

/**
 * @param iClient    Client index.
 * @return           bool
 */
bool IsClientTank(int iClient) {
    return (GetInfectedClass(iClient) == SI_CLASS_TANK);
}
