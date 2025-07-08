/*
	2024/11/03
	折磨坏咧修这个

	2024/11/03
	赫赫,小b

	2024/11/05
	完善了下功能,
	把原先的团队差值塞进来了
	加入了个投票恢复ping
	管理员强制平衡和恢复

	2024/11/17
	狗群友说喜欢Center的高延迟感觉
*/
#pragma semicolon 1
#pragma newdecls required

#include <custom_fakelag>
#include <console>
#include <colors>
#include <builtinvotes>

#define ABS(%0) (((%0) < 0) ? -(%0) : (%0))

#define FAKELAG_BOTTOM	0
#define FAKELAG_TOP		400

public Plugin myinfo = 
{
	name = "player_fakelag",
	author = "ProdigySim, Bred, Hana",
	description = "Set a custom fake latency per player",
	version = "1.6",
	url = "https://github.com/ProdigySim/custom_fakelag"
};

ConVar survivor_limit;

ArrayList lowteamplayers;

Handle hVoteEFakelag = null;

public void OnPluginStart()
{
	LoadTranslations("common.phrases");
	LoadTranslations("player_fakelag.phrases");
	
	survivor_limit = FindConVar("survivor_limit");
	
	RegAdminCmd("sm_safl", SetAllFakeLagCmd, ADMFLAG_CONFIG, "Set fake lag for all player(听说你喜欢center的感觉)");
	RegAdminCmd("sm_fakelag", FakeLagCmd, ADMFLAG_CONFIG, "Set fake lag for a player(为指定玩家设置fakelag)");
	RegAdminCmd("sm_fl", FakeLagCmd, ADMFLAG_CONFIG, "Set fake lag for a player(为指定玩家设置fakelag)");
	RegAdminCmd("sm_forceeping", ForceEqualizeFakelagCmd, ADMFLAG_GENERIC, "Force equalize fakelag for all players(管理员强制执行平衡ping)");
	RegAdminCmd("sm_forcecping", CancelEqualizeFakelagCmd, ADMFLAG_GENERIC, "Cancel equalized fakelag for all players(管理员强制取消平衡ping)");
	RegAdminCmd("sm_feping", ForceEqualizeFakelagCmd, ADMFLAG_GENERIC, "Force equalize fakelag for all players(管理员强制执行平衡ping)");
	RegAdminCmd("sm_fcping", CancelEqualizeFakelagCmd, ADMFLAG_GENERIC, "Cancel equalized fakelag for all players(管理员强制取消平衡ping)");
	RegAdminCmd("sm_fefl", ForceEqualizeFakelagCmd, ADMFLAG_GENERIC, "Force equalize fakelag for all players(管理员强制执行平衡ping)");
	RegAdminCmd("sm_fcfl", CancelEqualizeFakelagCmd, ADMFLAG_GENERIC, "Cancel equalized fakelag for all players(管理员强制取消平衡ping)");
	
	RegConsoleCmd("sm_printlag", PrintLagCmd,  "Print Current FakeLag(输出当前在线玩家ping值)");
	RegConsoleCmd("sm_ping", PrintLagCmd,  "Print Current FakeLag(输出当前在线玩家ping值)");
	RegConsoleCmd("sm_pings", PrintLagCmd,  "Print Current FakeLag(输出当前在线玩家ping值)");
	
	RegConsoleCmd("sm_myfakelag", MyFakeLagCmd, "Set fake lag for yourself(设置自己的fakelag值0-400)");
	RegConsoleCmd("sm_myfl", MyFakeLagCmd, "Set fake lag for yourself(设置自己的fakelag值0-400)");
	
	RegConsoleCmd("sm_equalizefakelag", EFakeLagVoteCmd, "Equalize fakelags of all player(平衡所有玩家延迟[非旁观])");
	RegConsoleCmd("sm_efl", EFakeLagVoteCmd, "Equalize fakelags of all player(平衡所有玩家延迟[非旁观])");
	RegConsoleCmd("sm_epings", EFakeLagVoteCmd, "Equalize fakelags of all player(平衡所有玩家延迟[非旁观])");
	RegConsoleCmd("sm_eping", EFakeLagVoteCmd, "Equalize fakelags of all player(平衡所有玩家延迟[非旁观])");

	RegConsoleCmd("sm_cancelefakelag", CancelEFakeLagVoteCmd, "Cancel equalized fakelags(取消平衡延迟,恢复原本延迟)");
	RegConsoleCmd("sm_cfl", CancelEFakeLagVoteCmd, "Cancel equalized fakelags(取消平衡延迟,恢复原本延迟)");
	RegConsoleCmd("sm_cpings", CancelEFakeLagVoteCmd, "Cancel equalized fakelags(取消平衡延迟,恢复原本延迟)");
	RegConsoleCmd("sm_cping", CancelEFakeLagVoteCmd, "Cancel equalized fakelags(取消平衡延迟,恢复原本延迟)");

	RegConsoleCmd("sm_teamequalizefakelag", TeamEFakeLagVoteCmd, "Equalize fakelags of team(平衡团队延迟[非旁观])");
	RegConsoleCmd("sm_tefl", TeamEFakeLagVoteCmd, "Equalize fakelags of team(平衡团队延迟[非旁观])");
	RegConsoleCmd("sm_tepings", TeamEFakeLagVoteCmd, "Equalize fakelags of team(平衡团队延迟[非旁观])");
	RegConsoleCmd("sm_teping", TeamEFakeLagVoteCmd, "Equalize fakelags of team(平衡团队延迟[非旁观])");
}

