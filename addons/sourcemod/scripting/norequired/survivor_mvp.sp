/*
* 移除了对treeutil.sp的调用
* 使用mvp命令不显示详细统计
* 回合结算显示详细统计
*/
#pragma semicolon 1
#pragma newdecls required

// 头文件
#include <sourcemod>
#include <sdktools>
#include <left4dhooks>
#include <colors>

#define CVAR_FLAG FCVAR_NOTIFY

enum
{
<<<<<<< HEAD
    TEAM_SPECTATOR = 1,
    TEAM_SURVIVOR,
    TEAM_INFECTED
=======
    name = "Survivor MVP notification",
    author = "Tabun, Artifacial",
    description = "Shows MVP for survivor team at end of round",
    version = "0.3.3",
    url = "https://github.com/alexberriman/l4d2_survivor_mvp"
};


new     Handle:     hPluginEnabled =    INVALID_HANDLE;

new     Handle:     hCountTankDamage =  INVALID_HANDLE;         // whether we're tracking tank damage for MVP-selection
new     Handle:     hCountWitchDamage = INVALID_HANDLE;         // whether we're tracking witch damage for MVP-selection
new     Handle:     hTrackFF =          INVALID_HANDLE;         // whether we're tracking friendly-fire damage (separate stat)
new     Handle:     hBrevityFlags =     INVALID_HANDLE;         // how verbose/brief the output should be:

new     bool:       bCountTankDamage;
new     bool:       bCountWitchDamage;
new     bool:       bTrackFF;
new                 iBrevityFlags;
new     bool:       bRUPLive;

new     String:     sClientName[MAXPLAYERS + 1][64];            // which name is connected to the clientId?

// Basic statistics
new                 iGotKills[MAXPLAYERS + 1];                  // SI kills             track for each client
new                 iGotCommon[MAXPLAYERS + 1];                 // CI kills
new                 iDidDamage[MAXPLAYERS + 1];                 // SI only              these are a bit redundant, but will keep anyway for now
new                 iDidDamageAll[MAXPLAYERS + 1];              // SI + tank + witch
new                 iDidDamageTank[MAXPLAYERS + 1];             // tank only
new                 iDidDamageWitch[MAXPLAYERS + 1];            // witch only
new                 iDidFF[MAXPLAYERS + 1];                     // friendly fire damage

// Detailed statistics
new                 iDidDamageClass[MAXPLAYERS + 1][ZC_TANK + 1];   // si classes
new                 timesPinned[MAXPLAYERS + 1][ZC_TANK + 1];   // times pinned
new                 totalPinned[MAXPLAYERS + 1];                // total times pinned
new                 pillsUsed[MAXPLAYERS + 1];                  // total pills eaten
new                 boomerPops[MAXPLAYERS + 1];                 // total boomer pops
new                 damageReceived[MAXPLAYERS + 1];             // Damage received

// Tank stats
new                tankSpawned = false;                        // When tank is spawned
new                 commonKilledDuringTank[MAXPLAYERS + 1];     // Common killed during the tank
new                 ttlCommonKilledDuringTank = 0;              // Common killed during the tank
new                 siDmgDuringTank[MAXPLAYERS + 1];            // SI killed during the tank
//new                 ttlSiDmgDuringTank = 0;                     // Total SI killed during the tank
new                tankThrow;                                  // Whether or not the tank has thrown a rock
new                 rocksEaten[MAXPLAYERS + 1];                 // The amount of rocks a player 'ate'.
new                 rockIndex;                                  // The index of the rock (to detect how many times we were rocked)
new                 ttlPinnedDuringTank[MAXPLAYERS + 1];        // The total times we were pinned when the tank was up


new                 iTotalKills;                                // prolly more efficient to store than to recalculate
new                 iTotalCommon;
//new                 iTotalDamage;
//new                 iTotalDamageTank;
//new                 iTotalDamageWitch;
new                 iTotalDamageAll;
new                 iTotalFF;

new                 iRoundNumber;
new                 bInRound;
new                 bPlayerLeftStartArea;                       // used for tracking FF when RUP enabled

//stock char sTmpString[MAX_NAME_LENGTH];                // just used because I'm not going to break my head over why string assignment parameter passing doesn't work

/*
*      Natives
*      =======
*/

