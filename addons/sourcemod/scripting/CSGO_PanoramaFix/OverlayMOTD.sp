ConVar g_ConVar_OverlayMOTDEnable;
bool g_bOverlayMOTDEnable = false;
Handle g_cOverlayMOTDState = INVALID_HANDLE;
bool g_bOverlayMOTDState[MAXPLAYERS+1];
Handle g_hTimerOverlayMOTD[MAXPLAYERS+1] = {INVALID_HANDLE, ...};
int g_iIsClientShowingOverlayMOTD[MAXPLAYERS+1] = -1;
ConVar g_ConVar_OverlayMOTDMaterial[7];
char g_szOverlayMOTDMaterial[7][128];
bool g_bCalledJoinOverlayMOTD[MAXPLAYERS+1] = {false, ...};
bool g_bDisabledHTMLMOTD[MAXPLAYERS+1] = {false, ...};

//----------------------------------------------------------------------------------------------------
// Purpose: General
//----------------------------------------------------------------------------------------------------
void OnPluginStart_OverlayMOTD() {
	g_ConVar_OverlayMOTDEnable = CreateConVar("sm_overlaymotd_enable", "0", "Enable/Disable the Overlay MOTD Functions", _, true, 0.0, true, 1.0);
	g_ConVar_OverlayMOTDEnable.AddChangeHook(OnConVarChanged_OverlayMOTD);
	g_bOverlayMOTDEnable = g_ConVar_OverlayMOTDEnable.BoolValue;
	g_cOverlayMOTDState = RegClientCookie("overlaymotd_cookie", "State of the Overlay MOTD", CookieAccess_Protected);

	RegConsoleCmd("sm_motd", Command_ShowOverlayMOTD);

	for (int x = 0; x < 7; x++) {
		char sConVar[128];
		FormatEx(sConVar, sizeof(sConVar), "sm_overlaymotd_material_%i", x);
		g_ConVar_OverlayMOTDMaterial[x] = CreateConVar(sConVar, "", "");
		g_ConVar_OverlayMOTDMaterial[x].AddChangeHook(OnConVarChanged_OverlayMOTD);
		g_ConVar_OverlayMOTDMaterial[x].GetString(g_szOverlayMOTDMaterial[x], sizeof(g_szOverlayMOTDMaterial[]));
	}
}

public void OnConVarChanged_OverlayMOTD(ConVar convar, const char[] oldValue, const char[] newValue) {
	if (convar == g_ConVar_OverlayMOTDEnable)
		g_bOverlayMOTDEnable = view_as<bool>(StringToInt(newValue));
	for (int x = 0; x < 7; x++) {
		if (convar == g_ConVar_OverlayMOTDMaterial[x])
			g_ConVar_OverlayMOTDMaterial[x].GetString(g_szOverlayMOTDMaterial[x], sizeof(g_szOverlayMOTDMaterial[]));
	}
}

void OnClientConnected_OverlayMOTD(int client) {
	g_bOverlayMOTDState[client] = false;
	g_hTimerOverlayMOTD[client] = INVALID_HANDLE;
	g_iIsClientShowingOverlayMOTD[client] = -1;
	g_bCalledJoinOverlayMOTD[client] = false;
}

void OnClientPostAdminCheck_OverlayMOTD(int client) {
	HTMLMOTDCheck(client);
}

void OnClientDisconnect_OverlayMOTD(int client) {
	g_bOverlayMOTDState[client] = false;
	if (g_hTimerOverlayMOTD[client] != INVALID_HANDLE) {
		KillTimer(g_hTimerOverlayMOTD[client]);
	}
	g_hTimerOverlayMOTD[client] = INVALID_HANDLE;
	g_iIsClientShowingOverlayMOTD[client] = -1;
	g_bCalledJoinOverlayMOTD[client] = false;
}

