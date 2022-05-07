#if defined _SMOKE_API_INCLUDED_
	#endinput
#endif
#define _SMOKE_API_INCLUDED_

public SharedPlugin __pl_Kitsune_SMOKE_DTC =
{
	name = "smoke-api",
	file = "smoke-api.smx",
	#if defined REQUIRE_PLUGIN
	required = 1,
	#else
	required = 0,
	#endif
};

public void __pl_Kitsune_SetNTVOptional()
{
	MarkNativeAsOptional("Kitsune_IsPlayerInSmoke");
}

//Fired when a client enters a smoke
forward void Kitsune_OnClientEnterSmoke(int iClient);

//Fired when a client leaves a smoke
forward void Kitsune_OnClientLeaveSmoke(int iClient);

/**
 * Check if the player is currently in smoke
 *
 * @param iClient				Client index
 * @return						Return true if player is in smoke, otherwise false.
 */
native bool Kitsune_IsPlayerInSmoke(int iClient);