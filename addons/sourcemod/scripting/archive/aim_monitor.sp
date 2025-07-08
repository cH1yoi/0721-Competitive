/*
 * 新增霰弹枪完整数据
 * 将角度计算改为帧计算*(角度向量)
 * 然后越来感觉越像一坨屎xd
 * 等待大佬优化叭,造屎糕手
*/

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <left4dhooks>
#include <logger>

#pragma semicolon 1
#pragma newdecls required

#define CMD_LENGTH 128
#define MAX_BUFFER_LENGTH 1024
#define MAX_ADJUSTMENT_RECORD 32

// 存储击杀数据的结构体
enum struct AimData {
    float delta;          // 最大角度变化
    float total_delta;    // 总角度变化
    int attackTicks;      // 攻击用的tick数
    float distance;       // 距离
    float latency;        // 延迟
    float packetLoss;     // 丢包率
}

// 角度变化数据结构
enum struct AngleData {
    float pitch;          // 俯仰角变化
    float yaw;           // 水平角变化
    float magnitude;     // 变化幅度
    float direction;     // 变化方向(弧度)
    float time;          // 变化时间点
}

// 伤害事件数据结构
enum struct DamageData {
    int client;          // 造成伤害的玩家
    char targetInfo[64]; // 目标信息
    char weapon[32];     // 武器名称
    bool headshot;       // 是否爆头
    float damage;        // 伤害量
    float distance;      // 距离
    int attackTicks;     // 攻击用的tick数
    float delta;         // 最大角度变化
    float total_delta;   // 总角度变化
    float latency;       // 延迟
    float packetLoss;    // 丢包率
}

// 击杀事件数据结构 (继承自伤害数据)
enum struct KillData {
    int client;          // 击杀者
    int victim;          // 被击杀者
    char targetInfo[64]; // 目标信息
    char weapon[32];     // 武器名称
    char shotType[32];   // 射击类型
    bool headshot;       // 是否爆头
    float distance;      // 距离
    int attackTicks;     // 攻击用的tick数
    float delta;         // 最大角度变化
    float total_delta;   // 总角度变化
    float latency;       // 延迟
    float packetLoss;    // 丢包率
}

// 散弹枪射击数据结构
enum struct ShotgunShot {
    float shotTime;           // 射击时间
    float aimAngles[3];      // 射击时的瞄准角度
    int pelletHits;          // 命中弹丸数
    float totalDamage;       // 总伤害
    bool hasHeadshot;        // 是否包含爆头
    float targetPos[3];      // 目标位置
    float shooterPos[3];     // 射击者位置
    AngleData preAimData;    // 射击前的瞄准数据
    AimData aimData;         // 瞄准数据
    char weapon[32];         // 武器名称
}

// 全局变量
Logger log;
float g_PlayerAngles[MAXPLAYERS + 1][CMD_LENGTH][3];  // 玩家角度历史记录
float g_PlayerTimes[MAXPLAYERS + 1][CMD_LENGTH];      // 玩家时间历史记录
int g_PlayerButtons[MAXPLAYERS + 1][CMD_LENGTH];      // 玩家按键历史记录
int g_PlayerIndex[MAXPLAYERS + 1];                    // 玩家历史记录索引
bool g_IsMonitored[MAXPLAYERS + 1];                   // 玩家是否被监控
int g_MonitoringAdmin[MAXPLAYERS + 1];                // 监控该玩家的管理员

// 角度分析相关变量
AngleData g_AdjustmentHistory[MAXPLAYERS + 1][MAX_ADJUSTMENT_RECORD];
int g_AdjustmentCount[MAXPLAYERS + 1];
int g_LastAdjustmentIndex[MAXPLAYERS + 1];

// 散弹枪相关变量
ShotgunShot g_LastShotgunShot[MAXPLAYERS + 1];
bool g_IsShotgunShooting[MAXPLAYERS + 1];
float g_PreShotAngles[MAXPLAYERS + 1][8][3];
int g_PreShotIndex[MAXPLAYERS + 1];

