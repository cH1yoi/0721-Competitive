#pragma semicolon               1
#pragma newdecls                required
#include <sourcemod>
#include <colors>
#include <l4d2util_constants>
#include <exp_interface>

#undef REQUIRE_PLUGIN
#include <readyup>
#define REQUIRE_PLUGIN

public void OnPluginStart()
{
    RegConsoleCmd("sm_exp", CMD_Exp);
}

public void OnRoundIsLive()
{
    CreateTimer(3.0, Timer_DelayedRoundIsLive);
}

public Action Timer_DelayedRoundIsLive(Handle timer){
    for(int i = 1; i <= MaxClients; i++){
        if (IsClientInGame(i)){
            PrintExp(i, false);
        }
    }
    CPrintToChatAll("{default}使用{green} !exp{default} 查看每个人的经验分");
    
    return Plugin_Handled;

}

public Action CMD_Exp(int client, int args){
    PrintExp(client, true);
    return Plugin_Handled;
}



void PrintExp(int client, bool show_everyone) {
    int surs, infs;
    int surc, infc;
    int surl[MAXPLAYERS], infl[MAXPLAYERS];
    
    for (int i = 1; i <= MaxClients; i++) {
        if (!IsClientInGame(i) || IsFakeClient(i)) continue;
        
        switch (GetClientTeam(i)) {
            case L4D2Team_Survivor: {
                if (show_everyone) {
                    CPrintToChat(client, "{blue}%N{default} %i[{green}%s{default}]", i, L4D2_GetClientExp(i), EXPRankNames[L4D2_GetClientExpRankLevel(i)]);
                }
                surs += L4D2_GetClientExp(i);
                surl[surc] = L4D2_GetClientExp(i);
                surc++;
            }
            case L4D2Team_Infected: {
                if (show_everyone) {
                    CPrintToChat(client, "{red}%N{default} %i[{green}%s{default}]", i, L4D2_GetClientExp(i), EXPRankNames[L4D2_GetClientExpRankLevel(i)]);
                }
                infs += L4D2_GetClientExp(i);
                infl[infc] = L4D2_GetClientExp(i);
                infc++;
            }
            case L4D2Team_Spectator: {
                if (show_everyone) {
                    CPrintToChat(client, "{default}%N{default} %i[{green}%s{default}]", i, L4D2_GetClientExp(i), EXPRankNames[L4D2_GetClientExpRankLevel(i)]);
                }
            }
        }
    }
    
    CPrintToChat(client, "============================");
    
    if (surc > 0) {
        float surCV = CalculateCoefficientOfVariation(surl, surc);
        CPrintToChat(client, "[{green}EXP{default}] {blue}生还者: %i{default} (平均 %i / 变异系数 %.2f%%)", 
            surs, surs/surc, surCV);
    }
    
    if (infc > 0) {
        float infCV = CalculateCoefficientOfVariation(infl, infc);
        CPrintToChat(client, "[{green}EXP{default}] {red}感染者: %i{default} (平均 %i / 变异系数 %.2f%%)", 
            infs, infs/infc, infCV);
    }
}

float CalculateCoefficientOfVariation(int[] array, int validLength)
{
    if (validLength <= 1) return 0.0;
    
    int sum = 0;
    for (int i = 0; i < validLength; i++) {
        sum += array[i];
    }
    
    float mean = float(sum) / float(validLength);
    if (mean == 0.0) return 0.0;
    
    float variance = 0.0;
    for (int i = 0; i < validLength; i++) {
        float diff = float(array[i]) - mean;
        variance += (diff * diff);
    }
    variance /= float(validLength - 1);
    
    float std_dev = SquareRoot(variance);
    return (std_dev / mean) * 100.0;
}