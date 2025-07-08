#include <sourcemod>
#include <sdktools>
#include <adminmenu>
#include <left4dhooks>

#pragma semicolon 1
#pragma newdecls required

#define TEAM_SPECTATOR 1
#define TEAM_SURVIVORS 2
#define TEAM_INFECTED 3

TopMenu hTopMenu;
TopMenuObject hHanaTools;

public Plugin myinfo =
{
    name = "Hana Menu",
    description = "狗管理神权时刻",
    author = "Hana",
    version = "1.2",
    url = "https://steamcommunity.com/profiles/76561197983870853/"
};

public void OnPluginStart()
{
    RegAdminCmd("sm_hp", Command_GiveHP, ADMFLAG_CHEATS, "Restore health for survivors");
    RegAdminCmd("sm_givehp", Command_GiveHP, ADMFLAG_CHEATS, "Restore health for survivors");
    RegAdminCmd("sm_respawn", Command_Respawn, ADMFLAG_CHEATS, "Respawn a specific player");
    RegAdminCmd("sm_tele", Command_Teleport, ADMFLAG_CHEATS, "Teleport a player to your crosshair");

    LoadTranslations("common.phrases");

    TopMenu topmenu = GetAdminTopMenu();
    if(topmenu != null)
    {
        OnAdminMenuReady(topmenu);
    }
}

public void OnAdminMenuReady(Handle aTopMenu)
{
    TopMenu topmenu = TopMenu.FromHandle(aTopMenu);
    if(topmenu == hTopMenu) return;

    hTopMenu = topmenu;
    
    hHanaTools = hTopMenu.AddCategory("hana_tools", 
                                    AdminMenu_HanaTools,
                                    "sm_hana",
                                    ADMFLAG_CHEATS);
    
    if(hHanaTools != INVALID_TOPMENUOBJECT)
    {
        hTopMenu.AddItem("sm_givehp", AdminMenu_GiveHP, hHanaTools, "sm_givehp", ADMFLAG_CHEATS);
        hTopMenu.AddItem("sm_respawn", AdminMenu_Respawn, hHanaTools, "sm_respawn", ADMFLAG_CHEATS);
        hTopMenu.AddItem("sm_tele", AdminMenu_Teleport, hHanaTools, "sm_tele", ADMFLAG_CHEATS);
    }
}

public Action Command_GiveHP(int client, int args)
{
    char command[32];
    GetCmdArg(0, command, sizeof(command));
    
    if(StrEqual(command, "sm_hp", false))
    {
        for(int i = 1; i <= MaxClients; i++)
        {
            if(IsClientInGame(i) && GetClientTeam(i) == TEAM_SURVIVORS)
            {
                CheatCommand(i);
            }
        }
        PrintToChatAll("\x01[\x05!\x01] 管理员 \x03%N \x01恢复了 \x05全体生还者 \x04的生命值", client);
        return Plugin_Handled;
    }
    
    if(StrEqual(command, "sm_givehp", false) && args < 1)
    {
        DisplayHPMenu(client);
        return Plugin_Handled;
    }

    char arg[32];
    GetCmdArg(1, arg, sizeof(arg));
    
    int target = FindTarget(client, arg, true, false);
    if(target != -1 && GetClientTeam(target) == TEAM_SURVIVORS)
    {
        CheatCommand(target);
        PrintToChatAll("\x01[\x05!\x01] 管理员 \x03%N \x01恢复了 \x05%N \x04的生命值", client, target);
    }
    
    return Plugin_Handled;
}

public Action Command_Respawn(int client, int args)
{
    if(args < 1)
    {
        DisplayRespawnMenu(client);
        return Plugin_Handled;
    }

    char arg[32];
    GetCmdArg(1, arg, sizeof(arg));
    
    int target = FindTarget(client, arg, true, false);
    if(target != -1 && GetClientTeam(target) == TEAM_SURVIVORS)
    {
        float pos[3];
        if(GetClientAimPosition(client, pos))
        {
            RespawnPlayer(target, pos);
            PrintToChatAll("\x01[\x05!\x01] 管理员 \x03%N \x01复活了玩家 \x05%N", client, target);
        }
    }
    
    return Plugin_Handled;
}

