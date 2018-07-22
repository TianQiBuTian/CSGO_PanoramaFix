#if defined _CSGO_PanoramaFix_included
  #endinput
#endif
#define _CSGO_PanoramaFix_included

/**
* Gets if a client is running the panorama UI or scale form UI.
*
* @param client		Client index.
*
* @return 			True if client is using panorama; false otherwise.
*/
native bool IsClientUsePanorama(int client);

public SharedPlugin __pl_CSGO_PanoramaFix = {
	name = "CSGO_PanoramaFix",
	file = "CSGO_PanoramaFix.smx",
#if defined REQUIRE_PLUGIN
	required = 1,
#else
	required = 0,
#endif
};

#if !defined REQUIRE_PLUGIN
public void __pl_CSGO_PanoramaFix_SetNTVOptional() {
	MarkNativeAsOptional("IsClientUsePanorama");
}
#endif