public APLRes:AskPluginLoad2(Handle:myself, bool:late, String:error[], err_max)
{
    CreateNative("SURVMVP_GetMVP", Native_GetMVP);
    CreateNative("SURVMVP_GetMVPDmgCount", Native_GetMVPDmgCount);
    CreateNative("SURVMVP_GetMVPKills", Native_GetMVPKills);
    CreateNative("SURVMVP_GetMVPDmgPercent", Native_GetMVPDmgPercent);
    CreateNative("SURVMVP_GetMVPCI", Native_GetMVPCI);
    CreateNative("SURVMVP_GetMVPCIKills", Native_GetMVPCIKills);
    CreateNative("SURVMVP_GetMVPCIPercent", Native_GetMVPCIPercent);
    
    return APLRes_Success;
>>>>>>> upstream/master
}

enum
{
    ZC_SMOKER = 1,
    ZC_BOOMER,
    ZC_HUNTER,
    ZC_SPITTER,
    ZC_JOCKEY,
    ZC_CHARGER,
    ZC_WITCH,
    ZC_TANK
}

enum struct PlayerInfo
{
	int totalDamage;
	int siCount;
	int ciCount;
	int ffCount;
	int gotFFCount;
	int headShotCount;
	void init() {
		this.totalDamage = this.siCount = this.ciCount = this.ffCount = this.gotFFCount = this.headShotCount = 0;
	}
}

PlayerInfo playerInfos[MAXPLAYERS + 1];

static int
	failCount;

static bool
	g_bHasPrint;

static char
	mapName[64];


public Plugin myinfo = 
{
	name 			= "Survivor Mvp & Round Status",
	author 			= "夜羽真白, Hana",
	description 	= "生还者 MVP 统计",
	version 		= "2024-11-24",
	url 			= "https://steamcommunity.com/id/saku_ra/"
}

ConVar
	g_hAllowShowMvp,
	g_hWhichTeamToShow,
	g_hAllowShowSi,
	g_hAllowShowCi,
	g_hAllowShowFF,
	g_hAllowShowTotalDmg,
	g_hAllowShowAccuracy,
	g_hAllowShowFailCount,
	g_hAllowShowDetails,
	g_hAllowShowRank;

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max) {
	EngineVersion test = GetEngineVersion();
	if( test != Engine_Left4Dead2 && test != Engine_Left4Dead) {
		strcopy(error, err_max, "Plugin only supports Left 4 Dead 1 & 2.");
		return APLRes_SilentFailure;
	}

	// 注册插件库函数
	RegPluginLibrary("survivor_mvp");

	// 注册 Natives
	CreateNative("GetTotalDamageMvp", Native_GetTotalDamageMvp);
	CreateNative("GetSiMvp", Native_GetSiMvp);
	CreateNative("GetCiMvp", Native_GetCiMvp);
	CreateNative("GetFFMvp", Native_GetFFMvp);
	CreateNative("GetFFReceiveMvp", Native_GetFFReceiveMvp);
	CreateNative("GetMapFailCount", Native_GetMapFailCount);
	CreateNative("GetClientRank", Native_GetClientRank);

	return APLRes_Success;
}

public void OnPluginStart()
{
	g_hAllowShowMvp = CreateConVar("mvp_allow_show", "1", "是否启用插件", CVAR_FLAG, true, 0.0, true, 1.0);

	g_hWhichTeamToShow = CreateConVar("mvp_witch_team_show", "0", "允许给哪个团队显示 MVP 信息 (0: 所有团队, 1: 仅旁观者团队, 2: 仅生还者团队, 3: 仅特感团队)", CVAR_FLAG, true, 0.0, true, 3.0);
	g_hAllowShowSi = CreateConVar("mvp_allow_show_si", "1", "是否允许显示特感击杀信息", CVAR_FLAG, true, 0.0, true, 1.0);
	g_hAllowShowCi = CreateConVar("mvp_allow_show_ci", "1", "是否允许显示丧尸击杀信息", CVAR_FLAG, true, 0.0, true, 1.0);
	g_hAllowShowFF = CreateConVar("mvp_allow_show_ff", "1", "是否允许显示黑枪与被黑信息", CVAR_FLAG, true, 0.0, true, 1.0);
	g_hAllowShowTotalDmg = CreateConVar("mvp_allow_show_damage", "1", "是否允许显示总伤害信息", CVAR_FLAG, true, 0.0, true, 1.0);
	g_hAllowShowAccuracy = CreateConVar("mvp_allow_show_acc", "0", "是否允许显示准确度信息", CVAR_FLAG, true, 0.0, true, 1.0);

	g_hAllowShowFailCount = CreateConVar("mvp_show_fail_count", "0", "是否在团灭时显示团灭次数", CVAR_FLAG, true, 0.0, true, 1.0);
	g_hAllowShowDetails = CreateConVar("mvp_show_details", "1", "是否在过关或团灭时显示各项 MVP 数据 (每项 MVP 数据显示与否与 mvp_allow_show_xx Cvar 挂钩, 本 Cvar 关闭所有单项数据均不会显示)", CVAR_FLAG, true, 0.0, true, 1.0);
	g_hAllowShowRank = CreateConVar("mvp_show_your_rank", "1", "显示各项 MVP 数据时是否允许显示你的排名", CVAR_FLAG, true, 0.0, true, 1.0);

	// HookEvents
	HookEvent("player_death", siDeathHandler);
	HookEvent("infected_death", ciDeathHandler);
	HookEvent("player_hurt", playerHurtHandler);
	HookEvent("round_start", roundStartHandler);
	HookEvent("round_end", roundEndHandler);
	HookEvent("map_transition", roundEndHandler);
	HookEvent("mission_lost", missionLostHandler);
	HookEvent("finale_vehicle_leaving", roundEndHandler);
	// RegConsoleCmd
	RegConsoleCmd("sm_mvp", showMvpHandler);
}