// 插件信息
public Plugin myinfo = {
    name = "Aim Monitor",
    author = "Hana",
    description = "Monitor player aim data",
    version = "1.8",
    url = "https://steamcommunity.com/profiles/76561197983870853/"
};

// 插件启动时注册命令和事件
public void OnPluginStart() {
    RegAdminCmd("sm_monitor", Command_Monitor, ADMFLAG_GENERIC, "开始监控指定玩家");
    RegAdminCmd("sm_mt", Command_Monitor, ADMFLAG_GENERIC, "开始监控指定玩家");
    RegAdminCmd("sm_unmonitor", Command_Unmonitor, ADMFLAG_GENERIC, "停止监控指定玩家");
    RegAdminCmd("sm_unmt", Command_Unmonitor, ADMFLAG_GENERIC, "停止监控指定玩家");
    
    HookEvent("player_death", Event_PlayerDeath);
    HookEvent("player_hurt", Event_PlayerHurt);

    log = new Logger("aim_monitor", LoggerType_NewLogFile);
}

// 地图开始时重置所有监控状态
public void OnMapStart() {
    for(int i = 1; i <= MaxClients; i++) {
        g_IsMonitored[i] = false;
        g_MonitoringAdmin[i] = 0;
        g_PlayerIndex[i] = 0;
        g_AdjustmentCount[i] = 0;
        g_LastAdjustmentIndex[i] = 0;
        g_IsShotgunShooting[i] = false;
        g_PreShotIndex[i] = 0;
        SDKUnhook(i, SDKHook_PostThinkPost, OnPlayerPostThinkPost);
    }
}

// 玩家断开连接时清理监控状态
public void OnClientDisconnect(int client) {
    g_IsMonitored[client] = false;
    g_MonitoringAdmin[client] = 0;
    g_PlayerIndex[client] = 0;
    g_AdjustmentCount[client] = 0;
    g_LastAdjustmentIndex[client] = 0;
    g_IsShotgunShooting[client] = false;
    g_PreShotIndex[client] = 0;
    SDKUnhook(client, SDKHook_PostThinkPost, OnPlayerPostThinkPost);
}

// 玩家进入服务器时初始化状态
public void OnClientPutInServer(int client) {
    g_IsMonitored[client] = false;
    g_MonitoringAdmin[client] = 0;
    g_AdjustmentCount[client] = 0;
    g_LastAdjustmentIndex[client] = 0;
}

// 开始监控命令处理
public Action Command_Monitor(int client, int args) {
    if(args < 1) {
        ReplyToCommand(client, "[SM] 用法: sm_monitor <#userid|name>");
        return Plugin_Handled;
    }
    
    char arg[64];
    GetCmdArg(1, arg, sizeof(arg));
    
    char target_name[MAX_TARGET_LENGTH];
    int target_list[MAXPLAYERS], target_count;
    bool tn_is_ml;
    
    if((target_count = ProcessTargetString(
        arg,
        client,
        target_list,
        MAXPLAYERS,
        COMMAND_FILTER_NO_IMMUNITY,
        target_name,
        sizeof(target_name),
        tn_is_ml)) <= 0) {
        ReplyToTargetError(client, target_count);
        return Plugin_Handled;
    }
    
    for(int i = 0; i < target_count; i++) {
        int target = target_list[i];
        if(g_IsMonitored[target]) {
            PrintToChat(client, "\x01[\x04Aim Info\x01] \x03%N\x01 已经在被监控了", target);
            continue;
        }
        
        g_IsMonitored[target] = true;
        g_MonitoringAdmin[target] = client;
        g_PlayerIndex[target] = 0;
        SDKHook(target, SDKHook_PostThinkPost, OnPlayerPostThinkPost);
        PrintToChat(client, "\x01[\x04Aim Info\x01] 开始监控 \x03%N", target);
    }
    
    return Plugin_Handled;
}