void OnClientCookiesCached_OverlayMOTD(int client) {
	char sValue[32];
	GetClientCookie(client, g_cOverlayMOTDState, sValue, sizeof(sValue));
	//PrintToServer("  -- %N: %s", client, sValue);
	char sToday[16];
	FormatTime(sToday, sizeof(sToday), "%y%m%d", GetTime());
	if (sValue[0] == '\0') {
		FormatEx(sValue, sizeof(sValue), "1%s", sToday);
		SetClientCookie(client, g_cOverlayMOTDState, sValue);
	} else {
		//PrintToServer("   >> %s", sValue[1]);
		if (!StrEqual(sValue[1], sToday, false)) {
			FormatEx(sValue, sizeof(sValue), "1%s", sToday);
			SetClientCookie(client, g_cOverlayMOTDState, sValue);
		}
	}
	g_bOverlayMOTDState[client] = (strncmp(sValue, "1", 1, false) == 0) ? true : false;
	//PrintToServer("  => %s", (strncmp(sValue, "1", 1, false) == 0) ? "true" : "false");
}

void HTMLMOTDCheck(int client) {
	g_bDisabledHTMLMOTD[client] = false;
	QueryClientConVar(client, "cl_disablehtmlmotd", ClientConVarHTMLMOTD);
}

public void ClientConVarHTMLMOTD(QueryCookie cookie, int client, ConVarQueryResult result, const char[] cvarName, const char[] cvarValue) {
	//PrintToServer("  - [QueryClientConVar] %N => result: %i, %s: %s", client, result, cvarName, cvarValue);
	if (result != ConVarQuery_Okay) {
		g_bDisabledHTMLMOTD[client] = true;
		return;
	}
	g_bDisabledHTMLMOTD[client] = view_as<bool>(StringToInt(cvarValue));
	return;
}

public Action Command_ShowOverlayMOTD(int client, int args) {
	if (client < 1 || client > MaxClients || !IsClientConnected(client) || !IsClientInGame(client)) return Plugin_Handled;
	ShowOverlayMOTD(client);
	return Plugin_Handled;
}