public Action SetAllFakeLagCmd(int client, int args) 
{
    if(args != 1) 
    {
        CReplyToCommand(client, "%t", "Usage_Safl");
        return Plugin_Handled;
    }
    
    int targetPing = GetCmdArgInt(1);
    
    if (!(FAKELAG_BOTTOM <= targetPing <= FAKELAG_TOP))
    {
        CPrintToChat(client, "%t", "InValid_Fakelag", FAKELAG_BOTTOM, FAKELAG_TOP);
        return Plugin_Handled;
    }

    ClearAllPlayersFakelag();
    
    DataPack dp = new DataPack();
    dp.WriteCell(targetPing);
    dp.WriteCell(client);
    
    CreateTimer(1.0, Timer_SetAllFakelag, dp);
    
    return Plugin_Handled;
}

public Action Timer_SetAllFakelag(Handle timer, DataPack dp)
{
    dp.Reset();
    int targetPing = dp.ReadCell();
    int client = dp.ReadCell();
    delete dp;
    
    // 为每个玩家设置新的延迟
    for(int i = 1; i <= MaxClients; i++) 
    {
        if(IsHuman(i) && (IsSurvivor(i) || IsInfected(i)))
        {
            int currentPing = GetClientAvgPing(i);
            int lagAmount = targetPing - currentPing;
            
            CFakeLag_SetPlayerLatency(i, lagAmount * 1.0);
            CPrintToChat(i, "%t", "eping_notice_player", lagAmount);
        }
    }
    
    CPrintToChatAll("%t", "set_all_fakelag", client, targetPing);
    return Plugin_Handled;
}

public Action FakeLagCmd(int client, int args) 
{
	if(args != 2) 
	{
		CReplyToCommand(client, "%t", "Usage");
		return Plugin_Handled;
	}
	
	char targetStr[256];
	GetCmdArg(1, targetStr, sizeof(targetStr));
	int target = FindTarget(client, targetStr, true);
	if(target < 0) 
	{
		CReplyToCommand(client, "%t", "No_Target");
		return Plugin_Handled;
	}
	if(!IsClientInGame(target)) 
	{
		CReplyToCommand(client, "%t", "Not_Ingame", target);
		return Plugin_Handled;
	}
	if (IsFakeClient(target)) 
	{
		CReplyToCommand(client, "%t", "Fake_Client", target);
		return Plugin_Handled;
	}

	int lagAmount = GetCmdArgInt(2);
	
	if (FAKELAG_BOTTOM <= lagAmount <= FAKELAG_TOP )
	{
		CFakeLag_SetPlayerLatency(target, lagAmount * 1.0);
		CPrintToChatAllEx(target, "%t", "Set_Fakelag", lagAmount, client, target);
		return Plugin_Handled;
	}
	
	CPrintToChat(client, "%t", "InValid_Fakelag", FAKELAG_BOTTOM, FAKELAG_TOP);
	return Plugin_Handled;
}