public void OnMapStart()
{
    g_bHasPrint = false;
    char nowMapName[64];
    GetCurrentMap(nowMapName, sizeof(nowMapName));
    if (strlen(mapName) < 1 || strcmp(mapName, nowMapName) != 0) {
        failCount = 0;
        strcopy(mapName, sizeof(mapName), nowMapName);
    }
    clearStuff();
}

public Action showMvpHandler(int client, int args)
{
    if (!g_hAllowShowMvp.BoolValue) {
        ReplyToCommand(client, "[MVP]：当前生还者 MVP 统计数据已禁用");
        return Plugin_Handled;
    }
    if (!IsValidClient(client)) {
        return Plugin_Handled;
    }

    // 检查团队显示权限
    if (GetClientTeam(client) == TEAM_SPECTATOR && (g_hWhichTeamToShow.IntValue != 0 && g_hWhichTeamToShow.IntValue != 1)) {
        CPrintToChat(client, "{blue}[{default}MVP{blue}]: {default}当前生还者 MVP 统计数据不允许向旁观者显示");
        return Plugin_Handled;
    }
    else if (GetClientTeam(client) == TEAM_SURVIVOR && (g_hWhichTeamToShow.IntValue != 0 && g_hWhichTeamToShow.IntValue != 2)) {
        CPrintToChat(client, "{blue}[{default}MVP{blue}]: {default}当前生还者 MVP 统计数据不允许向生还者显示");
        return Plugin_Handled;
    }
    else if (GetClientTeam(client) == TEAM_INFECTED && (g_hWhichTeamToShow.IntValue != 0 && g_hWhichTeamToShow.IntValue != 3)) {
        CPrintToChat(client, "{blue}[{default}MVP{blue}]: {default}当前生还者 MVP 统计数据不允许向感染者显示");
        return Plugin_Handled;
    }

    // 只显示详细统计
    if (g_hAllowShowDetails.BoolValue) {
        printParticularMvp(client);
    }

    return Plugin_Handled;
}

// 击杀特感
public void siDeathHandler(Event event, const char[] name, bool dontBroadcast)
{
	int victim = GetClientOfUserId(event.GetInt("userid")), attacker = GetClientOfUserId(event.GetInt("attacker"));
	if (!IsValidClient(victim) || !IsValidClient(attacker) || GetClientTeam(victim) != TEAM_INFECTED || GetClientTeam(attacker) != TEAM_SURVIVOR) { return; }
	if (GetInfectedClass(victim) < ZC_SMOKER || GetInfectedClass(victim) > ZC_CHARGER) { return; }
	playerInfos[attacker].siCount++;
	if (event.GetBool("headshot")) { playerInfos[attacker].headShotCount++; }
}

// 击杀丧尸
public void ciDeathHandler(Event event, const char[] name, bool dontBroadcast)
{
	int attacker = GetClientOfUserId(event.GetInt("attacker"));
	if (!IsValidSurvivor(attacker)) { return; }
	playerInfos[attacker].ciCount++;
	if (event.GetBool("headshot")) { playerInfos[attacker].headShotCount++; }
}