public Action Command_Teleport(int client, int args)
{
    if(args < 1)
    {
        DisplayTeleportMenu(client);
        return Plugin_Handled;
    }

    char arg[32];
    GetCmdArg(1, arg, sizeof(arg));
    
    int target = FindTarget(client, arg, true, false);
    if(target != -1)
    {
        float pos[3];
        if(GetClientAimPosition(client, pos))
        {
            TeleportEntity(target, pos, NULL_VECTOR, NULL_VECTOR);
            PrintToChatAll("\x01[\x05!\x01] 管理员 \x03%N \x01传送了玩家 \x05%N", client, target);
        }
    }
    
    return Plugin_Handled;
}

void DisplayHPMenu(int client)
{
    Menu menu = new Menu(MenuHandler_GiveHP);
    menu.SetTitle("选择要恢复血量的目标:");
    menu.AddItem("0", "全体生还者");
    
    char userid[12], name[MAX_NAME_LENGTH];
    for(int i = 1; i <= MaxClients; i++)
    {
        if(IsClientInGame(i) && GetClientTeam(i) == TEAM_SURVIVORS)
        {
            Format(userid, sizeof(userid), "%d", GetClientUserId(i));
            GetClientName(i, name, sizeof(name));
            menu.AddItem(userid, name);
        }
    }
    
    AddMenuExitBack(menu, client);
}

void DisplayRespawnMenu(int client)
{
    Menu menu = new Menu(MenuHandler_RespawnPlayer);
    menu.SetTitle("选择要复活的玩家:");
    
    char userid[12], name[MAX_NAME_LENGTH];
    bool foundTarget = false;
    
    for(int i = 1; i <= MaxClients; i++)
    {
        if(IsClientInGame(i) && GetClientTeam(i) == TEAM_SURVIVORS && !IsPlayerAlive(i))
        {
            Format(userid, sizeof(userid), "%d", GetClientUserId(i));
            GetClientName(i, name, sizeof(name));
            menu.AddItem(userid, name);
            foundTarget = true;
        }
    }
    
    if(!foundTarget)
    {
        menu.AddItem("", "没有可复活的玩家", ITEMDRAW_DISABLED);
    }
    
    AddMenuExitBack(menu, client);
}

void DisplayTeleportMenu(int client)
{
    Menu menu = new Menu(MenuHandler_TeleportMain);
    menu.SetTitle("传送菜单:");
    menu.AddItem("cursor", "传送到准心");
    menu.AddItem("player", "传送到玩家");
    AddMenuExitBack(menu, client);
}

void DisplayPlayerTeleportMenu(int client)
{
    Menu menu = new Menu(MenuHandler_PlayerTeleport);
    menu.SetTitle("选择传送目标位置:");
    
    char userid[12], name[MAX_NAME_LENGTH];
    for(int i = 1; i <= MaxClients; i++)
    {
        if(IsClientInGame(i) && GetClientTeam(i) == TEAM_SURVIVORS)
        {
            Format(userid, sizeof(userid), "%d", GetClientUserId(i));
            GetClientName(i, name, sizeof(name));
            menu.AddItem(userid, name);
        }
    }
    
    menu.AddItem("select", "选择单个传送目标");
    AddMenuExitBack(menu, client);
}

void DisplayCursorTeleportMenu(int client)
{
    Menu menu = new Menu(MenuHandler_CursorTeleport);
    menu.SetTitle("选择要传送到准心的目标:");
    menu.AddItem("self", "传送自己");
    menu.AddItem("all", "传送全体");
    
    char userid[12], name[MAX_NAME_LENGTH];
    for(int i = 1; i <= MaxClients; i++)
    {
        if(IsClientInGame(i) && GetClientTeam(i) == TEAM_SURVIVORS)
        {
            Format(userid, sizeof(userid), "%d", GetClientUserId(i));
            GetClientName(i, name, sizeof(name));
            menu.AddItem(userid, name);
        }
    }
    
    AddMenuExitBack(menu, client);
}

void DisplaySelectPlayerMenu(int client)
{
    Menu menu = new Menu(MenuHandler_SelectPlayer);
    menu.SetTitle("传送到谁身边:");
    
    char userid[12], name[MAX_NAME_LENGTH];
    for(int i = 1; i <= MaxClients; i++)
    {
        if(IsClientInGame(i) && GetClientTeam(i) == TEAM_SURVIVORS)
        {
            Format(userid, sizeof(userid), "%d", GetClientUserId(i));
            GetClientName(i, name, sizeof(name));
            menu.AddItem(userid, name);
        }
    }
    
    AddMenuExitBack(menu, client);
}