public Action ForceEqualizeFakelagCmd(int client, int args)
{
    if (!CheckPlayers())
    {
        CPrintToChat(client, "%t", "not_enough_player", survivor_limit.IntValue * 2);
        return Plugin_Handled;
    }

    CPrintToChatAll("%t", "force_equalize_start", client);
    
    ClearAllPlayersFakelag();

    CreateTimer(10.0, Timer_EqualizeFakelag);
    return Plugin_Handled;
}

public Action CancelEqualizeFakelagCmd(int client, int args)
{
    ClearAllPlayersFakelag();
    CPrintToChatAll("%t", "force_equalize_cancel", client);

    return Plugin_Handled;
}

public Action MyFakeLagCmd(int client, int args) 
{
	if(args != 1) 
	{
		CReplyToCommand(client, "%t", "Usage_Myfl");
		return Plugin_Handled;
	}
	
	int lagAmount = GetCmdArgInt(1);
	
	if (FAKELAG_BOTTOM <= lagAmount <= FAKELAG_TOP )
	{
		CFakeLag_SetPlayerLatency(client, lagAmount * 1.0);
		CPrintToChatAllEx(client, "%t", "Set_MyFakelag", lagAmount, client);
		return Plugin_Handled;
	}
	
	CPrintToChat(client, "%t", "InValid_Fakelag", FAKELAG_BOTTOM, FAKELAG_TOP);
	return Plugin_Handled;
}

//--------------------- equalize pings vote -----------------------------

public Action CancelEFakeLagVoteCmd(int client, int args)
{
	if (GetClientTeam(client) <= 1)
    {
        CPrintToChat(client, "%t", "spec_no_access");
        return Plugin_Handled;
    }

	if (StartCancelEFakeLagVote(client))
	{
		CPrintToChatAllEx(client, "%t", "vote_to_cancel", client);
		FakeClientCommand(client, "Vote Yes");
	}

	return Plugin_Handled;
}

bool StartCancelEFakeLagVote(int client)
{
	if (!IsBuiltinVoteInProgress())
	{
		int iNumPlayers;
		int[] iPlayers = new int[MaxClients];
		for (int i = 1; i <= MaxClients; i++)
		{
			if (!IsHuman(i) || (GetClientTeam(i) <= 1))
			{
				continue;
			}
			iPlayers[iNumPlayers++] = i;
		}
			
		char cVoteTitle[32];
		Format(cVoteTitle, sizeof(cVoteTitle), "%T", "Cancel_Vote_Title", LANG_SERVER);

		hVoteEFakelag = CreateBuiltinVote(VoteCancelEFakelagActionHandler, BuiltinVoteType_Custom_YesNo, BuiltinVoteAction_Cancel | BuiltinVoteAction_VoteEnd | BuiltinVoteAction_End);

		SetBuiltinVoteArgument(hVoteEFakelag, cVoteTitle);
		SetBuiltinVoteInitiator(hVoteEFakelag, client);
		SetBuiltinVoteResultCallback(hVoteEFakelag, VoteCancelEFakelagResultHandler);
		DisplayBuiltinVote(hVoteEFakelag, iPlayers, iNumPlayers, 20);
		
		return true;
	}
	
	CPrintToChat(client, "%t", "already_vote");
	return false;
}

public void VoteCancelEFakelagActionHandler(Handle vote, BuiltinVoteAction action, int param1, int param2)
{
	switch (action) 
	{
		case BuiltinVoteAction_End: 
		{
			delete vote;
			hVoteEFakelag = null;
		}
		case BuiltinVoteAction_Cancel: 
		{
			DisplayBuiltinVoteFail(vote, view_as<BuiltinVoteFailReason>(param1));
		}
	}
}

