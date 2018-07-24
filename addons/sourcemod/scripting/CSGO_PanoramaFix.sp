#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdkhooks>
#include <sdktools>
#include <cstrike>
#include <clientprefs>
#include <colors_csgo>
#include <CSGO_PanoramaFix>

public Plugin myinfo = {
	name = "Panorama Fix",
	author = "SHUFEN from POSSESSION.tokyo",
	description = "",
	version = "0.1",
	url = "https://possession.tokyo"
}

bool g_bIsPanorama[MAXPLAYERS+1];

/***** Scoreboard Fix *****/
bool g_bInScore[MAXPLAYERS+1] = {false, ...};
bool g_bIsEnabled[MAXPLAYERS+1];
Handle g_Scoreboard;

/***** Team Menu Fix *****/
Handle g_hClientTimer[MAXPLAYERS+1] = INVALID_HANDLE;

bool g_bLateLoad = false;

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max) {
	if (GetEngineVersion() != Engine_CSGO) {
		FormatEx(error, err_max, "The plugin only works on CS:GO");
		return APLRes_Failure;
	}

	RegPluginLibrary("CSGO_PanoramaFix");

	CreateNative("IsClientUsePanorama", Native_IsClientUsePanorama);

	g_bLateLoad = late;
	return APLRes_Success;
}

public void OnPluginStart() {
	LoadTranslations("CSGO_PanoramaFix.phrases");

	RegAdminCmd("sm_panoramacheck", Command_PanoramaCheck, ADMFLAG_GENERIC);

	/***** Scoreboard Fix *****/
	CreateTimer(1.0, Timer_ScoreboardHUD, _, TIMER_REPEAT);
	RegConsoleCmd("sm_moresb", Command_ToggleScoreboard);
	g_Scoreboard = RegClientCookie("scoreboard_gametext_cookie", "Enable/Disable the scoreboard UI", CookieAccess_Protected);

	/***** Team Menu Fix *****/
	HookUserMessage(GetUserMessageId("VGUIMenu"), TeamMenuHook, true);
	AddCommandListener(Command_JoinGame, "joingame");
	AddCommandListener(Command_JoinTeam, "jointeam");

	/***** endmatch_votenextmap Fix *****/
	HookEvent("cs_win_panel_match", Event_cs_win_panel_match);

	SetCookieMenuItem(PrefMenu, 0, "[Panorama] More Info for Scoreboard");

	if (g_bLateLoad) {
		int i = 1;
		while (i <= MaxClients) {
			if (IsClientInGame(i) && !IsFakeClient(i)) {
				//OnClientPostAdminCheck(i);
				PanoramaCheck(i, true);
				OnClientConnected(i);
				if (AreClientCookiesCached(i)) {
					OnClientCookiesCached(i);
				}
			}
			i++;
		}
	}
}

public void OnClientCookiesCached(int client) {
	char sValue[8];
	GetClientCookie(client, g_Scoreboard, sValue, sizeof(sValue));
	if (sValue[0] == '\0') {
		SetClientCookie(client, g_Scoreboard, "1");
		strcopy(sValue, sizeof(sValue), "1");
	}
	g_bIsEnabled[client] = view_as<bool>(StringToInt(sValue));
}

public void OnClientConnected(int client) {
	/***** Scoreboard Fix *****/
	g_bInScore[client] = false;
	/***** Team Menu Fix *****/
	g_hClientTimer[client] = INVALID_HANDLE;
}

public void OnClientDisconnect(int client) {
	/***** Scoreboard Fix *****/
	g_bInScore[client] = false;
	/***** Team Menu Fix *****/
	g_hClientTimer[client] = INVALID_HANDLE;
}

public void OnClientPutInServer(int client) {
	if (!IsFakeClient(client)) {
		ChangeClientTeam(client, CS_TEAM_SPECTATOR);
		//PrintToServer("  - [OnClientPutInServer] %N -> Force Team: 1", client);
	}
}

public void OnClientPostAdminCheck(int client) {
	PanoramaCheck(client);
}

public Action OnPlayerRunCmd(int client, int& buttons, int& impulse, float vel[3], float angles[3], int& weapon, int& subtype, int& cmdnum, int& tickcount, int& seed, int mouse[2]) {
	/***** Scoreboard Fix *****/
	if (buttons & IN_SCORE) {
		if (!g_bInScore[client]) {
			Timer_ScoreboardHUD(null, client);
		}
		g_bInScore[client] = true;
	} else {
		g_bInScore[client] = false;
	}
}

