#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <colors>
#include <left4dhooks>

#undef REQUIRE_PLUGIN
#include <confogl>

#define PLUGIN_VERSION "1.5.2"

public Plugin myinfo = 
{
    name = "[L4D & 2] Score Difference",
    author = "Forgetest, vikingo12, Hana",
    description = "Shows score difference between teams after each round",
    version = PLUGIN_VERSION,
    url = "https://github.com/Target5150/MoYu_Server_Stupid_Plugins"
};

#define ABS(%0) (((%0) < 0) ? -(%0) : (%0))

float g_flDelay;
bool g_bLeft4Dead2;
char g_sNextMap[64];
int g_iMapDistance, g_iNextMapDistance;
bool g_bMapStarted = false;

#define TRANSLATION_FILE "l4d2_score_difference.phrases"
void LoadPluginTranslations()
{
    char sPath[PLATFORM_MAX_PATH];
    BuildPath(Path_SM, sPath, sizeof(sPath), "translations/"...TRANSLATION_FILE...".txt");
    if (!FileExists(sPath))
    {
        SetFailState("Missing translation \""...TRANSLATION_FILE..."\"");
    }
    LoadTranslations(TRANSLATION_FILE);
}

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
    switch (GetEngineVersion())
    {
        case Engine_Left4Dead: g_bLeft4Dead2 = false;
        case Engine_Left4Dead2: g_bLeft4Dead2 = true;
        default:
        {
            strcopy(error, err_max, "Plugin supports L4D & 2 only");
            return APLRes_SilentFailure;
        }
    }
    return APLRes_Success;
}

public void OnPluginStart()
{
    LoadPluginTranslations();
    
    ConVar cv = CreateConVar("l4d2_scorediff_print_delay", "5.0", "Delay in printing score difference.", FCVAR_SPONLY|FCVAR_NOTIFY, true, 0.0);
    OnConVarChanged(cv, "", "");
    cv.AddChangeHook(OnConVarChanged);
}

void OnConVarChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
    g_flDelay = convar.FloatValue;
}

public void OnMapStart()
{
    g_bMapStarted = true;
    CreateTimer(0.1, Timer_SetMapDistance, _, TIMER_FLAG_NO_MAPCHANGE);
}

Action Timer_SetMapDistance(Handle timer)
{
    g_iMapDistance = L4D_GetVersusMaxCompletionScore();
    UpdateNextMapInfo();
    return Plugin_Stop;
}

public void OnMapEnd()
{
    g_bMapStarted = false;
    g_iNextMapDistance = 0;
    g_sNextMap[0] = '\0';
}

public void L4D_OnFirstSurvivorLeftSafeArea_Post(int client)
{   
    if (g_iNextMapDistance == 0)
    {
        UpdateNextMapInfo();
    }
}

void UpdateNextMapInfo()
{
    if (!g_bLeft4Dead2 || L4D_IsMissionFinalMap())
        return;

    char nextMapName[64];
    GetNextMapName(nextMapName, sizeof(nextMapName));
    
    if (nextMapName[0] != '\0')
    {
        if (LGO_IsMatchModeLoaded() && LGO_IsMapDataAvailable())
        {
            char buffer[PLATFORM_MAX_PATH];
            LGO_BuildConfigPath(buffer, sizeof(buffer), "mapinfo.txt");
            
            KeyValues kv = new KeyValues("MapInfo");
            if (kv.ImportFromFile(buffer))
            {
                if (kv.JumpToKey(nextMapName))
                {
                    g_iNextMapDistance = kv.GetNum("map_distance", 0);
                }
            }
            delete kv;
        }
        
        if (g_iNextMapDistance == 0 && g_bMapStarted)
        {
            g_iNextMapDistance = L4D_GetVersusMaxCompletionScore();
        }
    }
}

void GetNextMapName(char[] buffer, int maxlength)
{
    char mapName[64];
    GetCurrentMap(mapName, sizeof(mapName));
    
    char path[PLATFORM_MAX_PATH];
    BuildPath(Path_SM, path, sizeof(path), "configs/mapcycle.txt");
    
    File file = OpenFile(path, "r");
    if (file != null)
    {
        char line[64];
        bool foundCurrent = false;
        
        while (!file.EndOfFile() && file.ReadLine(line, sizeof(line)))
        {
            TrimString(line);
            if (line[0] == '\0' || line[0] == ';' || line[0] == '/')
                continue;
                
            if (foundCurrent)
            {
                strcopy(buffer, maxlength, line);
                delete file;
                return;
            }
            
            if (StrEqual(line, mapName, false))
            {
                foundCurrent = true;
            }
        }
        delete file;
    }
    
    buffer[0] = '\0';
}