// 造成伤害
public void playerHurtHandler(Event event, const char[] name, bool dontBroadcast)
{
	int victim = GetClientOfUserId(event.GetInt("userid")), attacker = GetClientOfUserId(event.GetInt("attacker")), damage = event.GetInt("dmg_health");
	if (IsValidSurvivor(attacker) && IsValidSurvivor(victim))
	{
		playerInfos[attacker].ffCount += damage;
		playerInfos[victim].gotFFCount += damage;
	}
	else if (IsValidSurvivor(attacker) && IsValidInfected(victim) && GetInfectedClass(victim) >= ZC_SMOKER && GetInfectedClass(victim) <= ZC_CHARGER) { playerInfos[attacker].totalDamage += damage; }
}

public void OnClientConnected(int client) {
	playerInfos[client].init();
}

public void OnClientDisconnect(int client) {
	playerInfos[client].init();
}

public void roundStartHandler(Event event, const char[] name, bool dontBroadcast)
{
    g_bHasPrint = false;
    char nowMapName[64] = {'\0'};
    GetCurrentMap(nowMapName, sizeof(nowMapName));
    if (strlen(mapName) < 1 || strcmp(mapName, nowMapName) != 0) {
        failCount = 0;
        strcopy(mapName, sizeof(mapName), nowMapName);
    }
    clearStuff();
}

/**
* 团灭 MVP 显示
* @param 
* @return void
**/
public void missionLostHandler(Event event, const char[] name, bool dontBroadcast)
{
    if (g_hAllowShowFailCount.BoolValue) {
        CPrintToChatAll("{blue}[{default}提示{blue}]: {default}这是你们第 {olive}%d {default}次团灭，请继续努力哦 (*･ω< )", ++failCount);
    }

    if (!g_hAllowShowMvp.BoolValue || g_bHasPrint) {
        return;
    }
    
    roundEndPrint();
}

public void roundEndHandler(Event event, const char[] name, bool dontBroadcast)
{
    if (!g_hAllowShowMvp.BoolValue || g_bHasPrint) {
        return;
    }

    roundEndPrint();
}

// 方法
void clearStuff() {
	for (int i = 1; i <= MaxClients; i++) { playerInfos[i].init(); }
}

void roundEndPrint() {
    // 如果已经打印过了，就不再打印
    if (g_bHasPrint) {
        return;
    }
    g_bHasPrint = true;

    // 遍历所有玩家，根据团队显示权限打印信息
    for (int i = 1; i <= MaxClients; i++) {
        if (!IsValidClient(i)) {
            continue;
        }

        // 检查团队显示权限
        switch (g_hWhichTeamToShow.IntValue) {
            case 1: {
                if (GetClientTeam(i) != TEAM_SPECTATOR) {
                    continue;
                }
            }
            case 2: {
                if (GetClientTeam(i) != TEAM_SURVIVOR) {
                    continue;
                }
            }
            case 3: {
                if (GetClientTeam(i) != TEAM_INFECTED) {
                    continue;
                }
            }
        }

        // 打印基础统计
        printMvpStatus(i);
        
        // 如果允许显示详细统计，则打印详细信息
        if (g_hAllowShowDetails.BoolValue) {
            printParticularMvp(i);
        }
    }

    // 清理数据
    clearStuff();
}

