#include <karyuu>
#include <smoke_api>

/*		 _   ___ _
/		| | / (_) |
/		| |/ / _| |_ ___ _   _ _ __   ___
/		|    \| | __/ __| | | | '_ \ / _ \
/		| |\  \ | |_\__ \ |_| | | | |  __/
/		\_| \_/_|\__|___/\__,_|_| |_|\___|
*/

#pragma semicolon 1
#pragma newdecls required

/* Important: There is no plugin-info for this project to remain unvisible, because it makes no sense to see. */

/*		______ _             _
/		| ___ \ |           (_)
/		| |_/ / |_   _  __ _ _ _ __
/		|  __/| | | | |/ _` | | '_ \
/		| |   | | |_| | (_| | | | | |
/		\_|   |_|\__,_|\__, |_|_| |_|
/		                __/ |
/		               |___/
*/

enum struct SmokePack
{
	int		 Smoke_Owner;
		int	 Smoke_Team;
		int	 Smoke_Particle;
		Handle Smoke_DeleteTimer;
		Handle Smoke_CheckPlayers;
}

ArrayList g_hThrownGrenades;

bool		 g_bInCheckPlayers,
	g_bIsClientInSmoke[MAXPLAYERS + 1] = { false, ... };

Handle g_hForward_OnClientEnterSmoke  = INVALID_HANDLE,
		 g_hForward_OnClientLeaveSmoke  = INVALID_HANDLE;

public void OnPluginStart()
{
	g_hThrownGrenades = CreateArray(sizeof(SmokePack));

	HookEvent("smokegrenade_detonate", Kitsune_DetonateSmoke, EventHookMode_Pre);

	g_hForward_OnClientEnterSmoke = CreateGlobalForward("Kitsune_OnClientEnterSmoke", ET_Ignore, Param_Cell);
	g_hForward_OnClientLeaveSmoke = CreateGlobalForward("Kitsune_OnClientLeaveSmoke", ET_Ignore, Param_Cell);

	CreateNative("Kitsune_IsPlayerInSmoke", Native_Kitsune_IsPlayerInSmoke);
}

public void OnMapEnd()
{
	g_hThrownGrenades.Clear();
}

public int Native_Kitsune_IsPlayerInSmoke(Handle h_Plugin, int iNumParameters)
{
	int client = GetNativeCell(1);
	if (Karyuu_IsValidClient(client))	// This also allow bots to be detected
	{
		return g_bIsClientInSmoke[client];
	}
	else
		return ThrowNativeError(SP_ERROR_NATIVE, "Invalid client index (%d)", client);
}

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	RegPluginLibrary("kit_detect_smoke");
	return APLRes_Success;
}

public void Kitsune_DetonateSmoke(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	if (client == INVALID_ENT_REFERENCE || !IsClientInGame(client))
		return;

	SmokePack iSmoke;
	iSmoke.Smoke_Owner		  = GetClientUserId(client);
	iSmoke.Smoke_Team			  = GetClientTeam(client);
	iSmoke.Smoke_Particle	  = INVALID_ENT_REFERENCE;
	iSmoke.Smoke_DeleteTimer  = null;
	iSmoke.Smoke_CheckPlayers = null;

	int ent						  = event.GetInt("entityid");
	int entityRef				  = EntIndexToEntRef(ent);

	iSmoke.Smoke_Particle	  = entityRef;
	iSmoke.Smoke_DeleteTimer  = CreateTimer(18.0, Timer_StopChecks, entityRef, TIMER_FLAG_NO_MAPCHANGE);
	iSmoke.Smoke_CheckPlayers = CreateTimer(0.5, Timer_CheckPlayers, entityRef, TIMER_FLAG_NO_MAPCHANGE | TIMER_REPEAT);

	g_hThrownGrenades.PushArray(iSmoke);
}

public Action Timer_CheckPlayers(Handle timer, any entityref)
{
	int entity = EntRefToEntIndex(entityref);
	if (entity == INVALID_ENT_REFERENCE)
		return Plugin_Continue;

	int		 iSize = GetArraySize(g_hThrownGrenades);
	SmokePack iSmoke;
	bool		 bFound;
	for (int i = 0; i < iSize; i++)
	{
		g_hThrownGrenades.GetArray(i, iSmoke);
		if (iSmoke.Smoke_Particle == entityref)
		{
			bFound = true;
			break;
		}
	}

	if (!bFound)
		return Plugin_Continue;

	int client = GetClientOfUserId(iSmoke.Smoke_Owner);
	if (!client)
		return Plugin_Continue;

	g_bInCheckPlayers = true;

	float fParticleOrigin[3], fPlayerOrigin[3];
	GetEntPropVector(entity, Prop_Send, "m_vecOrigin", fParticleOrigin);

	KARYUU_LOOP_PLAYERS(client_loop)
	{
		if (IsPlayerAlive(client_loop))
		{
			GetClientAbsOrigin(client_loop, fPlayerOrigin);
			if (GetVectorDistance(fParticleOrigin, fPlayerOrigin) <= 220)
			{
				if (!g_bIsClientInSmoke[client_loop])
				{
					g_bIsClientInSmoke[client_loop] = true;

					Call_StartForward(g_hForward_OnClientEnterSmoke);
					Call_PushCell(client_loop);
					int ignore;
					Call_Finish(view_as<int>(ignore));
				}
			}
			else
			{
				if (g_bIsClientInSmoke[client_loop])
				{
					g_bIsClientInSmoke[client_loop] = false;

					Call_StartForward(g_hForward_OnClientLeaveSmoke);
					Call_PushCell(client_loop);
					int ignore;
					Call_Finish(view_as<int>(ignore));
				}
			}
		}
	}

	if (!g_bInCheckPlayers)
		return Plugin_Stop;

	g_bInCheckPlayers = false;
	return Plugin_Continue;
}

public void Event_OnResetSmokes(Event event, const char[] name, bool dontBroadcast)
{
	int		 iSize = GetArraySize(g_hThrownGrenades);
	SmokePack iSmoke;
	for (int iGrenade = 0; iGrenade < iSize; iGrenade++)
	{
		g_hThrownGrenades.GetArray(iGrenade, iSmoke);

		if (Karyuu_IsValidHandle(iSmoke.Smoke_DeleteTimer))
			delete iSmoke.Smoke_DeleteTimer;

		if (!g_bInCheckPlayers && Karyuu_IsValidHandle(iSmoke.Smoke_DeleteTimer))
			delete iSmoke.Smoke_CheckPlayers;
	}
	g_hThrownGrenades.Clear();

	if (g_bInCheckPlayers)
		g_bInCheckPlayers = false;
}

public Action Timer_StopChecks(Handle timer, any entityref)
{
	int		 iSize = GetArraySize(g_hThrownGrenades);
	SmokePack iSmoke;
	for (int iGrenade = 0; iGrenade < iSize; iGrenade++)
	{
		g_hThrownGrenades.GetArray(iGrenade, iSmoke);

		if (iSmoke.Smoke_Particle == entityref)
		{
			delete iSmoke.Smoke_CheckPlayers;

			g_hThrownGrenades.Erase(iGrenade);
			break;
		}
	}

	return Plugin_Stop;
}