//----------------------------------------------------------------------------------------------------
// Purpose: endmatch_votenextmap Fix
//----------------------------------------------------------------------------------------------------
public void Event_cs_win_panel_match(Event event, const char[] name, bool dontBroadcast) {
	if (FindConVar("mp_endmatch_votenextmap").BoolValue) return;
	for (int x = 0; x <= 9; x++) {
		GameRules_SetProp("m_nEndMatchMapGroupVoteOptions", -1, _, x);
		GameRules_SetProp("m_nEndMatchMapGroupVoteTypes", -1, _, x);
	}
}

//----------------------------------------------------------------------------------------------------
// Purpose: Team Menu Fix
//----------------------------------------------------------------------------------------------------
public Action TeamMenuHook(UserMsg msg_id, Protobuf msg, const int[] players, int playersNum, bool reliable, bool init) {
	char buffermsg[64];

	PbReadString(msg, "name", buffermsg, sizeof(buffermsg));

	if (StrEqual(buffermsg, "team", true)) {
		int client = players[0];

		//Edit: Be warned that if you change the client's team here, it might throw a fatal error and crash the server.
		//	  To prevent it, use RequestFrame and pass the client index through it.

		if (IsClientUsePanorama(client)) {
			//PrintToServer("  - [TeamMenuHook] %N -> Team VGUIMenu: Plugin_Stop", client);
			return Plugin_Stop;
		}
	}

	return Plugin_Continue;
}

public Action Command_JoinGame(int client, const char[] command, int argc) {
	//PrintToServer("  - [Command_JoinGame] %N -> ShowVGUIPanel: \"team\"", client);
	ShowVGUIPanel(client, "team");
	g_hClientTimer[client] = CreateTimer(FindConVar("mp_force_pick_time").FloatValue, Timer_ForcePick, client, TIMER_FLAG_NO_MAPCHANGE);
	return Plugin_Continue;
}

public Action Command_JoinTeam(int client, const char[] command, int argc) {
	if (g_hClientTimer[client] != INVALID_HANDLE) {
		KillTimer(g_hClientTimer[client]);
		g_hClientTimer[client] = INVALID_HANDLE;
	}
	return Plugin_Continue;
}

public Action Timer_ForcePick(Handle timer, int client) {
	if (!IsClientConnected(client) || !IsClientInGame(client)) {
		g_hClientTimer[client] = INVALID_HANDLE;
		return Plugin_Stop;
	}
	ShowVGUIPanel(client, "team", INVALID_HANDLE, false);
	ClientCommand(client, "jointeam 3 1");
	//PrintToServer("  - [Timer_ForcePick] %N -> ClientCommand: \"jointeam 3 1\"", client);
	return Plugin_Continue;
}