/**
* 显示主 MVP 信息 (特感击杀, 丧尸击杀, 总伤害, 黑枪/被黑, 爆头率)
* @param client 需要显示的客户端索引
* @return void
**/
void printMvpStatus(int client)
{
	int i, index = 0;
	int[] players = new int[MaxClients + 1]; 
	for (i = 1; i <= MaxClients; i++) {
		if (!IsValidClient(i) || GetClientTeam(i) != TEAM_SURVIVOR) {
			continue;
		}
		players[index++] = i;
	}
	SortCustom1D(players, index, sortByDamageFunction);

	CPrintToChat(client, "{lightgreen}[生还者 MVP 统计]");

	char buffer[128], toPrint[256];
	for (i = 0; i < index; i++) {
		// 格式化排序后一个玩家的 MVP 信息
		if (g_hAllowShowSi.BoolValue) {
			FormatEx(buffer, sizeof(buffer), "{lightgreen}特感{olive}%d ", playerInfos[players[i]].siCount);
			StrCat(toPrint, sizeof(toPrint), buffer);
		}
		if (g_hAllowShowCi.BoolValue) {
			FormatEx(buffer, sizeof(buffer), "{lightgreen}丧尸{olive}%d ", playerInfos[players[i]].ciCount);
			StrCat(toPrint, sizeof(toPrint), buffer);
		}
		if (g_hAllowShowTotalDmg.BoolValue) {
			FormatEx(buffer, sizeof(buffer), "{lightgreen}伤害{olive}%d ", playerInfos[players[i]].totalDamage);
			StrCat(toPrint, sizeof(toPrint), buffer);
		}
		if (g_hAllowShowFF.BoolValue) {
			FormatEx(buffer, sizeof(buffer), "{lightgreen}黑/被黑{olive}%d/%d ", playerInfos[players[i]].ffCount, playerInfos[players[i]].gotFFCount);
			StrCat(toPrint, sizeof(toPrint), buffer);
		}
		if (g_hAllowShowAccuracy.BoolValue) {
			float accuracy = playerInfos[players[i]].siCount + playerInfos[players[i]].ciCount == 0 ? 0.0 : float(playerInfos[players[i]].headShotCount) / float(playerInfos[players[i]].siCount + playerInfos[players[i]].ciCount);
			FormatEx(buffer, sizeof(buffer), "{lightgreen}爆头率{olive}%.0f%% ", accuracy * 100.0);
			StrCat(toPrint, sizeof(toPrint), buffer);
		}
		FormatEx(buffer, sizeof(buffer), "{lightgreen}%N", players[i]);
		StrCat(toPrint, sizeof(toPrint), buffer);

		// 打印一个玩家的 MVP 信息
		CPrintToChat(client, "%s", toPrint);
		FormatEx(toPrint, sizeof(toPrint), "");
	}
}