public int MenuHandler_GiveHP(Menu menu, MenuAction action, int param1, int param2)
{
    switch(action)
    {
        case MenuAction_Select:
        {
            char item[32];
            menu.GetItem(param2, item, sizeof(item));
            
            if(StrEqual(item, "0"))
            {
                for(int i = 1; i <= MaxClients; i++)
                {
                    if(IsClientInGame(i) && GetClientTeam(i) == TEAM_SURVIVORS)
                    {
                        CheatCommand(i);
                    }
                }
                PrintToChatAll("\x01[\x05!\x01] 管理员 \x03%N \x01恢复了 \x05全体生还者 \x04的生命值", param1);
            }
            else
            {
                int userid = StringToInt(item);
                int target = GetClientOfUserId(userid);
                
                if(target && IsClientInGame(target))
                {
                    CheatCommand(target);
                    PrintToChatAll("\x01[\x05!\x01] 管理员 \x03%N \x01恢复了 \x05%N \x04的生命值", param1, target);
                }
            }
            DisplayHPMenu(param1);
        }
        case MenuAction_Cancel:
        {
            if(param2 == MenuCancel_ExitBack && hTopMenu)
                hTopMenu.Display(param1, TopMenuPosition_LastCategory);
        }
        case MenuAction_End:
            delete menu;
    }
    return 0;
}

public int MenuHandler_RespawnPlayer(Menu menu, MenuAction action, int param1, int param2)
{
    switch(action)
    {
        case MenuAction_Select:
        {
            char item[32];
            menu.GetItem(param2, item, sizeof(item));
            
            int userid = StringToInt(item);
            int target = GetClientOfUserId(userid);
            
            if(target && IsClientInGame(target))
            {
                float pos[3];
                if(GetClientAimPosition(param1, pos))
                {
                    RespawnPlayer(target, pos);
                    PrintToChatAll("\x01[\x05!\x01] 管理员 \x03%N \x01复活了玩家 \x05%N", param1, target);
                }
            }
            DisplayRespawnMenu(param1);
        }
        case MenuAction_Cancel:
        {
            if(param2 == MenuCancel_ExitBack && hTopMenu)
                hTopMenu.Display(param1, TopMenuPosition_LastCategory);
        }
        case MenuAction_End:
            delete menu;
    }
    return 0;
}

public int MenuHandler_TeleportMain(Menu menu, MenuAction action, int param1, int param2)
{
    switch(action)
    {
        case MenuAction_Select:
        {
            char item[32];
            menu.GetItem(param2, item, sizeof(item));
            
            if(StrEqual(item, "cursor"))
                DisplayCursorTeleportMenu(param1);
            else if(StrEqual(item, "player"))
                DisplayPlayerTeleportMenu(param1);
        }
        case MenuAction_Cancel:
        {
            if(param2 == MenuCancel_ExitBack && hTopMenu)
                hTopMenu.Display(param1, TopMenuPosition_LastCategory);
        }
        case MenuAction_End:
            delete menu;
    }
    return 0;
}

public int MenuHandler_CursorTeleport(Menu menu, MenuAction action, int param1, int param2)
{
    switch(action)
    {
        case MenuAction_Select:
        {
            char item[32];
            menu.GetItem(param2, item, sizeof(item));
            
            float pos[3];
            if(GetClientAimPosition(param1, pos))
            {
                if(StrEqual(item, "self"))
                {
                    TeleportEntity(param1, pos, NULL_VECTOR, NULL_VECTOR);
                    PrintToChatAll("\x01[\x05!\x01] 管理员 \x03%N \x01传送到了准心位置", param1);
                }
                else if(StrEqual(item, "all"))
                {
                    for(int i = 1; i <= MaxClients; i++)
                    {
                        if(IsClientInGame(i) && GetClientTeam(i) == TEAM_SURVIVORS)
                        {
                            TeleportEntity(i, pos, NULL_VECTOR, NULL_VECTOR);
                        }
                    }
                    PrintToChatAll("\x01[\x05!\x01] 管理员 \x03%N \x01传送了全体生还者到准心位置", param1);
                }
                else
                {
                    int userid = StringToInt(item);
                    int target = GetClientOfUserId(userid);
                    
                    if(target && IsClientInGame(target))
                    {
                        TeleportEntity(target, pos, NULL_VECTOR, NULL_VECTOR);
                        PrintToChatAll("\x01[\x05!\x01] 管理员 \x03%N \x01传送了 \x05%N \x01到准心位置", param1, target);
                    }
                }
            }
            DisplayTeleportMenu(param1);
        }
        case MenuAction_Cancel:
        {
            if(param2 == MenuCancel_ExitBack)
                DisplayTeleportMenu(param1);
        }
        case MenuAction_End:
            delete menu;
    }
    return 0;
}