public void L4D2_OnEndVersusModeRound_Post()
{
    if (InSecondHalfOfRound())
    {
        if (g_flDelay >= 0.1)
            CreateTimer(g_flDelay, Timer_PrintDifference, _, TIMER_FLAG_NO_MAPCHANGE);
        else
            Timer_PrintDifference(null);
    }
    else
    {
        if (g_flDelay >= 0.1)
            CreateTimer(g_flDelay, Timer_PrintComeback, _, TIMER_FLAG_NO_MAPCHANGE);
        else
            Timer_PrintComeback(null);
    }
}

Action Timer_PrintComeback(Handle timer)
{
    int iSurvCampaignScore = GetCampaignScore(L4D2_TeamNumberToTeamIndex(2));
    int iInfCampaignScore = GetCampaignScore(L4D2_TeamNumberToTeamIndex(3));
    
    int iTotalDifference = ABS(iSurvCampaignScore - iInfCampaignScore);
    
    if (TranslationPhraseExists("Announce_Survivor"))
        CPrintToChatAll("%t", "Announce_Survivor", iSurvCampaignScore);
    
    if (TranslationPhraseExists("Announce_Infected"))
        CPrintToChatAll("%t", "Announce_Infected", iInfCampaignScore);
    
    if (g_bLeft4Dead2)
    {
        if (iTotalDifference <= g_iMapDistance)
        {
            if (TranslationPhraseExists("Announce_ComebackWithDistance"))
                CPrintToChatAll("%t", "Announce_ComebackWithDistance", iTotalDifference);
        }
        else
        {
            if (TranslationPhraseExists("Announce_ComebackWithBonus"))
                CPrintToChatAll("%t", "Announce_ComebackWithBonus", g_iMapDistance, iTotalDifference - g_iMapDistance);
        }
    }
    else
    {
        if (TranslationPhraseExists("Announce_ComebackWithBonus_L4D1"))
            CPrintToChatAll("%t", "Announce_ComebackWithBonus_L4D1", iTotalDifference);
    }
    
    return Plugin_Stop;
}

Action Timer_PrintDifference(Handle timer)
{
    int iSurvRoundScore = GetChapterScore(L4D2_TeamNumberToTeamIndex(2));
    int iInfRoundScore = GetChapterScore(L4D2_TeamNumberToTeamIndex(3));
    int iSurvCampaignScore = GetCampaignScore(L4D2_TeamNumberToTeamIndex(2));
    int iInfCampaignScore = GetCampaignScore(L4D2_TeamNumberToTeamIndex(3));
    
    int iRoundDifference = ABS(iSurvRoundScore - iInfRoundScore);
    int iTotalDifference = ABS(iSurvCampaignScore - iInfCampaignScore);
    
    if (iRoundDifference != iTotalDifference) 
    {
        CPrintToChatAll("%t", "Announce_Chapter", iRoundDifference);
        CPrintToChatAll("%t", "Announce_Total", iTotalDifference);
    }
    else 
    {
        CPrintToChatAll("%t", "Announce_ElseChapter", iRoundDifference);
    }
    
    if (TranslationPhraseExists("Announce_Survivor"))
        CPrintToChatAll("%t", "Announce_Survivor", iSurvCampaignScore);
    
    if (TranslationPhraseExists("Announce_Infected"))
        CPrintToChatAll("%t", "Announce_Infected", iInfCampaignScore);
    
    if (g_bLeft4Dead2)
    {
        if (!L4D_IsMissionFinalMap() && g_iNextMapDistance > 0)
        {
            if (iTotalDifference <= g_iNextMapDistance)
            {
                if (TranslationPhraseExists("Announce_ComebackWithDistance"))
                    CPrintToChatAll("%t", "Announce_ComebackWithDistance", iTotalDifference);
            }
            else
            {
                if (TranslationPhraseExists("Announce_ComebackWithBonus"))
                    CPrintToChatAll("%t", "Announce_ComebackWithBonus", g_iNextMapDistance, iTotalDifference - g_iNextMapDistance);
            }
        }
    }
    else
    {
        if (TranslationPhraseExists("Announce_ComebackWithBonus_L4D1"))
            CPrintToChatAll("%t", "Announce_ComebackWithBonus_L4D1", iTotalDifference);
    }
    
    return Plugin_Stop;
}

int GetChapterScore(int team)
{
    if (!g_bLeft4Dead2)
    {
        switch (team)
        {
        case 0:
            {
                return GameRules_GetProp("m_iVersusMapScoreTeam1", _, L4D_GetCurrentChapter() - 1);
            }
        case 1:
            {
                return GameRules_GetProp("m_iVersusMapScoreTeam2", _, L4D_GetCurrentChapter() - 1);
            }
        }
    }
    
    return GameRules_GetProp("m_iChapterScore", _, team);
}

int GetCampaignScore(int team)
{
    return GameRules_GetProp("m_iCampaignScore", _, team);
}

int InSecondHalfOfRound()
{
    return GameRules_GetProp("m_bInSecondHalfOfRound");
}

stock int L4D2_TeamNumberToTeamIndex(int team)
{
    return (team - 2) ^ GameRules_GetProp("m_bAreTeamsFlipped");
}