/**
* 显示各项 MVP (SI, CI, FF, RANK)
* @param client 需要显示的客户端索引
* @return void
**/
void printParticularMvp(int client) {
	int siMvpClient, ciMvpClient, ffMvpClient, gotFFMvpClient;
	int dmgTotal, siTotal, ciTotal, ffTotal, gotFFTotal;

	int i;
	for (i = 1; i <= MaxClients; i++) {
		// 跳过不是生还者的
		if (!IsValidClient(i) || GetClientTeam(i) != TEAM_SURVIVOR) {
			continue;
		}
		dmgTotal += playerInfos[i].totalDamage;
		siTotal += playerInfos[i].siCount;
		ciTotal += playerInfos[i].ciCount;
		ffTotal += playerInfos[i].ffCount;
		gotFFTotal += playerInfos[i].gotFFCount;

		if (playerInfos[i].totalDamage > playerInfos[siMvpClient].totalDamage) {
			siMvpClient = i;
		}
		if (playerInfos[i].ciCount > playerInfos[ciMvpClient].ciCount) {
			ciMvpClient = i;
		}
		if (playerInfos[i].ffCount > playerInfos[ffMvpClient].ffCount) {
			ffMvpClient = i;
		}
		if (playerInfos[i].gotFFCount > playerInfos[gotFFMvpClient].gotFFCount) {
			gotFFMvpClient = i;
		}
	}

	int dmgPercent, killPercent;
	char clientName[MAX_NAME_LENGTH], buffer[512], temp[256];
	// 允许显示 SI MVP
	if (g_hAllowShowSi.BoolValue) {
		FormatEx(buffer, sizeof(buffer), "{blue}[{default}MVP{blue}] SI: ");
		if (!IsValidClient(siMvpClient) || siTotal <= 0) {
			StrCat(buffer, sizeof(buffer), "{olive}本局还没有击杀任何特感");
		} else {

			formatMvpClientName(siMvpClient, clientName, sizeof(clientName));

			dmgPercent = RoundToNearest(float(playerInfos[siMvpClient].totalDamage) / float(dmgTotal) * 100.0);
			killPercent = RoundToNearest(float(playerInfos[siMvpClient].siCount) / float(siTotal) * 100.0);
			FormatEx(temp, sizeof(temp), "{green}%s {blue}({default}%d {olive}伤害 {blue}[{default}%d%%{blue}]{default}, %d {olive}击杀 {blue}[{default}%d%%{blue}])", clientName, playerInfos[siMvpClient].totalDamage, dmgPercent, playerInfos[siMvpClient].siCount, killPercent);
			StrCat(buffer, sizeof(buffer), temp);
		}
		CPrintToChat(client, "%s", buffer);
	}
	// 允许显示 CI MVP
	if (g_hAllowShowCi.BoolValue) {
		FormatEx(buffer, sizeof(buffer), "{blue}[{default}MVP{blue}] CI: ");
		if (!IsValidClient(ciMvpClient) || ciTotal <= 0) {
			StrCat(buffer, sizeof(buffer), "{olive}本局还没有击杀任何丧尸");
		} else {

			formatMvpClientName(ciMvpClient, clientName, sizeof(clientName));

			killPercent = RoundToNearest(float(playerInfos[ciMvpClient].ciCount) / float(ciTotal) * 100.0);
			FormatEx(temp, sizeof(temp), "{green}%s {blue}({default}%d {olive}丧尸 {blue}[{default}%d%%{blue}])", clientName, playerInfos[ciMvpClient].ciCount, killPercent);
			StrCat(buffer, sizeof(buffer), temp);
		}
		CPrintToChat(client, "%s", buffer);
	}
	// 允许显示 FF MVP
	if (g_hAllowShowFF.BoolValue) {
		FormatEx(buffer, sizeof(buffer), "{blue}[{default}LVP{blue}] FF: ");
		if (!IsValidClient(ffMvpClient) || ffTotal <= 0) {
			StrCat(buffer, sizeof(buffer), "{olive}大家都没有黑枪");
		} else {

			formatMvpClientName(ffMvpClient, clientName, sizeof(clientName));

			killPercent = RoundToNearest(float(playerInfos[ffMvpClient].ffCount) / float(ffTotal) * 100.0);
			FormatEx(temp, sizeof(temp), "{green}%s {blue}({default}%d {olive}友伤 {blue}[{default}%d%%{blue}])", clientName, playerInfos[ffMvpClient].ffCount, killPercent);
			StrCat(buffer, sizeof(buffer), temp);
		}
		CPrintToChat(client, "%s", buffer);

		// 被黑 MVP
		FormatEx(buffer, sizeof(buffer), "{blue}[{default}MVP{blue}] FF Receive: ");
		if (!IsValidClient(gotFFMvpClient) || gotFFTotal <= 0) {
			StrCat(buffer, sizeof(buffer), "{olive}没有黑枪捏");
		} else {

			formatMvpClientName(gotFFMvpClient, clientName, sizeof(clientName));

			killPercent = RoundToNearest(float(playerInfos[gotFFMvpClient].gotFFCount) / float(gotFFTotal) * 100.0);
			FormatEx(temp, sizeof(temp), "{green}%s {blue}({default}%d {olive}被黑 {blue}[{default}%d%%{blue}])", clientName, playerInfos[gotFFMvpClient].gotFFCount, killPercent);
			StrCat(buffer, sizeof(buffer), temp);
		}
		CPrintToChat(client, "%s", buffer);
	}
	// 允许显示你的排名
	if (g_hAllowShowRank.BoolValue) {
		// 不是生还者, 不显示排名
		if (!IsValidClient(client) || GetClientTeam(client) != TEAM_SURVIVOR) {
			return;
		}
		// 你是 SI MVP, 则显示你的 CI 排名, 你是 SI, CI MVP 霸榜了, 除非你想显示你的 FF 排名, 则不显示你的排名
		if (client == siMvpClient && client == ciMvpClient) {
			return;
		}

		// 开始排名
		int index = 0, rank;
		int[] players = new int[MaxClients + 1];
		for (i = 1; i <= MaxClients; i++) {
			if (!IsValidClient(i)) {
				continue;
			}
			players[index++] = i;
		}

		// 是杀特高手 或 不是杀特高手也不是清僵尸高手, 显示他的杀丧尸排名
		if (client == siMvpClient || client != ciMvpClient) {
			// 没有丧尸击杀, 不显示丧尸排名
			if (ciTotal <= 0) {
				return;
			}

			SortCustom1D(players, index, sortByCiCountFunction);

			for (i = 0; i < index; i++) {
				if (players[i] == client) {
					rank = i + 1;
					break;
				}
			}

			killPercent = RoundToNearest(float(playerInfos[client].ciCount) / float(ciTotal) * 100.0);
			FormatEx(buffer, sizeof(buffer), "{blue}你的排名 {olive}CI: {green}#%d {blue}({default}%d {olive}击杀 {blue}[{default}%d%%{blue}])", rank, playerInfos[client].ciCount, killPercent);
		} else {
			// 没有特感击杀, 不显示特感排名
			if (siTotal <= 0) {
				return;
			}

			SortCustom1D(players, index, sortBySiCountFunction);

			for (i = 0; i < index; i++) {
				if (players[i] == client) {
					rank = i + 1;
					break;
				}
			}

			dmgPercent = RoundToNearest(float(playerInfos[client].totalDamage) / float(dmgTotal) * 100.0);
			killPercent = RoundToNearest(float(playerInfos[client].siCount) / float(siTotal) * 100.0);
			FormatEx(buffer, sizeof(buffer), "{blue}你的排名 {olive}SI: {green}#%d {blue}({default}%d {olive}伤害 {blue}[{default}%d%%{blue}]{default}, %d {olive}击杀 {blue}[{default}%d%%{blue}])", rank, playerInfos[client].totalDamage, dmgPercent, playerInfos[client].siCount, killPercent);
		}
		CPrintToChat(client, "%s", buffer);
	}
}