// 停止监控命令处理
public Action Command_Unmonitor(int client, int args) {
    if(args < 1) {
        ReplyToCommand(client, "[SM] 用法: sm_unmonitor <#userid|name>");
        return Plugin_Handled;
    }
    
    char arg[64];
    GetCmdArg(1, arg, sizeof(arg));
    
    char target_name[MAX_TARGET_LENGTH];
    int target_list[MAXPLAYERS], target_count;
    bool tn_is_ml;
    
    if((target_count = ProcessTargetString(
        arg,
        client,
        target_list,
        MAXPLAYERS,
        COMMAND_FILTER_NO_IMMUNITY,
        target_name,
        sizeof(target_name),
        tn_is_ml)) <= 0) {
        ReplyToTargetError(client, target_count);
        return Plugin_Handled;
    }
    
    for(int i = 0; i < target_count; i++) {
        int target = target_list[i];
        if(!g_IsMonitored[target]) {
            PrintToChat(client, "\x01[\x04Aim Info\x01] \x03%N\x01 没有被监控", target);
            continue;
        }
        
        g_IsMonitored[target] = false;
        g_MonitoringAdmin[target] = 0;
        SDKUnhook(target, SDKHook_PostThinkPost, OnPlayerPostThinkPost);
        PrintToChat(client, "\x01[\x04Aim Info\x01] 停止监控 \x03%N", target);
    }
    
    return Plugin_Handled;
}

// 玩家死亡事件处理
public void Event_PlayerDeath(Event event, const char[] name, bool dontBroadcast) {
    int victim = GetClientOfUserId(event.GetInt("userid"));
    int attacker = GetClientOfUserId(event.GetInt("attacker"));
    bool headshot = event.GetBool("headshot");
    
    if(!IsValidClient(attacker) || !g_IsMonitored[attacker])
        return;
        
    char weapon[32];
    event.GetString("weapon", weapon, sizeof(weapon));
    
    float distance = 0.0;
    if(IsValidClient(victim)) {
        float pos1[3], pos2[3];
        GetClientEyePosition(attacker, pos1);
        GetClientEyePosition(victim, pos2);
        distance = GetVectorDistance(pos1, pos2);
    }
    
    int fallback_index = g_PlayerIndex[attacker];
    
    float delta = 0.0, total_delta = 0.0;
    int ind, shotindex = -1;
    bool foundShot = false;
    int attackTicks = 0;
    
    char targetInfo[64];
    int zombieClass = GetEntProp(victim, Prop_Send, "m_zombieClass");
    if(zombieClass < 1 || zombieClass > 6) {
        return;
    }
    
    char className[32];
    GetZombieClassName(zombieClass, className, sizeof(className));
    Format(targetInfo, sizeof(targetInfo), "%N(%s)", victim, className);
    
    // 分析玩家的瞄准数据
    ind = g_PlayerIndex[attacker];
    for(int i = 0; i < time_to_ticks(1.0); i++) {
        if(--ind < 0)
            ind = CMD_LENGTH - 1;
            
        if(GetGameTime() - g_PlayerTimes[attacker][ind] > 1.0)
            break;
            
        if(g_PlayerButtons[attacker][ind] & IN_ATTACK) {
            foundShot = true;
            attackTicks++;
            
            if(shotindex == -1)
                shotindex = ind;
        }
        else if(foundShot) {
            break;
        }
        
        if(i > 0 && shotindex != -1) {
            int nextInd = (ind + 1) % CMD_LENGTH;
            float tdelta = GetAngleDelta(g_PlayerAngles[attacker][ind], g_PlayerAngles[attacker][nextInd]);
            if(tdelta > delta)
                delta = tdelta;
            total_delta += tdelta;
        }
    }
    
    if(shotindex == -1) {
        shotindex = fallback_index;
    }

    // 构建击杀数据
    KillData data;
    data.client = attacker;
    data.victim = victim;
    data.headshot = headshot;
    strcopy(data.weapon, sizeof(data.weapon), weapon);
    data.distance = distance;
    data.attackTicks = attackTicks;
    data.delta = delta;
    data.total_delta = total_delta;
    strcopy(data.targetInfo, sizeof(data.targetInfo), targetInfo);
    data.latency = GetClientLatency(attacker, NetFlow_Both);
    data.packetLoss = GetClientAvgLoss(attacker, NetFlow_Both);

    if(attackTicks <= 1)
        Format(data.shotType, sizeof(data.shotType), "[1shot]%s", headshot ? "[爆头]" : "");
    else
        Format(data.shotType, sizeof(data.shotType), "%s", headshot ? "[爆头]" : "");

    int admin = g_MonitoringAdmin[attacker];
    if(!IsValidClient(admin))
        return;
        
    PrintKillData(admin, data);
    LogKillData(data);
}

