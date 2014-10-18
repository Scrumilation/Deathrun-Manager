#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <csgocolors>
#undef REQUIRE_EXTENSIONS
#include <cstrike>
#include <sdktools>
#include <sdkhooks>
#define REQUIRE_EXTENSIONS

#define MESS  "{GREEN}[{LIGHTGREEN}Zonix{GREEN}] %t"
#define TEAM_T 2
#define TEAM_CT 3
#define PLUGIN_VERSION	 "1.3"
#define MaxClients 20
#define DMG_FALL   (1 << 5)

new Handle:deathrun_manager_version	= INVALID_HANDLE;
new Handle:deathrun_enabled		= INVALID_HANDLE;
new Handle:deathrun_swapteam		= INVALID_HANDLE;
new Handle:deathrun_block_radio		= INVALID_HANDLE;
new Handle:deathrun_block_suicide	= INVALID_HANDLE;
new Handle:deathrun_limit_terror	= INVALID_HANDLE;
new Handle:deathrun_block_sprays	= INVALID_HANDLE;
new Handle:deathrun_fix_spawns		= INVALID_HANDLE;

new Handle:RoundTime			= INVALID_HANDLE;

new RadioCommands[][] =
{
	"coverme",
	"cheer",
	"thanks",
	"compliment",
	"takepoint",
	"holdpos",
	"regroup",
	"followme",
	"takingfire",
	"go",
	"fallback",
	"sticktog",
	"getinpos",
	"stormfront",
	"report",
	"roger",
	"enemyspot",
	"needbackup",
	"sectorclear",
	"inposition",
	"reportingin",
	"getout",
	"negative",
	"enemydown"
};

public Plugin:myinfo =
{
	name = "Deathrun Manager",
	author = "Rogue",
	description = "Manages terrorists/counter-terrorists on DR servers",
	version = PLUGIN_VERSION,
	url = ""
};

public OnPluginStart()
{
	LoadTranslations("deathrun.phrases");
	
	for(new i = 0; i<sizeof(RadioCommands); i++)
	{
		AddCommandListener(BlockRadio, RadioCommands[i]);
		LogMessage("Added the radio command %s to the block list", RadioCommands[i]);
	}
	
	AddCommandListener(BlockKill, "kill");
	AddCommandListener(Cmd_JoinTeam, "jointeam");
	
	AddTempEntHook("Player Decal", PlayerSpray);
	
	HookEvent("round_end", Event_RoundEnd);
	HookEvent("player_spawn", Event_PlayerSpawn);
	HookEvent("player_disconnect", Event_PlayerDisconnect, EventHookMode_Pre);
	
	deathrun_manager_version 	= CreateConVar("deathrun_manager_version", PLUGIN_VERSION, "Deathrun Manager version; not changeable", FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_REPLICATED|FCVAR_NOTIFY|FCVAR_DONTRECORD);
	deathrun_enabled 		= CreateConVar("deathrun_enabled", "1", "Enable or disable Deathrun Manager; 0 - disabled, 1 - enabled");
	deathrun_swapteam 		= CreateConVar("deathrun_swapteam", "1", "Enable or disable automatic swapping of CTs and Ts; 1 - enabled, 0 - disabled");
	deathrun_block_radio 		= CreateConVar("deathrun_block_radio", "1", "Allow or disallow radio commands; 1 - radio commands are blocked, 0 - radio commands can be used");
	deathrun_block_suicide 		= CreateConVar("deathrun_block_suicide", "1", "Block or allow the 'kill' command; 1 - command is blocked, 0 - command is allowed");
	deathrun_limit_terror 		= CreateConVar("deathrun_limit_terror", "0", "Limits terrorist team to chosen value; 0 - disabled");
	deathrun_block_sprays 		= CreateConVar("deathrun_block_sprays", "0", "Blocks player sprays; 1 - enabled, 0 - disabled");
	deathrun_fix_spawns		= CreateConVar("deathrun_fix_spawns", "1", "Fixes glitched spawns on a specific map");
	
	SetConVarString(deathrun_manager_version, PLUGIN_VERSION);
	AutoExecConfig(true, "deathrun_manager");
}

public OnConfigsExecuted()
{
	decl String:mapname[128];
	GetCurrentMap(mapname, sizeof(mapname));
	RoundTime = FindConVar("mp_roundtime");
	
	if (strncmp(mapname, "dr_", 3, false) == 0 || (strncmp(mapname, "deathrun_", 9, false) == 0) || (strncmp(mapname, "dtka_", 5, false) == 0))
	{
		LogMessage("Deathrun map detected. Enabling Deathrun Manager.");
		SetConVarInt(deathrun_enabled, 1);
		SetConVarInt(RoundTime, 999);
	}
	else
	{
		LogMessage("Current map is not a deathrun map. Disabling Deathrun Manager.");
		SetConVarInt(deathrun_enabled, 0);
		SetConVarInt(RoundTime, 0);
	}
}

public OnClientPutInServer(client)
{
	SDKHook(client, SDKHook_OnTakeDamage, OnTakeDamage);
}
				