/**
* 根据客户端是否为 BOT 在其名字后面添加 [BOT] 字样
* @param client 需要获取名称的客户端索引
* @param str 名称字符串
* @param len 字符串长度
* @return void
**/
void formatMvpClientName(int client, char[] str, int len) {
	if (IsFakeClient(client)) {
		FormatEx(str, len, "{green}%N {default}[BOT]", client);
	} else {
		FormatEx(str, len, "{green}%N", client);
	}
}

/**
* 按照生还者总伤害击杀特感数量 -> 客户端索引排序
* @param x 第一个参与排序的元素
* @param y 第二个参与排序的元素
* @param array 原数组
* @param hndl 可选句柄
* @return int
**/
stock int sortBySiCountFunction(int x, int y, const int[] array, Handle hndl) {
	return playerInfos[x].siCount > playerInfos[y].siCount ? -1 : playerInfos[x].siCount == playerInfos[y].siCount ? 0 : 1;
}

/**
* 按照生还者击杀丧尸数量 -> 客户端索引排序
* @param x 第一个参与排序的元素
* @param y 第二个参与排序的元素
* @param array 原数组
* @param hndl 可选句柄
* @return int
**/
stock int sortByCiCountFunction(int x, int y, const int[] array, Handle hndl) {
	return playerInfos[x].ciCount > playerInfos[y].ciCount ? -1 : playerInfos[x].ciCount == playerInfos[y].ciCount ? x > y ? -1 : 1 : 1;
}

/**
* 按照生还者总伤害 -> 客户端索引排序
* @param x 第一个参与排序的元素
* @param y 第二个参与排序的元素
* @param array 原数组
* @param hndl 可选句柄
* @return int
**/
stock int sortByTotalDamageFunction(int x, int y, const int[] array, Handle hndl) {
	return playerInfos[x].totalDamage > playerInfos[y].totalDamage ? -1 : playerInfos[x].totalDamage == playerInfos[y].totalDamage ? x > y ? -1 : 1 : 1;
}

/**
* 按照生还者总伤害 -> 爆头率 -> 客户端索引排序
* @param x 第一个参与排序的元素
* @param y 第二个参与排序的元素
* @param array 原数组
* @param hndl 可选句柄
* @return int
**/
stock int sortByDamageFunction(int x, int y, const int[] array, Handle hndl) {
	int xDamage = playerInfos[x].totalDamage, yDamage = playerInfos[y].totalDamage;

	int xCount = playerInfos[x].siCount + playerInfos[x].ciCount,
		yCount = playerInfos[y].siCount + playerInfos[y].ciCount;
	float xAcc = xCount == 0 ? 0.0 : float(playerInfos[x].headShotCount) / float(xCount),
		yAcc = yCount == 0 ? 0.0 : float(playerInfos[y].headShotCount) / float(yCount);
	// 先按总伤害排名，总伤害一样按爆头率排名, 爆头率一样按客户端索引排名
	return xDamage > yDamage ? -1 : xDamage == yDamage ? FloatCompare(xAcc, yAcc) > 0 ? -1 : FloatCompare(xAcc, yAcc) == 0 ? x > y ? -1 : 1 : 1 : 1;
}

