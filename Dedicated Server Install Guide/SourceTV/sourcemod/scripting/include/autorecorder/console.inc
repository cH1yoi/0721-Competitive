#if defined _autorecorder_console_included
  #endinput
#endif
#define _autorecorder_console_included

#include <autorecorder/logic>

public Action sm_recordstatus(int client, int args)
{
    if (!SourceTV_IsActive()) {
        ReplyToCommand(client, "SourceTV is not active.");
        
        return Plugin_Handled;
    }

    if (!SourceTV_IsRecording()) {
        ReplyToCommand(client, "SourceTV is not recording.");
        
        return Plugin_Handled;
    }
    
    char szLength[64];
    Util_FormatSeconds(szLength, sizeof(szLength), RoundToCeil(GetTickInterval() * SourceTV_GetRecordingTick()));
    
    char szSize[64];
    Util_FormatBytes(szSize, sizeof(szSize), FileSize(g_szDemoPath));
    
    ReplyToCommand(client, "Recording to \"%s\" (length: %s, size: %s)", g_szDemoPath, szLength, szSize);

    return Plugin_Handled;
}

void Console_Init()
{
    RegAdminCmd("sm_recordstatus", sm_recordstatus, ADMFLAG_ROOT, "sm_recordstatus - Show recording information.");
}