// 玩家受伤事件处理
public void Event_PlayerHurt(Event event, const char[] name, bool dontBroadcast) {
    int victim = GetClientOfUserId(event.GetInt("userid"));
    int attacker = GetClientOfUserId(event.GetInt("attacker"));
    
    if(!IsValidClient(attacker) || !g_IsMonitored[attacker])
        return;
        
    char weapon[32];
    event.GetString("weapon", weapon, sizeof(weapon));
    
    // 处理散弹枪伤害
    if(IsShotgunWeapon(weapon)) {
        ProcessShotgunDamage(event, attacker, victim, weapon);
        return;
    }
    
    float distance = 0.0;
    if(IsValidClient(victim)) {
        float pos1[3], pos2[3];
        GetClientEyePosition(attacker, pos1);
        GetClientEyePosition(victim, pos2);
        distance = GetVectorDistance(pos1, pos2);
    }
    
    int fallback_index = g_PlayerIndex[attacker];
    
    float delta = 0.0, total_delta = 0.0;
    int ind, shotindex = -1;
    bool foundShot = false;
    int attackTicks = 0;
    
    char targetInfo[64];
    int zombieClass = GetEntProp(victim, Prop_Send, "m_zombieClass");
    if(zombieClass < 1 || zombieClass > 6) {
        return;
    }
    
    char className[32];
    GetZombieClassName(zombieClass, className, sizeof(className));
    Format(targetInfo, sizeof(targetInfo), "%N(%s)", victim, className);
    
    // 分析玩家的瞄准数据
    ind = g_PlayerIndex[attacker];
    for(int i = 0; i < time_to_ticks(1.0); i++) {
        if(--ind < 0)
            ind = CMD_LENGTH - 1;
            
        if(GetGameTime() - g_PlayerTimes[attacker][ind] > 1.0)
            break;
            
        if(g_PlayerButtons[attacker][ind] & IN_ATTACK) {
            foundShot = true;
            attackTicks++;
            
            if(shotindex == -1)
                shotindex = ind;
        }
        else if(foundShot) {
            break;
        }
        
        if(i > 0 && shotindex != -1) {
            int nextInd = (ind + 1) % CMD_LENGTH;
            float tdelta = GetAngleDelta(g_PlayerAngles[attacker][ind], g_PlayerAngles[attacker][nextInd]);
            if(tdelta > delta)
                delta = tdelta;
            total_delta += tdelta;
        }
    }
    
    if(shotindex == -1) {
        shotindex = fallback_index;
    }

    // 构建伤害数据
    DamageData data;
    data.client = attacker;
    strcopy(data.targetInfo, sizeof(data.targetInfo), targetInfo);
    strcopy(data.weapon, sizeof(data.weapon), weapon);
    data.headshot = (event.GetInt("hitgroup") == 1);
    data.damage = event.GetFloat("dmg_health");
    data.distance = distance;
    data.attackTicks = attackTicks;
    data.delta = delta;
    data.total_delta = total_delta;
    data.latency = GetClientLatency(attacker, NetFlow_Both);
    data.packetLoss = GetClientAvgLoss(attacker, NetFlow_Both);

    int admin = g_MonitoringAdmin[attacker];
    if(!IsValidClient(admin))
        return;
        
    PrintDamageData(admin, data);
    LogDamageData(data);
}