public int MenuHandler_PlayerTeleport(Menu menu, MenuAction action, int param1, int param2)
{
    switch(action)
    {
        case MenuAction_Select:
        {
            char item[32];
            menu.GetItem(param2, item, sizeof(item));
            
            if(StrEqual(item, "select"))
            {
                DisplaySelectPlayerMenu(param1);
                return 0;
            }
            
            int userid = StringToInt(item);
            int target = GetClientOfUserId(userid);
            
            if(target && IsClientInGame(target))
            {
                float pos[3];
                GetClientAbsOrigin(target, pos);
                
                for(int i = 1; i <= MaxClients; i++)
                {
                    if(IsClientInGame(i) && GetClientTeam(i) == TEAM_SURVIVORS && i != target)
                    {
                        TeleportEntity(i, pos, NULL_VECTOR, NULL_VECTOR);
                    }
                }
                PrintToChatAll("\x01[\x05!\x01] 管理员 \x03%N \x01传送了全体生还者到 \x05%N \x01身边", param1, target);
            }
            DisplayTeleportMenu(param1);
        }
        case MenuAction_Cancel:
        {
            if(param2 == MenuCancel_ExitBack)
                DisplayTeleportMenu(param1);
        }
        case MenuAction_End:
            delete menu;
    }
    return 0;
}

public int MenuHandler_SelectPlayer(Menu menu, MenuAction action, int param1, int param2)
{
    switch(action)
    {
        case MenuAction_Select:
        {
            char item[32];
            menu.GetItem(param2, item, sizeof(item));
            
            int userid = StringToInt(item);
            int target = GetClientOfUserId(userid);
            
            if(target && IsClientInGame(target))
            {
                DisplayTargetMenu(param1, target);
            }
        }
        case MenuAction_Cancel:
        {
            if(param2 == MenuCancel_ExitBack)
                DisplayTeleportMenu(param1);
        }
        case MenuAction_End:
            delete menu;
    }
    return 0;
}

public int MenuHandler_Target(Menu menu, MenuAction action, int param1, int param2)
{
    switch(action)
    {
        case MenuAction_Select:
        {
            char item[32], items[2][12];
            menu.GetItem(param2, item, sizeof(item));
            ExplodeString(item, ";", items, sizeof(items), sizeof(items[]));
            
            int targetid = StringToInt(items[0]);
            int playerid = StringToInt(items[1]);
            
            int target = GetClientOfUserId(targetid);
            int player = GetClientOfUserId(playerid);
            
            if(target && player && IsClientInGame(target) && IsClientInGame(player))
            {
                float pos[3];
                GetClientAbsOrigin(target, pos);
                TeleportEntity(player, pos, NULL_VECTOR, NULL_VECTOR);
                PrintToChatAll("\x01[\x05!\x01] 管理员 \x03%N \x01传送了 \x05%N \x01到 \x05%N \x01身边", param1, player, target);
            }
            DisplayTeleportMenu(param1);
        }
        case MenuAction_Cancel:
        {
            if(param2 == MenuCancel_ExitBack)
                DisplaySelectPlayerMenu(param1);
        }
        case MenuAction_End:
            delete menu;
    }
    return 0;
}

void DisplayTargetMenu(int client, int target)
{
    Menu menu = new Menu(MenuHandler_Target);
    menu.SetTitle("选择要传送到 %N 身边的玩家:", target);
    
    char userid[32], name[MAX_NAME_LENGTH];
    Format(userid, sizeof(userid), "%d", GetClientUserId(target));
    
    for(int i = 1; i <= MaxClients; i++)
    {
        if(IsClientInGame(i) && GetClientTeam(i) == TEAM_SURVIVORS && i != target)
        {
            Format(userid, sizeof(userid), "%d;%d", GetClientUserId(target), GetClientUserId(i));
            GetClientName(i, name, sizeof(name));
            menu.AddItem(userid, name);
        }
    }
    
    AddMenuExitBack(menu, client);
}

