/******************************/
/*     [L4D(2)] Laser Tag     */
/*       By KrX/ Whosat       */
/* -------------------------- */
/* Creates a laser beam from  */
/*  player to bullet impact   */
/*  point.                    */
/* -------------------------- */
/*  Version 0.3 (2024)        */
/* -------------------------- */
/******************************/

#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#undef REQUIRE_PLUGIN
#include <readyup>
#define REQUIRE_PLUGIN

#define PLUGIN_VERSION "0.3"

#define DEFAULT_FLAGS FCVAR_NOTIFY

#define WEAPONTYPE_PISTOL   6
#define WEAPONTYPE_RIFLE    5 
#define WEAPONTYPE_SNIPER   4
#define WEAPONTYPE_SMG      3
#define WEAPONTYPE_SHOTGUN  2
#define WEAPONTYPE_MELEE    1
#define WEAPONTYPE_UNKNOWN  0

ConVar 
    cvar_vsenable,
    cvar_realismenable,
    cvar_bots,
    cvar_enable,
    cvar_pistols,
    cvar_rifles,
    cvar_snipers,
    cvar_smgs,
    cvar_shotguns,
    cvar_laser_red,
    cvar_laser_green,
    cvar_laser_blue,
    cvar_laser_alpha,
    cvar_bots_red,
    cvar_bots_green,
    cvar_bots_blue,
    cvar_bots_alpha,
    cvar_laser_life,
    cvar_laser_width,
    cvar_laser_offset;

bool 
    g_LaserTagEnable = true,
    g_Bots,
    b_TagWeapon[7],
    isL4D2;

float
    g_LaserOffset,
    g_LaserWidth,
    g_LaserLife;

int
    g_LaserColor[4],
    g_BotsLaserColor[4],
    g_Sprite,
    GameMode;

ConVar changecvar;

public Plugin myinfo = 
{
    name = "[L4D(2)] Laser Tag",
    author = "KrX/Whosat, Modified by YourName",
    description = "Shows a laser for straight-flying fired projectiles",
    version = PLUGIN_VERSION,
    url = "http://forums.alliedmods.net/showthread.php?p=1203196"
};