/**
* 按照生还者黑枪 -> 被黑 -> 客户端索引排序
* @param x 第一个参与排序的元素
* @param y 第二个参与排序的元素
* @param array 原数组
* @param hndl 可选句柄
* @return int
**/
stock int sortByFriendlyFireFunction(int x, int y, const int[] array, Handle hndl) {
	int xFF = playerInfos[x].ffCount, yFF = playerInfos[y].ffCount;
	int xGotFF = playerInfos[x].gotFFCount, yGotFF = playerInfos[y].gotFFCount;
	// 先按黑枪排名, 友伤一样按被黑排名, 黑枪一样按客户端索引排名
	return xFF > yFF ? -1 : xFF == yFF ? xGotFF > yGotFF ? -1 : xGotFF == yGotFF ? x > y ? -1 : 1 : 1 : 1;
}

/**
* 按照生还者被黑 -> 客户端索引排序
* @param x 第一个参与排序的元素
* @param y 第二个参与排序的元素
* @param array 原数组
* @param hndl 可选句柄
* @return int
**/
stock int sortByFFReceiveFunction(int x, int y, const int[] array, Handle hndl) {
	return playerInfos[x].gotFFCount > playerInfos[y].gotFFCount ? -1 : playerInfos[x].gotFFCount == playerInfos[y].gotFFCount ? x > y ? -1 : 1 : 1;
}

// Natives
any Native_GetTotalDamageMvp(Handle plugin, int numParams) {
	int count;
	int[] players = new int[MaxClients + 1];
	getSurvivorArray(players, count);
	SortCustom1D(players, count, sortByTotalDamageFunction);
	return players[0];
}

any Native_GetSiMvp(Handle plugin, int numParams) {
	int count;
	int[] players = new int[MaxClients + 1];
	getSurvivorArray(players, count);
	SortCustom1D(players, count, sortBySiCountFunction);
	return players[0];
}

any Native_GetCiMvp(Handle plugin, int numParams) {
	int count;
	int[] players = new int[MaxClients + 1];
	getSurvivorArray(players, count);
	SortCustom1D(players, count, sortByCiCountFunction);
	return players[0];
}

any Native_GetFFMvp(Handle plugin, int numParams) {
	int count;
	int[] players = new int[MaxClients + 1];
	getSurvivorArray(players, count);
	SortCustom1D(players, count, sortByFriendlyFireFunction);
	return players[0];
}

any Native_GetFFReceiveMvp(Handle plugin, int numParams) {
	int count;
	int[] players = new int[MaxClients + 1];
	getSurvivorArray(players, count);
	SortCustom1D(players, count, sortByFFReceiveFunction);
	return players[0];
}

any Native_GetMapFailCount(Handle plugin, int numParams) {
	return failCount;
}

any Native_GetClientRank(Handle plugin, int numParams) {
	int client = GetNativeCell(1);
	int type = GetNativeCell(2);

	if (!IsValidClient(client) || GetClientTeam(client) != TEAM_SURVIVOR) {
		ThrowNativeError(SP_ERROR_NATIVE, "Client (%d) is invalid or not a survivor", client);
	}

	int i, count, rank;
	int[] players = new int[MaxClients + 1];
	getSurvivorArray(players, count);

	switch (type) {
		case 1:
			SortCustom1D(players, count, sortByDamageFunction);
		case 2:
			SortCustom1D(players, count, sortBySiCountFunction);
		case 3:
			SortCustom1D(players, count, sortByCiCountFunction);
		case 4:
			SortCustom1D(players, count, sortByFriendlyFireFunction);
		case 5:
			SortCustom1D(players, count, sortByFFReceiveFunction);
		default: {
			return ThrowNativeError(SP_ERROR_NATIVE, "Invalid type (%d), param type should between 1 and 5", type);
		}
	}
	
	for (i = 0; i < count; i++) {
		if (players[i] == client) {
			rank = i + 1;
			break;
		}
	}

	return rank;
}

void getSurvivorArray(int[] arr, int& size) {
	int index = 0, i;
	for (i = 1; i <= MaxClients; i++) {
		if (!IsValidClient(i) || GetClientTeam(i) != TEAM_SURVIVOR) {
			continue;
		}
		arr[index++] = i;
	}
	size = index;
}

stock bool IsValidClient(int client)
{
    return client > 0 && client <= MaxClients && IsClientInGame(client);
}

stock bool IsValidSurvivor(int client)
{
    return IsValidClient(client) && GetClientTeam(client) == TEAM_SURVIVOR;
}

stock bool IsValidInfected(int client)
{
    return IsValidClient(client) && GetClientTeam(client) == TEAM_INFECTED;
}

stock int GetInfectedClass(int client)
{
    return IsValidInfected(client) ? GetEntProp(client, Prop_Send, "m_zombieClass") : -1;
}