public Event_RoundEnd(Handle:event, const String:name[], bool:dontBroadcast)
{
	if (GetConVarInt(deathrun_enabled) == 1 && (GetConVarInt(deathrun_swapteam) == 1))
	{
		for (new i=1;i<MaxClients;i++)
		{
			if (IsClientInGame(i) && (GetClientTeam(i) == TEAM_T))
			{
				CS_SwitchTeam(i, TEAM_CT);
			}
		}
		
		if(GetClientCount() < 2)
		{
			//If there's only one player, let him stay as CT
			CPrintToChatAll("{GREEN}[{LIGHTGREEN}DeathRun{GREEN}]{RED}Apenas um jogador no servidor, nenhuma troca de times será feita");
		} 	
		else if(GetClientCount() > 1 && GetClientCount() < (MaxClients / 2)) //If there's more then one player, but less then half of the server capactity send only one player to T
		{
			CS_SwitchTeam(GetRandomPlayer(TEAM_CT), TEAM_T);
			CPrintToChatAll("{GREEN}[{LIGHTGREEN}DeathRun{GREEN}]{RED}Menos de %d jogadores no servidor, apenas um jogador será movido para o time TR", (MaxClients / 2));
		}
		else if(GetClientCount() >= (MaxClients / 2)) //If there's more then half on the server MAX players on, send the number of players specified in deathrun_limit_terror to T
		{
			CPrintToChatAll("{GREEN}[{LIGHTGREEN}DeathRun{GREEN}]{RED}Mais que %d jogadores no servidor, dois jogadores serão movidos para o time TR", (MaxClients / 2));
			CS_SwitchTeam(GetRandomPlayer(TEAM_CT), TEAM_T);// I had it in a loop but for some reason it was not working, so...
			CS_SwitchTeam(GetRandomPlayer(TEAM_CT), TEAM_T);
		}
	}
}

public Action:OnTakeDamage(client, &attacker, &inflictor, &Float:damage, &damagetype)
{
	if ((GetConVarInt(deathrun_enabled) == 0) && (damagetype & DMG_FALL))
	{
		return Plugin_Handled;
	}
return Plugin_Continue;
}

public Action:BlockRadio(client, const String:command[], args)
{
	CPrintToChat(client, MESS, "radio blocked");
	return Plugin_Handled;
}

public Action:BlockKill(client, const String:command[], args)
{
	if (GetConVarInt(deathrun_enabled) == 1 && (GetConVarInt(deathrun_block_suicide) == 1))
	{
		CPrintToChat(client, MESS, "kill blocked");
		return Plugin_Handled;
	}
	else
	{
		return Plugin_Continue;
	}
}

/*  For some reason hooking this command means that you can not use the 'jointeam' command via console.
    Not that it really matters anyway, because the command is hidden. Changing team VIA the GUI
    (pressing M) still works fine though. I know of a way to 'fix' it if it's a major problem for anybody. */ 
public Action:Cmd_JoinTeam(client, const String:command[], args)
{
	if (args == 0)
	{
		return Plugin_Continue;
	}
  
	new argg;
	new String:arg[32];  
	GetCmdArg(1, arg, sizeof(arg));
	argg = StringToInt(arg);
  
	if (GetConVarInt(deathrun_enabled) == 1 && (GetConVarInt(deathrun_limit_terror) > 0) && (argg == 2))
	{
		new teamcount = GetTeamClientCount(TEAM_T);
    
		if (teamcount >= GetConVarInt(deathrun_limit_terror))
		{
			CPrintToChat(client, MESS, "enough ts");
			return Plugin_Handled;
		}
	}
	return Plugin_Continue;
}

public Action:PlayerSpray(const String:te_name[],const clients[],client_count,Float:delay)
{
	new client = TE_ReadNum("m_nPlayer");
  
	if (GetConVarInt(deathrun_enabled) == 1 && (GetConVarInt(deathrun_block_sprays) == 1))
	{
		CPrintToChat(client, MESS, "sprays blocked");
		return Plugin_Handled;
	}
	return Plugin_Continue;
}

GetRandomPlayer(team)
{
	new clients[MaxClients+1], clientCount;
	for (new i = 1; i <= MaxClients; i++)
		if (IsClientInGame(i) && (GetClientTeam(i) == team))
			clients[clientCount++] = i;
	return (clientCount == 0) ? -1 : clients[GetRandomInt(0, clientCount-1)];
}


public Action:Event_PlayerSpawn(Handle:event, const String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	decl String:mapname[128];
	GetCurrentMap(mapname, sizeof(mapname));
	if (GetConVarInt(deathrun_fix_spawns) == 1 && (strncmp(mapname, "deathrun_stone", 14, false) == 0))
	{	
		new Float:Pos[3];
		GetEntPropVector(client, Prop_Send, "m_vecOrigin", Pos);
		if(Pos[2] < 80)
		{
			Pos[2] += 50;
			SetEntPropVector(client, Prop_Send, "m_vecOrigin", Pos);
			CPrintToChat(client, "{GREEN}[{LIGHTGREEN}DeathRun{GREEN}]{BLUE}Voce nasceu bugado e foi desbugado pelo desbugator 5000");
		}
	}
	return Plugin_Continue;
}

EndRound()
{
	CS_TerminateRound(0.1, CSRoundEnd_Draw);
}

public Action:Event_PlayerDisconnect(Handle:event, const String:name[], bool:dontBroadcast)
{
	if(GetConVarInt(deathrun_enabled) == 1 && (GetConVarInt(deathrun_swapteam) == 1))
	{
		new client = GetClientOfUserId(GetEventInt(event, "userid"));
		if((GetClientTeam(client) == TEAM_T) && (GetTeamClientCount(TEAM_T) == 0))
		{
			CPrintToChatAll("{GREEN}[{LIGHTGREEN}DeathRun{GREEN}]Nenhum jogador no time TR, reiniciando o round"); //Sorry for being too lazy to use the translation file :/ translation is: "No player left on the terrorist team, restarting the round".
			EndRound();
		}
	}
	return Plugin_Continue;
}

