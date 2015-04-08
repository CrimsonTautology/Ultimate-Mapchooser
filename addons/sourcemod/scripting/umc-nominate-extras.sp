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
#include <umc_utils>

#define PLUGIN_VERSION "0.1"
#define PLUGIN_NAME "[UMC] Nomination Extras"

public Plugin:myinfo =
{
    name = PLUGIN_NAME,
    author = "CrimsonTautology",
    description = "Adds extra nomination commands such as !nomgrep and !noms",
    version = PLUGIN_VERSION,
    url = "https://github.com/CrimsonTautology/Ultimate-Mapchooser"
};

new bool:g_VoteCompleted = false;
new bool:g_CanNominate   = false;

new Handle:g_UMCMapCycle = INVALID_HANDLE;
new Handle:g_UMCMapKV    = INVALID_HANDLE;

//Memory queues. Used to store the previously played maps.
new Handle:g_MapMemory     = INVALID_HANDLE;
new Handle:g_GroupMemory = INVALID_HANDLE;

new Handle:g_Cvar_CycleFile = INVALID_HANDLE;
new Handle:g_Cvar_GroupExclude = INVALID_HANDLE;
new Handle:g_Cvar_MapExclude = INVALID_HANDLE;

public OnPluginStart()
{
    LoadTranslations("ultimate-mapchooser.phrases");

    CreateConVar("sm_umc_nominate_extras_version", PLUGIN_VERSION, PLUGIN_NAME, FCVAR_PLUGIN | FCVAR_SPONLY | FCVAR_REPLICATED | FCVAR_NOTIFY | FCVAR_DONTRECORD);

    g_Cvar_CycleFile = FindConVar("sm_umc_nominate_cyclefile");
    g_Cvar_GroupExclude = FindConVar("sm_umc_nominate_groupexclude");
    g_Cvar_MapExclude = FindConVar("sm_umc_nominate_mapexclude");

    RegConsoleCmd("sm_nomsearch", Command_Nomgrep, "Search the map list for a given search key");
    RegConsoleCmd("sm_nomgrep", Command_Nomgrep, "Search the map list for a given search key");
    RegConsoleCmd("sm_noms", Command_Noms, "Display list of nominated maps to players.");

    //Initialize our memory arrays
    new cells = ByteCountToCells(MAP_LENGTH);
    g_MapMemory     = CreateArray(cells);
    g_GroupMemory = CreateArray(cells);
}

public OnConfigsExecuted()
{
    g_CanNominate = ReloadMapcycle();
    g_VoteCompleted = false;

    //Add the map to all the memory queues.
    decl String:current_map[MAP_LENGTH], String:current_group[MAP_LENGTH];
    GetCurrentMap(current_map, sizeof(current_map));
    UMC_GetCurrentMapGroup(current_group, sizeof(current_group));

    new maps = GetConVarInt(g_Cvar_MapExclude);
    new groups = GetConVarInt(g_Cvar_GroupExclude);
    AddToMemoryArray(current_map, g_MapMemory, maps);
    AddToMemoryArray(current_group, g_GroupMemory, (maps > groups) ? maps : groups);
}

public Action:Command_Nomgrep(client, args)
{
    if(!client) return Plugin_Handled;

    if(HasVoteCompleted())
    {
        ReplyToCommand(client, "\x03[UMC]\x01 %t", "No Nominate Nextmap");
        return Plugin_Handled;
    }

    if (args == 0) {
        ReplyToCommand(client, "\x03[UMC]\x01 Nomgrep Incorrect Syntax:  !nomsearch <searchstring>");
        return Plugin_Handled;
    }

    new String:search_key[MAP_LENGTH], found;
    GetCmdArg(1, search_key, sizeof(search_key));

    if(!MapSearch(client, search_key))
    {
        ReplyToCommand(client, "\x03[UMC]\x01 No maps were found matching '%s'", search_key);
        return Plugin_Handled;
    }

    return Plugin_Handled;
}

public Action:Command_Noms(client, args)
{
    if (HasVoteCompleted())
    {
        decl String:map[MAP_LENGTH];
        GetNextMap(map, sizeof(map));
        PrintToChatAll("\x03[UMC]\x01 %t", "End of Map Vote Map Won", map);
        return Plugin_Handled;
    }

    DisplayNominatedMaps();

    return Plugin_Handled;
}

//Called when UMC has set a next map.
public UMC_OnNextmapSet(Handle:kv, const String:map[], const String:group[], const String:display[])
{
    g_VoteCompleted = true;
}

//Called when UMC has extended a map.
public UMC_OnMapExtended()
{
    g_VoteCompleted = false;
}

//Called when UMC requests that the mapcycle should be reloaded.
public UMC_RequestReloadMapcycle()
{
    g_CanNominate = ReloadMapcycle();
}