// 玩家移动后处理
public Action OnPlayerPostThinkPost(int client) {
    if(!g_IsMonitored[client])
        return Plugin_Continue;
        
    float angles[3];
    GetClientEyeAngles(client, angles);
    float currentTime = GetGameTime();
    
    // 记录角度历史
    int index = g_PlayerIndex[client];
    g_PlayerAngles[client][index] = angles;
    g_PlayerTimes[client][index] = currentTime;
    g_PlayerButtons[client][index] = GetClientButtons(client);
    
    // 分析角度变化
    if(index > 0) {
        int prevIndex = (index - 1 + CMD_LENGTH) % CMD_LENGTH;
        AnalyzeAimAdjustment(client, g_PlayerAngles[client][prevIndex], angles, currentTime);
    }
    
    // 记录射击前角度
    int preIndex = g_PreShotIndex[client];
    g_PreShotAngles[client][preIndex] = angles;
    g_PreShotIndex[client] = (preIndex + 1) % 8;
    
    if(++index >= CMD_LENGTH)
        index = 0;
    g_PlayerIndex[client] = index;
    
    return Plugin_Continue;
}

// 分析角度变化
void AnalyzeAimAdjustment(int client, float oldAngles[3], float newAngles[3], float time) {
    float pitchDelta = newAngles[0] - oldAngles[0];
    float yawDelta = newAngles[1] - oldAngles[1];
    
    while(yawDelta > 180.0) yawDelta -= 360.0;
    while(yawDelta < -180.0) yawDelta += 360.0;
    
    float magnitude = SquareRoot(pitchDelta * pitchDelta + yawDelta * yawDelta);
    if(magnitude < 0.1) return;
    
    float direction = ArcTangent2(yawDelta, pitchDelta);
    
    int index = g_LastAdjustmentIndex[client];
    g_AdjustmentHistory[client][index].pitch = pitchDelta;
    g_AdjustmentHistory[client][index].yaw = yawDelta;
    g_AdjustmentHistory[client][index].magnitude = magnitude;
    g_AdjustmentHistory[client][index].direction = direction;
    g_AdjustmentHistory[client][index].time = time;
    
    g_LastAdjustmentIndex[client] = (index + 1) % MAX_ADJUSTMENT_RECORD;
    g_AdjustmentCount[client]++;
}

// 获取瞄准调整统计
void GetAimAdjustmentStats(int client, float &avgAdjustment, float &maxAdjustment, int &adjustCount) {
    avgAdjustment = 0.0;
    maxAdjustment = 0.0;
    adjustCount = 0;
    
    float currentTime = GetGameTime();
    for(int i = 0; i < MAX_ADJUSTMENT_RECORD; i++) {
        if(currentTime - g_AdjustmentHistory[client][i].time > 1.0) continue;
        
        float magnitude = g_AdjustmentHistory[client][i].magnitude;
        if(magnitude > 0.1) {
            avgAdjustment += magnitude;
            if(magnitude > maxAdjustment) maxAdjustment = magnitude;
            adjustCount++;
        }
    }
    
    if(adjustCount > 0) {
        avgAdjustment /= float(adjustCount);
    }
}