public void VoteCancelEFakelagResultHandler(Handle vote, int num_votes, int num_clients, const int[][] client_info, int num_items, const int[][] item_info)
{
	for (int i = 0; i < num_items; i++) {
		if (item_info[i][BUILTINVOTEINFO_ITEM_INDEX] == BUILTINVOTES_VOTE_YES) 
		{
			if (item_info[i][BUILTINVOTEINFO_ITEM_VOTES] > (num_votes / 2))
			{
				char tVotePass[32];
				Format(tVotePass, sizeof(tVotePass), "%T", "Cancel_Vote_Pass_Title", LANG_SERVER);
				
				DisplayBuiltinVotePass(vote, tVotePass);
				
				ClearAllPlayersFakelag();
				return;
			}
		}
	}

	DisplayBuiltinVoteFail(vote, BuiltinVoteFail_Loses);
}

//--------------------- equalize pings vote -----------------------------

public Action EFakeLagVoteCmd(int client, int args)
{
	if (GetClientTeam(client) <= 1)
    {
        CPrintToChat(client, "%t", "spec_no_access");
        return Plugin_Handled;
    }

	if (StartEFakeLagVote(client))
	{
		CPrintToChatAllEx(client, "%t", "vote_to_start", client);
		FakeClientCommand(client, "Vote Yes");
    } 

	return Plugin_Handled;
}

bool StartEFakeLagVote(int client)
{
	// 人数检查
	if (!CheckPlayers())
	{
		CPrintToChat(client, "%t", "not_enough_player", survivor_limit.IntValue * 2);
	 	return false;
	}
	
	if (!IsBuiltinVoteInProgress())
	{
		int iNumPlayers;
		int[] iPlayers = new int[MaxClients];
		for (int i = 1; i <= MaxClients; i++)
		{
			if (!IsHuman(i) || (GetClientTeam(i) <= 1))
			{
				continue;
			}
			iPlayers[iNumPlayers++] = i;
		}
			
		char cVoteTitle[32];
		Format(cVoteTitle, sizeof(cVoteTitle), "%T", "Vote_Tittle", LANG_SERVER);

		hVoteEFakelag = CreateBuiltinVote(VoteEFakelagActionHandler, BuiltinVoteType_Custom_YesNo, BuiltinVoteAction_Cancel | BuiltinVoteAction_VoteEnd | BuiltinVoteAction_End);

		SetBuiltinVoteArgument(hVoteEFakelag, cVoteTitle);
		SetBuiltinVoteInitiator(hVoteEFakelag, client);
		SetBuiltinVoteResultCallback(hVoteEFakelag, VoteEFakelagResultHandler);
		DisplayBuiltinVote(hVoteEFakelag, iPlayers, iNumPlayers, 20);
		
		return true;
	}
	
	CPrintToChat(client, "%t", "already_vote");
	return false;
}

public void VoteEFakelagActionHandler(Handle vote, BuiltinVoteAction action, int param1, int param2)
{
	switch (action) 
	{
		case BuiltinVoteAction_End: 
		{
			delete vote;
			hVoteEFakelag = null;
		}
		case BuiltinVoteAction_Cancel: 
		{
			DisplayBuiltinVoteFail(vote, view_as<BuiltinVoteFailReason>(param1));
		}
	}
}

public void VoteEFakelagResultHandler(Handle vote, int num_votes, int num_clients, const int[][] client_info, int num_items, const int[][] item_info)
{
	for (int i = 0; i < num_items; i++) {
		if (item_info[i][BUILTINVOTEINFO_ITEM_INDEX] == BUILTINVOTES_VOTE_YES) 
		{
			if (item_info[i][BUILTINVOTEINFO_ITEM_VOTES] > (num_votes / 2))
			{
				char tVotePass[32];
				Format(tVotePass, sizeof(tVotePass), "%T", "Vote_Pass_Tittle", LANG_SERVER);
				
				DisplayBuiltinVotePass(vote, tVotePass);
				
				EqualizeFakelag();
				return;
			}
		}
	}

	DisplayBuiltinVoteFail(vote, BuiltinVoteFail_Loses);
}

public void EqualizeFakelag()
{
	if (!CheckPlayers())
	{
	 	PrintToChatAll("%t", "not_enough_player", survivor_limit.IntValue * 2);
	 	return;
	}

	ClearAllPlayersFakelag();
	CPrintToChatAll("%t","wait_10s");

 	CreateTimer(10.0, Timer_EqualizeFakelag);
}