//----------------------------------------------------------------------------------------------------
// Purpose: Scoreboard Fix
//----------------------------------------------------------------------------------------------------
public Action Timer_ScoreboardHUD(Handle timer, int caller) {
	if (0 < caller <= MaxClients && (!IsClientConnected(caller) || !IsClientInGame(caller))) {
		return;
	}

	int specslist[MAXPLAYERS+1];
	int specscount = 0;
	int tcount = 0;
	int talive = 0;
	int ctcount = 0;
	int ctalive = 0;

	for (int i = 1; i <= MaxClients; i++) {
		if (!IsClientConnected(i) || !IsClientInGame(i)) continue;
		if (GetClientTeam(i) == CS_TEAM_T) {
			tcount++;
			if (IsPlayerAlive(i)) talive++;
		}
		if (GetClientTeam(i) == CS_TEAM_CT) {
			ctcount++;
			if (IsPlayerAlive(i)) ctalive++;
		}
		else if (GetClientTeam(i) == CS_TEAM_SPECTATOR) specslist[specscount++] = i;
	}

	char txt[255];
	char txt_specs[255];
	char buffer[255];

	int timeleft;
	GetMapTimeLeft(timeleft);

	int mins, secs;

	if (timeleft > 0) {
		/*days = timeleft / 86400;
		hours = (timeleft / 3600) % 24;
		mins = (timeleft / 60) % 60;*/
		mins = timeleft / 60;
		secs = timeleft % 60;
	}

	for (int x = 0; x < specscount; x++) {
		FormatEx(buffer, sizeof(buffer), "\n%N", specslist[x]);
		StrCat(txt_specs, sizeof(txt_specs), buffer);
	}

	if (0 < caller <= MaxClients) {
		if (HasFlags(caller, "b")) {
			if (IsClientUsePanorama(caller)) {
				FormatEx(txt, sizeof(txt), "%T %d:%02d\n%T %i/%i\n%T %i/%i\n\n%i %T:%s", "Timeleft", caller, mins, secs, "CT Players Alive", caller, ctalive, ctcount, "T Players Alive", caller, talive, tcount, specscount, "Spectators", caller, txt_specs);
			} else {
				FormatEx(txt, sizeof(txt), "\n\n%i %T:%s", specscount, "Spectators", caller, txt_specs);
			}
		} else if (IsClientUsePanorama(caller)) {
			FormatEx(txt, sizeof(txt), "%T %d:%02d\n%T %i/%i\n%T %i/%i", "Timeleft", caller, mins, secs, "CT Players Alive", caller, ctalive, ctcount, "T Players Alive", caller, talive, tcount);
		}

		if (g_bIsEnabled[caller]) {
			SetHudTextParamsEx(0.01, 0.37, 1.0, {255, 255, 255, 255}, {0, 0, 0, 255}, 0, 0.0, 0.0, 0.0);
			ShowHudText(caller, 3, txt);
		}
	} else {
		for (int i = 1; i <= MaxClients; i++) {
			if (!IsClientConnected(i) || !IsClientInGame(i)) continue;
			if (g_bInScore[i]) {
				if (HasFlags(i, "b")) {
					if (IsClientUsePanorama(i)) {
						FormatEx(txt, sizeof(txt), "%T %d:%02d\n%T %i/%i\n%T %i/%i\n\n%i %T:%s", "Timeleft", i, mins, secs, "CT Players Alive", i, ctalive, ctcount, "T Players Alive", i, talive, tcount, specscount, "Spectators", i, txt_specs);
					} else {
						FormatEx(txt, sizeof(txt), "\n\n%i %T:%s", specscount, "Spectators", i, txt_specs);
					}
				} else if (IsClientUsePanorama(i)) {
					FormatEx(txt, sizeof(txt), "%T %d:%02d\n%T %i/%i\n%T %i/%i", "Timeleft", i, mins, secs, "CT Players Alive", i, ctalive, ctcount, "T Players Alive", i, talive, tcount);
				}

				if (g_bIsEnabled[i]) {
					SetHudTextParamsEx(0.01, 0.37, 1.0, {255, 255, 255, 255}, {0, 0, 0, 255}, 0, 0.0, 0.0, 0.0);
					ShowHudText(i, 3, txt);
				}
			}
		}
	}
}

//----------------------------------------------------------------------------------------------------
// Purpose: Toggle Command
//----------------------------------------------------------------------------------------------------
public Action Command_ToggleScoreboard(int client, int args) {
	if (client < 1 || client > MaxClients) return Plugin_Handled;
	ToggleScoreboard(client);
	return Plugin_Handled;
}

public void PrefMenu(int client, CookieMenuAction actions, any info, char[] buffer, int maxlen) {
	if (actions == CookieMenuAction_DisplayOption) {
		switch (view_as<int>(g_bIsEnabled[client])) {
			case 0: FormatEx(buffer, maxlen, "%T: %T", "ScoreboardHud", client, "Off", client);
			case 1: FormatEx(buffer, maxlen, "%T: %T", "ScoreboardHud", client, "On", client);
		}
	}

	if (actions == CookieMenuAction_SelectOption) {
		ToggleScoreboard(client);
		ShowCookieMenu(client);
	}
}

void ToggleScoreboard(int client) {
	if (!IsClientUsePanorama(client) && !HasFlags(client, "b")) {
		CPrintToChat(client, "\x04[SM] \x01%t", "NoPanorama");
		return;
	}

	if (g_bIsEnabled[client]) {
		g_bIsEnabled[client] = false;
		char sCookieValue[12];
		IntToString(0, sCookieValue, sizeof(sCookieValue));
		SetClientCookie(client, g_Scoreboard, sCookieValue);
		CPrintToChat(client, "\x04[SM] \x01%t", "OffMsg");
		return;
	}

	g_bIsEnabled[client] = true;
	char sCookieValue[12];
	IntToString(1, sCookieValue, sizeof(sCookieValue));
	SetClientCookie(client, g_Scoreboard, sCookieValue);
	CPrintToChat(client, "\x04[SM] \x01%t", "OnMsg");
}