// 处理散弹枪伤害
void ProcessShotgunDamage(Event event, int attacker, int victim, const char[] weapon) {
    float currentTime = GetGameTime();
    
    if(!g_IsShotgunShooting[attacker]) {
        // 新的散弹枪射击
        g_IsShotgunShooting[attacker] = true;
        g_LastShotgunShot[attacker].shotTime = currentTime;
        g_LastShotgunShot[attacker].pelletHits = 1;
        g_LastShotgunShot[attacker].totalDamage = event.GetFloat("dmg_health");
        g_LastShotgunShot[attacker].hasHeadshot = (event.GetInt("hitgroup") == 1);
        
        GetClientEyePosition(attacker, g_LastShotgunShot[attacker].shooterPos);
        GetClientEyePosition(victim, g_LastShotgunShot[attacker].targetPos);
        GetClientEyeAngles(attacker, g_LastShotgunShot[attacker].aimAngles);
        
        // 分析最近8帧的瞄准数据
        float maxDelta = 0.0, totalDelta = 0.0;
        int currentIndex = g_PreShotIndex[attacker];
        for(int i = 0; i < 8; i++) {
            int prevIndex = (currentIndex - i - 1 + 8) % 8;
            float delta = GetAngleDelta(g_PreShotAngles[attacker][prevIndex], g_PreShotAngles[attacker][currentIndex]);
            maxDelta = maxDelta > delta ? maxDelta : delta;
            totalDelta += delta;
        }
        
        // 记录瞄准调整数据和武器信息
        strcopy(g_LastShotgunShot[attacker].weapon, 32, weapon);
        g_LastShotgunShot[attacker].preAimData.magnitude = maxDelta;
        g_LastShotgunShot[attacker].preAimData.direction = totalDelta;  // 存储总角度变化
        g_LastShotgunShot[attacker].preAimData.time = currentTime;
        
        CreateTimer(0.1, Timer_FinishShotgunShot, attacker);
    } else {
        // 同一次射击的后续伤害
        g_LastShotgunShot[attacker].pelletHits++;
        g_LastShotgunShot[attacker].totalDamage += event.GetFloat("dmg_health");
        g_LastShotgunShot[attacker].hasHeadshot = g_LastShotgunShot[attacker].hasHeadshot || (event.GetInt("hitgroup") == 1);
    }
}

// 散弹枪射击完成定时器
public Action Timer_FinishShotgunShot(Handle timer, any client) {
    if(!g_IsShotgunShooting[client]) return Plugin_Stop;
    
    int admin = g_MonitoringAdmin[client];
    if(IsValidClient(admin)) {
        // 输出到聊天
        float avgAdjustment = 0.0, maxAdjustment = 0.0;
        int adjustCount = 0;
        GetAimAdjustmentStats(client, avgAdjustment, maxAdjustment, adjustCount);
        
        PrintToChat(admin, "\x01[\x04Aim Info\x01] \x03%N\x01 散弹枪数据 | 命中:\x04%d\x01 伤害:\x04%.1f\x01 爆头:\x04%s\x01 距离:\x04%.1f\x01 角度变化:\x04%.1f度/帧\x01 最大变化:\x04%.1f度\x01",
            client,
            g_LastShotgunShot[client].pelletHits,
            g_LastShotgunShot[client].totalDamage,
            g_LastShotgunShot[client].hasHeadshot ? "是" : "否",
            GetVectorDistance(g_LastShotgunShot[client].shooterPos, g_LastShotgunShot[client].targetPos),
            avgAdjustment,
            maxAdjustment);
    }
    
    // 记录日志
    CreateTimer(0.1, Timer_LogShotgunData, client);
    
    g_IsShotgunShooting[client] = false;
    return Plugin_Stop;
}

// 输出伤害数据到聊天
void PrintDamageData(int admin, DamageData data) {
    float avgAdjustment = 0.0, maxAdjustment = 0.0;
    int adjustCount = 0;
    GetAimAdjustmentStats(data.client, avgAdjustment, maxAdjustment, adjustCount);

    PrintToChat(admin, "\x01[\x04Aim Info\x01] \x03%N\x01 伤害 \x04%s\x01 | 伤害:\x04%.1f\x01 射击Tick:\x04%d\x01 角度变化:\x04%.1f度/帧\x01 最大变化:\x04%.1f度\x01",
        data.client,
        data.targetInfo,
        data.damage,
        data.attackTicks,
        avgAdjustment,
        maxAdjustment);
}

