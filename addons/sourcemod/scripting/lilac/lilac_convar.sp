/*
	Little Anti-Cheat
	Copyright (C) 2018-2023 J_Tanzanite

	This program is free software: you can redistribute it and/or modify
	it under the terms of the GNU General Public License as published by
	the Free Software Foundation, either version 3 of the License, or
	(at your option) any later version.

	This program is distributed in the hope that it will be useful,
	but WITHOUT ANY WARRANTY; without even the implied warranty of
	MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
	GNU General Public License for more details.

	You should have received a copy of the GNU General Public License
	along with this program.  If not, see <https://www.gnu.org/licenses/>.
*/


static int query_index[MAXPLAYERS + 1];
static int query_failed[MAXPLAYERS + 1];

/* Structure to store convar validation rules */
enum struct ConvarRule {
    char name[32];
    int expected_value;
    bool is_minimum;  // If true, value must be >= expected_value
}

/* Basic query list. */
static ConvarRule convar_rules[] = {
    {"cl_cmdrate", 10, true},
    {"cl_pitchdown", 89, false},
    {"cl_pitchup", 89, false},
    {"cl_thirdperson", 0, false},
    {"host_limitlocal", 0, false},
    {"host_timescale", 1, false},
    {"mat_fillrate", 0, false},
    {"mat_proxy", 0, false},
    {"mat_wireframe", 0, false},
    {"net_blockmsg", 0, false},
    {"net_droppackets", 0, false},
    {"net_fakejitter", 0, false},
    {"net_fakelag", 0, false},
    {"net_fakeloss", 0, false},
    {"r_ClipAreaPortals", 1, false},
    {"r_colorstaticprops", 0, false},
    {"r_drawmodelstatsoverlay", 0, false},
    {"r_drawothermodels", 1, false},
    {"r_drawparticles", 1, false},
    {"r_drawrenderboxes", 0, false},
    {"r_drawskybox", 1, false},
    {"r_modelwireframedecal", 0, false},
    {"r_portalsopenall", 0, false},
    {"r_shadowwireframe", 0, false},
    {"r_showenvcubemap", 0, false},
    {"r_skybox", 1, false},
    {"snd_show", 0, false},
    {"snd_visualize", 0, false},
    {"sv_cheats", 0, false}
};

void lilac_convar_reset_client(int client)
{
	query_index[client] = 0;
	query_failed[client] = 0;
}

public Action timer_query(Handle timer)
{
	if (!icvar[CVAR_ENABLE] || !icvar[CVAR_CONVAR])
		return Plugin_Continue;

	/* sv_cheats recently changed or is set to 1, abort. */
	if (GetTime() < time_sv_cheats || sv_cheats)
		return Plugin_Continue;

	for (int i = 1; i <= MaxClients; i++) {
		if (!is_player_valid(i) || IsFakeClient(i))
			continue;

		/* Player recently joined, wait before querying. */
		if (GetClientTime(i) < 60.0)
			continue;

		/* Don't query already banned players. */
		if (playerinfo_banned_flags[i][CHEAT_CONVAR])
			continue;

		/* Only increments query index if the player
		 * has responded to the last one. */
		if (!query_failed[i]) {
			if (++query_index[i] >= sizeof(convar_rules))
				query_index[i] = 0;
		}

		QueryClientConVar(i, convar_rules[query_index[i]].name, query_reply, 0);

		if (++query_failed[i] > QUERY_MAX_FAILURES) {
			if (icvar[CVAR_LOG_MISC]) {
				lilac_log_setup_client(i);
				Format(line_buffer, sizeof(line_buffer),
					"%s was kicked for failing to respond to %d queries in %.0f seconds.",
					line_buffer, QUERY_MAX_FAILURES,
					QUERY_TIMER * QUERY_MAX_FAILURES);

				lilac_log(true);

				if (icvar[CVAR_LOG_EXTRA] == 2)
					lilac_log_extra(i);
			}
			database_log(i, "cvar_query_failure", DATABASE_KICK, float(QUERY_MAX_FAILURES), QUERY_TIMER * QUERY_MAX_FAILURES);

			KickClient(i, "[Lilac] %T", "kick_query_failure", i);
		}
	}

	return Plugin_Continue;
}

public void query_reply(QueryCookie cookie, int client, ConVarQueryResult result,
			const char[] cvarName, const char[] cvarValue, any value)
{
	/* Player NEEDS to answer the query. */
	if (result != ConVarQuery_Okay)
		return;

	/* Client did respond to the query request, move on to the next convar. */
	query_failed[client] = 0;

	/* Any response the server may recieve may also be faulty, ignore. */
	if (GetTime() < time_sv_cheats || sv_cheats)
		return;

	/* Already banned. */
	if (playerinfo_banned_flags[client][CHEAT_CONVAR])
		return;

	int val = StringToInt(cvarValue);

	/* Check against convar rules */
	for (int i = 0; i < sizeof(convar_rules); i++) {
		if (StrEqual(convar_rules[i].name, cvarName, false)) {
			if (convar_rules[i].is_minimum) {
				if (val >= convar_rules[i].expected_value)
					return;
			} else {
				if (val == convar_rules[i].expected_value)
					return;
			}
			break;
		}
	}

	if (lilac_forward_allow_cheat_detection(client, CHEAT_CONVAR) == false)
		return;

	char sDetails[512];
	Format(sDetails, sizeof(sDetails), "%s %s", cvarName, cvarValue);

	lilac_save_player_details(client, sDetails);
	lilac_forward_client_cheat(client, CHEAT_CONVAR);

	if (icvar[CVAR_LOG]) {
		lilac_log_setup_client(client);
		Format(line_buffer, sizeof(line_buffer),
			"%s was detected and banned for an invalid ConVar (%s).",
			line_buffer, sDetails);

		lilac_log(true);

		if (icvar[CVAR_LOG_EXTRA])
			lilac_log_extra(client);
	}
	database_log(client, "cvar_invalid", DATABASE_BAN);

	playerinfo_banned_flags[client][CHEAT_CONVAR] = true;
	lilac_ban_client(client, CHEAT_CONVAR);
}