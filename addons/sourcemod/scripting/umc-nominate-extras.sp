/**
 * vim: set ts=4 :
 * =============================================================================
 * Ultimate Mapchooser - Nominate Extras
 * Adds extra nomination commands such as !nomgrep and !noms
 *
 * Copyright 2015 CrimsonTautology
 * =============================================================================
 *
 */

#pragma semicolon 1

#include <sourcemod>
#include <umc-core>

#define PLUGIN_VERSION "0.1"
#define PLUGIN_NAME "[UMC] Nomination Extras"

#define MAX_ARG_SIZE 64

public Plugin:myinfo =
{
    name = PLUGIN_NAME,
    author = "CrimsonTautology",
    description = "Adds extra nomination commands such as !nomgrep and !noms",
    version = PLUGIN_VERSION,
    url = "https://github.com/CrimsonTautology/Ultimate-Mapchooser"
};

public OnPluginStart()
{
    LoadTranslations("ultimate-mapchooser.phrases");

    CreateConVar("sm_umc_nominate_extras_version", PLUGIN_VERSION, PLUGIN_NAME, FCVAR_PLUGIN | FCVAR_SPONLY | FCVAR_REPLICATED | FCVAR_NOTIFY | FCVAR_DONTRECORD);

    RegConsoleCmd("sm_test", Command_Test, "TODO: TEST");

    RegConsoleCmd("sm_nomsearch", Command_Nomgrep, "Search the map list for a given search key");
    RegConsoleCmd("sm_nomgrep", Command_Nomgrep, "Search the map list for a given search key");
    RegConsoleCmd("sm_noms", Command_Noms, "Display list of nominated maps to players.");
}

public Action:Command_Test(client, args)
{
    return Plugin_Handled;
}

public Action:Command_Nomgrep(client, args)
{
    if(!client) return Plugin_Handled;

    if (args == 0) {
        ReplyToCommand(client, "\x03[UMC]\x01 Nomgrep Incorrect Syntax:  !nomsearch <searchstring>");
        return Plugin_Handled;
    }

    new String:search_key[MAX_ARG_SIZE], found;
    GetCmdArg(1, search_key, sizeof(search_key));

    found = MapSearch(client, search_key);

    if(!found)
    {
        ReplyToCommand(client, "\x03[UMC]\x01 No maps were found matching '%s'", search_key);
        return Plugin_Handled;
    }

    return Plugin_Handled;
}

public Action:Command_Noms(client, args)
{
    return Plugin_Handled;
}

public bool:MapSearch(client, const String:search_key[])
{
    return false;
}