public void OnPluginStart()
{   
    cvar_enable = CreateConVar("l4d_lasertag_enable", "1", "Turn on Lasertagging. 0=disable, 1=enable", FCVAR_NOTIFY, true, 0.0, true, 1.0);
    cvar_vsenable = CreateConVar("l4d_lasertag_vs", "1", "Enable or Disable Lasertagging in Versus / Scavenge", FCVAR_NOTIFY, true, 0.0, true, 1.0);
    cvar_realismenable = CreateConVar("l4d_lasertag_realism", "1", "Enable or Disable Lasertagging in Realism. 0=disable, 1=enable", FCVAR_NOTIFY, true, 0.0, true, 1.0);
    cvar_bots = CreateConVar("l4d_lasertag_bots", "1", "Enable or Disable lasertagging for bots. 0=disable, 1=enable", FCVAR_NOTIFY, true, 0.0, true, 1.0);
    
    cvar_pistols = CreateConVar("l4d_lasertag_pistols", "1", "LaserTagging for Pistols. 0=disable, 1=enable", FCVAR_NOTIFY, true, 0.0, true, 1.0);
    cvar_rifles = CreateConVar("l4d_lasertag_rifles", "1", "LaserTagging for Rifles. 0=disable, 1=enable", FCVAR_NOTIFY, true, 0.0, true, 1.0);
    cvar_snipers = CreateConVar("l4d_lasertag_snipers", "1", "LaserTagging for Sniper Rifles. 0=disable, 1=enable", FCVAR_NOTIFY, true, 0.0, true, 1.0);
    cvar_smgs = CreateConVar("l4d_lasertag_smgs", "1", "LaserTagging for SMGs. 0=disable, 1=enable", FCVAR_NOTIFY, true, 0.0, true, 1.0);
    cvar_shotguns = CreateConVar("l4d_lasertag_shotguns", "1", "LaserTagging for Shotguns. 0=disable, 1=enable", FCVAR_NOTIFY, true, 0.0, true, 1.0);
        
    cvar_laser_red = CreateConVar("l4d_lasertag_red", "0", "Amount of Red", FCVAR_NOTIFY, true, 0.0, true, 255.0);
    cvar_laser_green = CreateConVar("l4d_lasertag_green", "125", "Amount of Green", FCVAR_NOTIFY, true, 0.0, true, 255.0);
    cvar_laser_blue = CreateConVar("l4d_lasertag_blue", "255", "Amount of Blue", FCVAR_NOTIFY, true, 0.0, true, 255.0);
    cvar_laser_alpha = CreateConVar("l4d_lasertag_alpha", "100", "Transparency (Alpha) of Laser", FCVAR_NOTIFY, true, 0.0, true, 255.0);
    
    cvar_bots_red = CreateConVar("l4d_lasertag_bots_red", "0", "Bots Laser - Amount of Red", FCVAR_NOTIFY, true, 0.0, true, 255.0);
    cvar_bots_green = CreateConVar("l4d_lasertag_bots_green", "255", "Bots Laser - Amount of Green", FCVAR_NOTIFY, true, 0.0, true, 255.0);
    cvar_bots_blue = CreateConVar("l4d_lasertag_bots_blue", "75", "Bots Laser - Amount of Blue", FCVAR_NOTIFY, true, 0.0, true, 255.0);
    cvar_bots_alpha = CreateConVar("l4d_lasertag_bots_alpha", "70", "Bots Laser - Transparency (Alpha) of Laser", FCVAR_NOTIFY, true, 0.0, true, 255.0);
    
    cvar_laser_life = CreateConVar("l4d_lasertag_life", "0.80", "Seconds Laser will remain", FCVAR_NOTIFY, true, 0.1);
    cvar_laser_width = CreateConVar("l4d_lasertag_width", "1.0", "Width of Laser", FCVAR_NOTIFY, true, 1.0);
    cvar_laser_offset = CreateConVar("l4d_lasertag_offset", "36", "Lasertag Offset", FCVAR_NOTIFY);
    
    CreateConVar("l4d_lasertag_version", PLUGIN_VERSION, "Lasertag Version", FCVAR_NOTIFY|FCVAR_DONTRECORD);
    
    //AutoExecConfig(true, "l4d_lasertag");
    
    char GameName[16];
    GetConVarString(FindConVar("mp_gamemode"), GameName, sizeof(GameName));
    
    // Check if L4D2 or L4D1
    GetGameFolderName(GameName, sizeof(GameName));
    if (StrEqual(GameName, "left4dead2", false)) 
    {
        isL4D2 = true;
    }
    else 
    {
        isL4D2 = false;
    }
    
    if (StrEqual(GameName, "survival", false))
    {
        GameMode = 3;
    }
    else if (StrEqual(GameName, "versus", false) || StrEqual(GameName, "teamversus", false) || 
             StrEqual(GameName, "scavenge", false) || StrEqual(GameName, "teamscavenge", false))
    {
        GameMode = 2;
    }
    else if (StrEqual(GameName, "coop", false))
    {
        GameMode = 1;
    }
    else if (StrEqual(GameName, "realism", false))
    {
        GameMode = 0;
    }
    else
    {
        GameMode = -1;
    }
    
    HookEvent("bullet_impact", Event_BulletImpact);
    
    // ConVars that change whether the plugin is enabled
    HookConVarChange(cvar_enable, CheckEnabled);
    HookConVarChange(cvar_vsenable, CheckEnabled);
    HookConVarChange(cvar_realismenable, CheckEnabled);
    HookConVarChange(cvar_bots, CheckEnabled);
    
    HookConVarChange(cvar_pistols, CheckWeapons);
    HookConVarChange(cvar_rifles, CheckWeapons);
    HookConVarChange(cvar_snipers, CheckWeapons);
    HookConVarChange(cvar_smgs, CheckWeapons);
    HookConVarChange(cvar_shotguns, CheckWeapons);
    
    HookConVarChange(cvar_laser_red, UselessHooker);
    HookConVarChange(cvar_laser_blue, UselessHooker);
    HookConVarChange(cvar_laser_green, UselessHooker);
    HookConVarChange(cvar_laser_alpha, UselessHooker);
    HookConVarChange(cvar_bots_red, UselessHooker);
    HookConVarChange(cvar_bots_blue, UselessHooker);
    HookConVarChange(cvar_bots_green, UselessHooker);
    HookConVarChange(cvar_bots_alpha, UselessHooker);
    
    HookConVarChange(cvar_laser_life, UselessHooker);
    HookConVarChange(cvar_laser_width, UselessHooker);
    HookConVarChange(cvar_laser_offset, UselessHooker);

    changecvar = FindConVar("l4d_lasertag_enable");
}

public void OnMapStart()
{
    if(isL4D2)
    {
        g_Sprite = PrecacheModel("materials/sprites/laserbeam.vmt");            
    }
    else
    {
        g_Sprite = PrecacheModel("materials/sprites/laser.vmt");        
    }
}


public void OnRoundIsLive()
{
    changecvar.IntValue = 0;
}

public void OnReadyUpInitiate()
{
    changecvar.IntValue = 1;
}

public void UselessHooker(ConVar convar, const char[] oldValue, const char[] newValue)
{
    OnConfigsExecuted();
}