public Action Timer_LogShotgunData(Handle timer, any client) {
    LogShotgunData(client, g_LastShotgunShot[client]);
    return Plugin_Stop;
}

void LogShotgunData(int client, ShotgunShot shot) {
    float avgAdjustment = 0.0, maxAdjustment = 0.0;
    int adjustCount = 0;
    GetAimAdjustmentStats(client, avgAdjustment, maxAdjustment, adjustCount);
    
    log.info(
        "[%N] 散弹枪数据 命中:%d 伤害:%.1f 爆头:%s 距离:%.1f 角度变化:%.1f°/帧 最大变化:%.1f° 延迟:%dms/%.1f%%",
        client,
        shot.pelletHits,
        shot.totalDamage,
        shot.hasHeadshot ? "是" : "否",
        GetVectorDistance(shot.shooterPos, shot.targetPos),
        avgAdjustment,
        maxAdjustment,
        RoundToNearest(GetClientLatency(client, NetFlow_Both) * 1000.0),
        GetClientAvgLoss(client, NetFlow_Both));
}

// 记录伤害数据到日志
void LogDamageData(DamageData data) {
    if(!IsValidClient(data.client)) {
        return;
    }
    
    float avgAdjustment = 0.0, maxAdjustment = 0.0;
    int adjustCount = 0;
    GetAimAdjustmentStats(data.client, avgAdjustment, maxAdjustment, adjustCount);
    
    log.info(
        "[%N] 伤害数据 目标:%s 武器:<%s%s> 伤害:%.1f 距离:%.1f 射击Tick:%d 角度变化:%.1f°/帧 最大变化:%.1f° 延迟:%dms/%.1f%%",
        data.client,
        data.targetInfo,
        data.weapon,
        data.headshot ? "[爆头]" : "",
        data.damage,
        data.distance,
        data.attackTicks,
        avgAdjustment,
        maxAdjustment,
        RoundToNearest(data.latency * 1000.0),
        data.packetLoss);
}

// 输出击杀数据到聊天
void PrintKillData(int admin, KillData data) {
    float avgAdjustment = 0.0, maxAdjustment = 0.0;
    int adjustCount = 0;
    GetAimAdjustmentStats(data.client, avgAdjustment, maxAdjustment, adjustCount);

    float score = CalculateAimScore(data.weapon, data.delta, data.distance, data.attackTicks, data.headshot);
    
    // 区分散弹枪和其他武器的显示
    if(IsShotgunWeapon(data.weapon)) {
        PrintToChat(admin, "\x01[\x04Aim Info\x01] \x01[\x04评分:%.1f\x01] \x03%N\x01 击杀 \x04%s\x01 | 距离:\x04%.1f\x01 角度变化:\x04%.1f度/帧\x01 最大变化:\x04%.1f度\x01",
            score,
            data.client,
            data.targetInfo,
            data.distance,
            avgAdjustment,
            maxAdjustment);
    } else {
        PrintToChat(admin, "\x01[\x04Aim Info\x01] \x01[\x04评分:%.1f\x01] \x03%N\x01 击杀 \x04%s\x01 | 射击Tick:\x04%d\x01 角度变化:\x04%.1f度/帧\x01 最大变化:\x04%.1f度\x01",
            score,
            data.client,
            data.targetInfo,
            data.attackTicks,
            avgAdjustment,
            maxAdjustment);
    }
}