public Action Timer_EqualizeFakelag(Handle timer)
{
	// 计算当前所有玩家延迟确认最高值
	int highestPing = 0;
	int[] playerPing = new int[MaxClients];

	for (int i = 1; i <= MaxClients; i++)
	{
		if(IsSurvivor(i) || IsInfected(i))
		{
			int ping = GetClientAvgPing(i);
			playerPing[i] = ping;
			if (ping > highestPing)
			{
				highestPing = ping;
			}
		}
	}
	// 目标延迟设置为最高延迟90%
	int targetPing = RoundToNearest(highestPing * 0.90);

	// 增加低延迟玩家延迟,接近目标值延迟
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsSurvivor(i) || IsInfected(i))
		{
			int currentPing = playerPing[i];
			int lagAmount = targetPing - currentPing;
			// 仅对低延迟玩家增加延迟
			if (lagAmount > 0)
			{
				CFakeLag_SetPlayerLatency(i, lagAmount * 1.0);
				CPrintToChat(i, "%t", "eping_notice_player", lagAmount);
			}
		}
	}
	CPrintToChatAll("%t", "equalize_finish", targetPing);
	return Plugin_Handled;
}

//--------------------- team equalize pings vote -----------------------------

public Action TeamEFakeLagVoteCmd(int client, int args)
{
	if (GetClientTeam(client) <= 1)
    {
        CPrintToChat(client, "%t", "spec_no_access");
        return Plugin_Handled;
    }
	
	if (StartTeamEFakeLagVote(client))
	{
		CPrintToChatAllEx(client, "%t", "vote_to_team", client);
		FakeClientCommand(client, "Vote Yes");
    } 

	return Plugin_Handled;
}

bool StartTeamEFakeLagVote(int client)
{
	// 人数检查
	if (!CheckPlayers())
	{
		CPrintToChat(client, "%t", "not_enough_player", survivor_limit.IntValue * 2);
	 	return false;
	}
	
	if (!IsBuiltinVoteInProgress())
	{
		int iNumPlayers;
		int[] iPlayers = new int[MaxClients];
		for (int i = 1; i <= MaxClients; i++)
		{
			if (!IsHuman(i) || (GetClientTeam(i) <= 1))
			{
				continue;
			}
			iPlayers[iNumPlayers++] = i;
		}
			
		char cVoteTitle[32];
		Format(cVoteTitle, sizeof(cVoteTitle), "%T", "Vote_team", LANG_SERVER);

		hVoteEFakelag = CreateBuiltinVote(VoteTeamEFakelagActionHandler, BuiltinVoteType_Custom_YesNo, BuiltinVoteAction_Cancel | BuiltinVoteAction_VoteEnd | BuiltinVoteAction_End);

		SetBuiltinVoteArgument(hVoteEFakelag, cVoteTitle);
		SetBuiltinVoteInitiator(hVoteEFakelag, client);
		SetBuiltinVoteResultCallback(hVoteEFakelag, VoteTeamEFakelagResultHandler);
		DisplayBuiltinVote(hVoteEFakelag, iPlayers, iNumPlayers, 20);
		
		return true;
	}
	
	CPrintToChat(client, "%t", "already_vote");
	return false;
}

public void VoteTeamEFakelagActionHandler(Handle vote, BuiltinVoteAction action, int param1, int param2)
{
	switch (action) 
	{
		case BuiltinVoteAction_End: 
		{
			delete vote;
			hVoteEFakelag = null;
		}
		case BuiltinVoteAction_Cancel: 
		{
			DisplayBuiltinVoteFail(vote, view_as<BuiltinVoteFailReason>(param1));
		}
	}
}