//----------------------------------------------------------------------------------------------------
// Purpose: Panorama Check
//----------------------------------------------------------------------------------------------------
public Action Command_PanoramaCheck(int client, int args) {
	if (args == 1) {
		char arg1[65];
		GetCmdArg(1, arg1, sizeof(arg1));
		int target = FindTarget(client, arg1, false, false);
		if (target == -1 || !IsClientInGame(target) || IsFakeClient(target)) {
			ReplyToCommand(client, " \x04[SM] \x01Invalid Target");
			return Plugin_Handled;
		}
		ReplyToCommand(client, " \x04[SM] \x05%N \x01is using \x06%s", target, g_bIsPanorama[target] ? "Panorama UI" : "Old UI");
	} else {
		ReplyToCommand(client, " \x04[SM] \x01Usage: sm_panoramacheck <client|#userid>");
	}

	return Plugin_Handled;
}

void PanoramaCheck(int client, bool late = false) {
	g_bIsPanorama[client] = false;
	if (!late)
		QueryClientConVar(client, "@panorama_debug_overlay_opacity", ClientConVar);
	else
		QueryClientConVar(client, "@panorama_debug_overlay_opacity", ClientConVarLate);
}

public void ClientConVar(QueryCookie cookie, int client, ConVarQueryResult result, const char[] cvarName, const char[] cvarValue) {
	if (result != ConVarQuery_Okay) {
		g_bIsPanorama[client] = false;
		ChangeClientTeam(client, CS_TEAM_NONE);
		//PrintToServer("  - [QueryClientConVar] %N -> Force Team: 0", client);
		return;
	} else {
		g_bIsPanorama[client] = true;
		ChangeClientTeam(client, CS_TEAM_CT);
		//PrintToServer("  - [QueryClientConVar] %N -> Force Team: 3", client);
		return;
	}
}

public void ClientConVarLate(QueryCookie cookie, int client, ConVarQueryResult result, const char[] cvarName, const char[] cvarValue) {
	if (result != ConVarQuery_Okay) {
		g_bIsPanorama[client] = false;
		return;
	} else {
		g_bIsPanorama[client] = true;
		return;
	}
}

public int Native_IsClientUsePanorama(Handle plugin, int numParams) {
	return g_bIsPanorama[GetNativeCell(1)];
}

//----------------------------------------------------------------------------------------------------
// Purpose: Stock
//----------------------------------------------------------------------------------------------------
stock bool HasFlags(int client, char[] sFlags) {
	if (StrEqual(sFlags, "public", false) || StrEqual(sFlags, "", false))
		return true;

	if (StrEqual(sFlags, "none", false))
		return false;

	AdminId id = GetUserAdmin(client);
	if (id == INVALID_ADMIN_ID)
		return false;

	if (CheckCommandAccess(client, "sm_not_a_command", ADMFLAG_ROOT, true))
		return true;

	int iCount, iFound, flags;
	if (StrContains(sFlags, ";", false) != -1) //check if multiple strings
	{
		int c = 0, iStrCount = 0;
		while (sFlags[c] != '\0') {
			if (sFlags[c++] == ';')
				iStrCount++;
		}
		iStrCount++; //add one more for IP after last comma
		char[][] sTempArray = new char[iStrCount][30];
		ExplodeString(sFlags, ";", sTempArray, iStrCount, 30);

		for (int i = 0; i < iStrCount; i++) {
			flags = ReadFlagString(sTempArray[i]);
			iCount = 0;
			iFound = 0;
			for (int j = 0; j <= 20; j++) {
				if (flags & (1<<j)) {
					iCount++;

					if (GetAdminFlag(id, view_as<AdminFlag>(j)))
						iFound++;
				}
			}

			if (iCount == iFound)
				return true;
		}
	} else {
		flags = ReadFlagString(sFlags);
		iCount = 0;
		iFound = 0;
		for (int i = 0; i <= 20; i++) {
			if (flags & (1<<i)) {
				iCount++;

				if (GetAdminFlag(id, view_as<AdminFlag>(i)))
					iFound++;
			}
		}

		if (iCount == iFound)
			return true;
	}
	return false;
}