// 记录击杀数据到日志
void LogKillData(KillData data) {
    if(!IsValidClient(data.client)) {
        return;
    }
    
    char timeStr[32];
    FormatTime(timeStr, sizeof(timeStr), "%Y-%m-%d %H:%M:%S", GetTime());
    
    float score = CalculateAimScore(data.weapon, data.delta, data.distance, data.attackTicks, data.headshot);
    
    float avgAdjustment = 0.0, maxAdjustment = 0.0;
    int adjustCount = 0;
    GetAimAdjustmentStats(data.client, avgAdjustment, maxAdjustment, adjustCount);
    
    log.info(
        "[评分:%.1f] [%N] 击杀数据 目标:%s 武器:<%s%s> 距离:%.1f 射击Tick:%d 角度变化:%.1f度/帧 最大变化:%.1f度 延迟:%dms/%.1f%%",
        score,
        data.client,
        data.targetInfo,
        data.weapon,
        data.shotType,
        data.distance,
        data.attackTicks,
        avgAdjustment,
        maxAdjustment,
        RoundToNearest(data.latency * 1000.0),
        data.packetLoss);
}

// 判断是否是散弹枪
bool IsShotgunWeapon(const char[] weapon) {
    return (StrEqual(weapon, "shotgun_chrome", false) || 
            StrEqual(weapon, "pumpshotgun", false) || 
            StrEqual(weapon, "autoshotgun", false) || 
            StrEqual(weapon, "shotgun_spas", false));
}

// 获取特感类名
void GetZombieClassName(int zombieClass, char[] buffer, int maxlen) {
    switch(zombieClass) {
        case 1: strcopy(buffer, maxlen, "Smoker");
        case 2: strcopy(buffer, maxlen, "Boomer");
        case 3: strcopy(buffer, maxlen, "Hunter");
        case 4: strcopy(buffer, maxlen, "Spitter");
        case 5: strcopy(buffer, maxlen, "Jockey");
        case 6: strcopy(buffer, maxlen, "Charger");
        case 7: strcopy(buffer, maxlen, "Witch");
        case 8: strcopy(buffer, maxlen, "Tank");
        default: strcopy(buffer, maxlen, "Unknown");
    }
}

// 计算tick数
int time_to_ticks(float time) {
    if (time > 0.0)
        return RoundToNearest(time / GetTickInterval());
    return 0;
}

// 计算角度变化
float GetAngleDelta(float angles1[3], float angles2[3]) {
    float p1[3], p2[3], delta;
    
    p1[0] = angles1[0]; // pitch
    p1[1] = angles1[1]; // yaw
    p2[0] = angles2[0];
    p2[1] = angles2[1];
    
    p1[2] = 0.0;
    p2[2] = 0.0;
    
    delta = GetVectorDistance(p1, p2);
    
    int normal = 5;
    while (delta > 180.0 && normal > 0) {
        normal--;
        delta = FloatAbs(delta - 360.0);
    }
    
    return delta;
}

float CalculateAimScore(const char[] weapon, float delta, float distance, int attackTicks, bool headshot) {
    float score = 100.0;
    
    if(IsShotgunWeapon(weapon)) {
        // 散弹枪评分计算
        if(distance < 100.0) {
            score *= 0.8;
        } else if(distance < 300.0) {
            score *= 1.0;
        } else {
            score *= 1.2 + (distance - 300.0) / 500.0;
        }
        
        if(headshot) {
            score *= 1.2;  // 爆头加成
        }
        
        return score;
    }
    else {
        // 其他武器评分计算
        if(distance < 150.0) {
            score *= 0.6;
        } else if(distance < 400.0) {
            score *= 1.0;
        } else if(distance < 800.0) {
            score *= 1.3;
        } else {
            score *= 1.5;
        }
        
        if(attackTicks <= 2 && delta > 2.0) {
            score *= 1.4;
        }
    }
    
    // 爆头加分
    if(headshot) {
        float headshotMultiplier = 1.0 + (distance / 500.0);
        score *= headshotMultiplier;
    }
    
    // 大角度调整加分
    if(delta > 3.0) {
        score *= 1.0 + (delta - 3.0) * 0.1;
    }
    
    return score;
}

// 检查客户端是否有效
bool IsValidClient(int client) {
    return (client > 0 && client <= MaxClients && IsClientInGame(client));
}