public void VoteTeamEFakelagResultHandler(Handle vote, int num_votes, int num_clients, const int[][] client_info, int num_items, const int[][] item_info)
{
	for (int i = 0; i < num_items; i++) {
		if (item_info[i][BUILTINVOTEINFO_ITEM_INDEX] == BUILTINVOTES_VOTE_YES) 
		{
			if (item_info[i][BUILTINVOTEINFO_ITEM_VOTES] > (num_votes / 2))
			{
				char tVotePass[32];
				Format(tVotePass, sizeof(tVotePass), "%T", "Vote_Pass_team", LANG_SERVER);
				
				DisplayBuiltinVotePass(vote, tVotePass);
				
				TeamEqualizeFakelag();
				return;
			}
		}
	}

	DisplayBuiltinVoteFail(vote, BuiltinVoteFail_Loses);
}

public void TeamEqualizeFakelag()
{
	if (!CheckPlayers())
	{
	 	PrintToChatAll("%t", "not_enough_player", survivor_limit.IntValue * 2);
	 	return;
	}

	ClearAllPlayersFakelag();
	CPrintToChatAll("%t","wait_10s");

 	CreateTimer(10.0, Timer_TeamEqualizeFakelag);
}

public Action Timer_TeamEqualizeFakelag(Handle timer)
{
	// 初始化一下
	lowteamplayers = CreateArray();
	
	int surpings = SumPings(2);
	int infpings = SumPings(3);
	
	int lowteam;
	int avgbuffer;

	ClearArray(lowteamplayers);
	
	if (surpings > infpings)
	{
		lowteam = 3;
		avgbuffer = surpings / survivor_limit.IntValue;
	}
	else
	{
		lowteam = 2;
		avgbuffer = infpings / survivor_limit.IntValue;
	}

	int sumdiff = 0;
	int diff;

	for(int i = 1; i <= MaxClients; i++)
	{
    	if (IsHuman(i) && GetClientTeam(i) == lowteam)
    	{
        	diff = avgbuffer - GetClientAvgPing(i); // 修正计算方向，确保增加低延迟团队的延迟
        	if (diff > 0) // 仅对低延迟的玩家增加延迟
        	{
            	PushArrayCell(lowteamplayers, i);
            	sumdiff += diff;
        	}
    	}
	}

	int teamdiff = ABS(surpings - infpings);

	for (int i = 0; i < GetArraySize(lowteamplayers); i++)
	{
    	int client = GetArrayCell(lowteamplayers, i);
    	int lagAmount = (avgbuffer - GetClientAvgPing(client)) * teamdiff / sumdiff;
		// 设置增加的延迟，确保其为正值
    	if (lagAmount > 0)
		{
			CFakeLag_SetPlayerLatency(client, lagAmount * 1.0);
			CPrintToChat(client, "%t", "eping_notice_player", lagAmount);
		}
	}

	CPrintToChatAll("%t", "equalize_finish", sumdiff);
	
	return Plugin_Handled;
}


// DEBUG: See the value of s_FakeLag
Action PrintLagCmd(int client, int args) 
{
	for(int i = 1; i < MaxClients; i++) 
	{
		if(IsSurvivor(i) || IsInfected(i))
		{
			if (CFakeLag_GetPlayerLatency(i))
				CReplyToCommandEx(client, i, "%t", "show_ping_fl", i, GetClientAvgPing(i) * 1.0, GetClientAvgPing(i) - CFakeLag_GetPlayerLatency(i), CFakeLag_GetPlayerLatency(i));
			else
				CReplyToCommandEx(client, i, "%t", "show_ping", i, GetClientAvgPing(i) * 1.0);
		}
	}
	
	return Plugin_Handled;
}

void ClearAllPlayersFakelag()
{
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsHuman(i))
			CFakeLag_SetPlayerLatency(i, 0.0);
	}
}

stock int SumPings(int team)
{
	int teampings = 0;
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsHuman(i) && GetClientTeam(i) == team)
			teampings += GetClientAvgPing(i);
		continue;
	}
	return teampings;
}

stock int GetClientAvgPing(int client)
{
	return RoundFloat(GetClientAvgLatency(client, NetFlow_Both) * 1000);
}

bool CheckPlayers() 
{
	int count = 0;

	for (int client = 1; client <= MaxClients; client++) 
	{
		if (IsSurvivor(client) || IsInfected(client)) 
		{
			count ++;
		}
		continue;
	}
	return count == survivor_limit.IntValue * 2;
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