public void OnConfigsExecuted()
{
    CheckEnabled(null, "", "");
    CheckWeapons(null, "", "");
    
    g_LaserColor[3] = GetConVarInt(cvar_laser_alpha);
    g_BotsLaserColor[0] = GetRandomInt(0, 255);
    g_BotsLaserColor[1] = GetRandomInt(0, 255);
    g_BotsLaserColor[2] = GetRandomInt(0, 255);
    g_BotsLaserColor[3] = GetConVarInt(cvar_bots_alpha);
    
    g_LaserLife = GetConVarFloat(cvar_laser_life);
    g_LaserWidth = GetConVarFloat(cvar_laser_width);
    g_LaserOffset = GetConVarFloat(cvar_laser_offset);
}

public void CheckEnabled(ConVar convar, const char[] oldValue, const char[] newValue)
{
    // Bot Laser Tagging?
    g_Bots = GetConVarBool(cvar_bots);
    
    if(GetConVarInt(cvar_enable) == 0) {
        // IS GLOBALLY ENABLED?
        g_LaserTagEnable = false;
    } else if(GameMode == 2 && GetConVarInt(cvar_vsenable) == 0) {
        // IS VS Enabled?
        g_LaserTagEnable = false;
    } else if(GameMode == 0 && GetConVarInt(cvar_realismenable) == 0) {
        // IS REALISM ENABLED?
        g_LaserTagEnable = false;
    } else {
        // None of the above fulfilled, enable plugin.
        g_LaserTagEnable = true;
    }
}

public void CheckWeapons(ConVar convar, const char[] oldValue, const char[] newValue)
{
    b_TagWeapon[WEAPONTYPE_PISTOL] = GetConVarBool(cvar_pistols);
    b_TagWeapon[WEAPONTYPE_RIFLE] = GetConVarBool(cvar_rifles);
    b_TagWeapon[WEAPONTYPE_SNIPER] = GetConVarBool(cvar_snipers);
    b_TagWeapon[WEAPONTYPE_SMG] = GetConVarBool(cvar_smgs);
    b_TagWeapon[WEAPONTYPE_SHOTGUN] = GetConVarBool(cvar_shotguns);
}

int GetWeaponType(int userid)
{
    // Get current weapon
    char weapon[32];
    GetClientWeapon(userid, weapon, sizeof(weapon));
    
    if(StrEqual(weapon, "weapon_hunting_rifle") || StrContains(weapon, "sniper") >= 0) return WEAPONTYPE_SNIPER;
    if(StrContains(weapon, "weapon_rifle") >= 0) return WEAPONTYPE_RIFLE;
    if(StrContains(weapon, "pistol") >= 0) return WEAPONTYPE_PISTOL;
    if(StrContains(weapon, "smg") >= 0) return WEAPONTYPE_SMG;
    if(StrContains(weapon, "shotgun") >=0) return WEAPONTYPE_SHOTGUN;
    
    return WEAPONTYPE_UNKNOWN;
}

public Action Event_BulletImpact(Event event, const char[] name, bool dontBroadcast)
{
    if(!g_LaserTagEnable) return Plugin_Continue;

    int userid = GetClientOfUserId(event.GetInt("userid"));
    if(GetClientTeam(userid) != 2) return Plugin_Continue;

    bool isBot = IsFakeClient(userid);
    if(isBot && !g_Bots) return Plugin_Continue;

    if(b_TagWeapon[GetWeaponType(userid)])
    {
        float x = event.GetFloat("x");
        float y = event.GetFloat("y");
        float z = event.GetFloat("z");
        
        float startPos[3], bulletPos[3], playerPos[3], lineVector[3];
        
        startPos[0] = bulletPos[0] = x;
        startPos[1] = bulletPos[1] = y;
        startPos[2] = bulletPos[2] = z;
        
        GetClientEyePosition(userid, playerPos);
        
        SubtractVectors(playerPos, startPos, lineVector);
        NormalizeVector(lineVector, lineVector);
        ScaleVector(lineVector, g_LaserOffset);
        SubtractVectors(playerPos, lineVector, startPos);
        
        if(!isBot)
        {
            g_LaserColor[0] = GetRandomInt(0, 255);
            g_LaserColor[1] = GetRandomInt(0, 255);
            g_LaserColor[2] = GetRandomInt(0, 255);
            TE_SetupBeamPoints(startPos, bulletPos, g_Sprite, 0, 0, 0, g_LaserLife, g_LaserWidth, g_LaserWidth, 1, 0.0, g_LaserColor, 0);
        }
        else 
        {
            TE_SetupBeamPoints(startPos, bulletPos, g_Sprite, 0, 0, 0, g_LaserLife, g_LaserWidth, g_LaserWidth, 1, 0.0, g_BotsLaserColor, 0);
        }
        
        TE_SendToAll();
    }
    
    return Plugin_Continue;
}