void RespawnPlayer(int client, float pos[3])
{
    L4D_RespawnPlayer(client);
    TeleportEntity(client, pos, NULL_VECTOR, NULL_VECTOR);
}

void CheatCommand(int client)
{
    int give_flags = GetCommandFlags("give");
    SetCommandFlags("give", give_flags & ~FCVAR_CHEAT);

    if(GetEntProp(client, Prop_Send, "m_isHangingFromLedge") || 
       (IsIncapacitated(client) && GetInfectedAttacker(client) == -1) ||
       GetClientHealth(client) < 100)
    {
        FakeClientCommand(client, "give health");
        if(!GetEntProp(client, Prop_Send, "m_isHangingFromLedge"))
        {
            SetEntPropFloat(client, Prop_Send, "m_healthBufferTime", GetGameTime());
            SetEntPropFloat(client, Prop_Send, "m_healthBuffer", 0.0);
        }
    }
    
    SetCommandFlags("give", give_flags);
}

bool IsIncapacitated(int client)
{
    return view_as<bool>(GetEntProp(client, Prop_Send, "m_isIncapacitated"));
}

int GetInfectedAttacker(int client)
{
    static const char attackerProps[][] = {
        "m_pummelAttacker",
        "m_carryAttacker",
        "m_jockeyAttacker",
        "m_pounceAttacker",
        "m_tongueOwner"
    };
    
    int attacker;
    for(int i = 0; i < sizeof(attackerProps); i++)
    {
        attacker = GetEntPropEnt(client, Prop_Send, attackerProps[i]);
        if(attacker > 0) return attacker;
    }
    return -1;
}

bool GetClientAimPosition(int client, float pos[3])
{
    float vAngles[3], vOrigin[3];
    GetClientEyePosition(client, vOrigin);
    GetClientEyeAngles(client, vAngles);
    
    Handle trace = TR_TraceRayFilterEx(vOrigin, vAngles, MASK_SHOT, RayType_Infinite, TraceEntityFilterPlayer);
    if(TR_DidHit(trace))
    {
        TR_GetEndPosition(pos, trace);
        delete trace;
        return true;
    }
    delete trace;
    return false;
}

public bool TraceEntityFilterPlayer(int entity, int contentsMask)
{
    return entity > MaxClients || !entity;
}

void AddMenuExitBack(Menu menu, int client)
{
    menu.ExitBackButton = true;
    menu.Display(client, MENU_TIME_FOREVER);
}

public void AdminMenu_HanaTools(TopMenu topmenu, TopMenuAction action, TopMenuObject object_id, int param, char[] buffer, int maxlength)
{
    if(action == TopMenuAction_DisplayTitle || action == TopMenuAction_DisplayOption)
    {
        Format(buffer, maxlength, "花的小菜单");
    }
}

public void AdminMenu_GiveHP(TopMenu topmenu, TopMenuAction action, TopMenuObject object_id, int param, char[] buffer, int maxlength)
{
    if(action == TopMenuAction_DisplayOption)
    {
        Format(buffer, maxlength, "恢复血量");
    }
    else if(action == TopMenuAction_SelectOption)
    {
        DisplayHPMenu(param);
    }
}

public void AdminMenu_Respawn(TopMenu topmenu, TopMenuAction action, TopMenuObject object_id, int param, char[] buffer, int maxlength)
{
    if(action == TopMenuAction_DisplayOption)
    {
        Format(buffer, maxlength, "复活玩家");
    }
    else if(action == TopMenuAction_SelectOption)
    {
        DisplayRespawnMenu(param);
    }
}

public void AdminMenu_Teleport(TopMenu topmenu, TopMenuAction action, TopMenuObject object_id, int param, char[] buffer, int maxlength)
{
    if(action == TopMenuAction_DisplayOption)
    {
        Format(buffer, maxlength, "传送玩家");
    }
    else if(action == TopMenuAction_SelectOption)
    {
        DisplayTeleportMenu(param);
    }
}