void ShowOverlayMOTD(int client) {
	if (g_hTimerOverlayMOTD[client] != INVALID_HANDLE)
		StopOverlayMOTD(client);
	g_iIsClientShowingOverlayMOTD[client] = 0;
	Timer_ShowOverlayMOTD(null, client);
	g_hTimerOverlayMOTD[client] = CreateTimer(1.0, Timer_ShowOverlayMOTD, client, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
}

void StopOverlayMOTD(int client) {
	if (g_hTimerOverlayMOTD[client] != INVALID_HANDLE) {
		KillTimer(g_hTimerOverlayMOTD[client]);
	}
	g_hTimerOverlayMOTD[client] = INVALID_HANDLE;
	ClientCommand(client, "r_screenoverlay \"\"");
	g_iIsClientShowingOverlayMOTD[client] = -1;
	ClearMenu_OverlayMOTD(client);
}

bool IsClientShowingOverlayMOTD(int client) {
	if (g_iIsClientShowingOverlayMOTD[client] > -1)
		return true;
	return false;
}

public Action Timer_ShowOverlayMOTD(Handle timer, int client) {
	if (!IsClientConnected(client) || !IsClientInGame(client) || !IsClientShowingOverlayMOTD(client)) {
		g_hTimerOverlayMOTD[client] = INVALID_HANDLE;
		return Plugin_Stop;
	}

	ClientCommand(client, "r_screenoverlay \"%s\"", g_szOverlayMOTDMaterial[g_iIsClientShowingOverlayMOTD[client]]);
	Menu_OverlayMOTD(client);

	return Plugin_Continue;
}

void Menu_OverlayMOTD(int client) {
	Panel hPanel = new Panel();
	char sBuffer[256];

	hPanel.SetTitle("[pS] MOTD");

	//hPanel.DrawItem("------------------------", ITEMDRAW_RAWLINE);

	for (int x = 0; x < 7; x++) {
		FormatEx(sBuffer, sizeof(sBuffer), " ");
		if (g_szOverlayMOTDMaterial[x][0] != '\0')
			hPanel.DrawItem(sBuffer);
		else hPanel.DrawItem("", ITEMDRAW_SPACER);
	}

	if (g_bOverlayMOTDState[client])
		hPanel.DrawItem("Do not display today");				// 8
	else
		hPanel.DrawItem("Enable MOTD when join");				// 8
	hPanel.DrawItem("Close", ITEMDRAW_CONTROL);					// 9

	hPanel.Send(client, PanelHandler_Main, MENU_TIME_FOREVER);

	CloseHandle(hPanel);
}

public int PanelHandler_Main(Menu hMenu, MenuAction action, int client, int param2) {
	switch (action) {
		case MenuAction_Display: {
			// ToDo
		}
		case MenuAction_End: {
			EmitSoundToClient(client, "buttons/combine_button7.wav");
			//PrintToChat(client, "  Panel -> MenuAction_End");
			delete hMenu;
		}
		case MenuAction_Cancel: {
			//PrintToChat(client, "  Panel -> MenuAction_Cancel");
			if (param2 == MenuCancel_ExitBack) {
				// ToDo
			}
		}
		case MenuAction_Select: {
			switch (param2) {
				case 8: {
					char sToday[16], sValue[32];
					FormatTime(sToday, sizeof(sToday), "%y%m%d", GetTime());
					g_bOverlayMOTDState[client] = !g_bOverlayMOTDState[client];
					FormatEx(sValue, sizeof(sValue), "%i%s", g_bOverlayMOTDState[client], sToday);
					SetClientCookie(client, g_cOverlayMOTDState, sValue);
					EmitSoundToClient(client, "buttons/button14.wav");
					if (!g_bOverlayMOTDState[client]) {
						if (g_bCalledJoinOverlayMOTD[client]) {
							g_bCalledJoinOverlayMOTD[client] = false;
							StopOverlayMOTD(client);
							if (IsClientUsePanorama(client))
								ChangeClientTeam(client, CS_TEAM_CT);
							else {
								ShowVGUIPanel(client, "team");
								g_hClientTimer[client] = CreateTimer(FindConVar("mp_force_pick_time").FloatValue, Timer_ForcePick, client, TIMER_FLAG_NO_MAPCHANGE);
							}
						} else Menu_OverlayMOTD(client);
					}
					else Menu_OverlayMOTD(client);
				}
				case 9: {
					EmitSoundToClient(client, "buttons/combine_button7.wav");
					StopOverlayMOTD(client);
					if (g_bCalledJoinOverlayMOTD[client]) {
						g_bCalledJoinOverlayMOTD[client] = false;
						if (IsClientUsePanorama(client))
							ChangeClientTeam(client, CS_TEAM_CT);
						else {
							ShowVGUIPanel(client, "team");
							g_hClientTimer[client] = CreateTimer(FindConVar("mp_force_pick_time").FloatValue, Timer_ForcePick, client, TIMER_FLAG_NO_MAPCHANGE);
						}
					}
				}
				default: {
					g_iIsClientShowingOverlayMOTD[client] = param2 - 1;
					ClientCommand(client, "r_screenoverlay \"%s\"", g_szOverlayMOTDMaterial[param2 - 1]);
					EmitSoundToClient(client, "buttons/button14.wav");
					Menu_OverlayMOTD(client);
				}
			}
		}
	}
	return -1;
}

void ClearMenu_OverlayMOTD(int client) {
	Panel hPanel = new Panel();

	hPanel.SetTitle(" ");

	hPanel.Send(client, PanelHandler_Clear, 1);

	CloseHandle(hPanel);
}

public int PanelHandler_Clear(Menu hMenu, MenuAction action, int client, int param2) {
	if (action == MenuAction_End) {
		EmitSoundToClient(client, "buttons/combine_button7.wav");
		//PrintToChat(client, "  Panel -> MenuAction_End");
		delete hMenu;
	}
	return -1;
}