//Reloads the mapcycle. Returns true on success, false on failure.
bool:ReloadMapcycle()
{
    //Grab the file name from the cvar.
    decl String:filename[PLATFORM_MAX_PATH];
    GetConVarString(g_Cvar_CycleFile, filename, sizeof(filename));

    //Get the kv handle from the file.
    if(g_UMCMapCycle != INVALID_HANDLE) CloseHandle(g_UMCMapCycle);
    g_UMCMapCycle = GetKvFromFile(filename, "umc_rotation");

    if (g_UMCMapCycle == INVALID_HANDLE)
    {
        LogError("SETUP: Mapcycle failed to load!(extras)");
        return false;
    }

    if(g_UMCMapKV != INVALID_HANDLE) CloseHandle(g_UMCMapKV);
    g_UMCMapKV = CreateKeyValues("umc_rotation");
    KvCopySubkeys(g_UMCMapCycle, g_UMCMapKV);
    FilterMapcycleFromArrays(g_UMCMapKV, g_MapMemory, g_GroupMemory, GetConVarInt(g_Cvar_GroupExclude));

    return g_UMCMapCycle != INVALID_HANDLE && g_UMCMapKV != INVALID_HANDLE;
}


public bool:MapSearch(client, const String:search_key[])
{
    new String:map[MAP_LENGTH], String:group[MAP_LENGTH];
    new Handle:menu = CreateMenu(NominationMenuHandler);

    if (!KvGotoFirstSubKey(g_UMCMapKV)) return false;

    //Iterate through the Map Key Value structure
    do
    {
        KvGetSectionName(g_UMCMapKV, group, sizeof(group));
        if (!KvGotoFirstSubKey(g_UMCMapKV)) continue;

        do
        {
            KvGetSectionName(g_UMCMapKV, map, sizeof(map));
            if(StrContains(map, search_key, false) >= 0)
            {
                AddMenuItem(menu,
                        map,
                        map,
                        UMC_IsMapNominated(map, group) ? ITEMDRAW_DISABLED : ITEMDRAW_DEFAULT
                        );
            }

        } while (KvGotoNextKey(g_UMCMapKV));

        KvGoBack(g_UMCMapKV);
    } while (KvGotoNextKey(g_UMCMapKV));
    KvGoBack(g_UMCMapKV);

    if(GetMenuItemCount(menu) <=0) return false;

    //Try and display this new menu
    SetMenuTitle(menu, "%T", "Nomination Menu Title", client);
    DisplayMenu(menu, client, MENU_TIME_FOREVER);

    return true;
}

//Called when the client has picked an item in the nomination menu.
public NominationMenuHandler(Handle:menu, MenuAction:action, client, param2)
{
    switch (action)
    {
        case MenuAction_Select: //The client has picked something.
            {
                //Get the selected map.
                decl String:map[MAP_LENGTH], String:group[MAP_LENGTH];
                GetMenuItem(menu, param2, map, sizeof(map));
                //GetArrayString(nom_menu_groups[client], param2, group, sizeof(group));
                KvFindGroupOfMap(g_UMCMapCycle, map, group, sizeof(group));

                KvRewind(g_UMCMapKV);

                //Nominate it.
                UMC_NominateMap(g_UMCMapKV, map, group, client);

                //Display a message.
                decl String:name[MAX_NAME_LENGTH];
                GetClientName(client, name, sizeof(name));
                PrintToChatAll("\x03[UMC]\x01 %t", "Player Nomination", name, map);
                LogUMCMessage("%s has nominated '%s' from group '%s'", name, map, group);
            }
        case MenuAction_End: CloseHandle(menu);
    }
}

//Ugh
public DisplayNominatedMaps()
{
    new String:map[MAP_LENGTH], String:group[MAP_LENGTH], count=0;
    new Handle:menu = CreateMenu(NominationMenuHandler);

    if (!KvGotoFirstSubKey(g_UMCMapKV)) return;

    //Iterate through the Map Key Value structure
    do
    {
        KvGetSectionName(g_UMCMapKV, group, sizeof(group));
        if (!KvGotoFirstSubKey(g_UMCMapKV)) continue;

        do
        {
            KvGetSectionName(g_UMCMapKV, map, sizeof(map));
            if(UMC_IsMapNominated(map, group))
            {
                count++;
                PrintToChatAll("\x03[UMC]\x01 %d. %s (%s)", (count+1), map, group);
                PrintToConsole(0, "[UMC] %d. %s (%s)", (count+1), map, group);
            }

        } while (KvGotoNextKey(g_UMCMapKV));

        KvGoBack(g_UMCMapKV);
    } while (KvGotoNextKey(g_UMCMapKV));
    KvGoBack(g_UMCMapKV);

    if(count == 0)
    {
        //nothing nominated
        PrintToChatAll("\x03[UMC]\x01 -empty-");
        PrintToConsole(0, "[UMC] -empty-");
    }

}

public bool:HasVoteCompleted()
{
    return g_VoteCompleted;
}

public bool:CanNominate()
{
    return g_CanNominate;
}
