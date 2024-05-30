bool survivalActive = false;
bool resetTimerStopped = true;
int survivalTime = 60;
int currentTime = 0;
int resetTime = 5;
CCVar@ cvar_survive;


CScheduledFunction@ g_pThinkFunc = null;
CScheduledFunction@ g_pThinkFuncTwo = null;
 
void PluginInit() {
	g_Module.ScriptInfo.SetAuthor("Sebastian");
	g_Module.ScriptInfo.SetContactInfo("Smoke Weed");
	g_Hooks.RegisterHook( Hooks::Game::MapChange, @MapChange );
	g_Hooks.RegisterHook(Hooks::Player::PlayerTakeDamage, @PlayerTakeDamage);
	g_Hooks.RegisterHook(Hooks::Player::PlayerSpawn, @PlayerSpawn);
	g_Hooks.RegisterHook(Hooks::Player::PlayerKilled, @PlayerKilled);
	g_Hooks.RegisterHook(Hooks::Player::ClientConnected, @ClientConnected);

	@cvar_survive = CCVar("survive", 1, "Janky survival", ConCommandFlag::AdminOnly);
	
	if (g_pThinkFunc !is null) {
		g_Scheduler.RemoveTimer(g_pThinkFunc);
		resetTimerStopped = true;
	}
 	if (g_pThinkFuncTwo !is null)  g_Scheduler.RemoveTimer(g_pThinkFuncTwo); 
	
	@g_pThinkFunc = g_Scheduler.SetInterval("displaySurvival", 1);
	@g_pThinkFuncTwo = g_Scheduler.SetInterval("NPC_KILL", 1);

	for (int i = 1; i <= g_Engine.maxClients; i++) {
		CBasePlayer@ plr = g_PlayerFuncs.FindPlayerByIndex(i);
		if (plr !is null ){
			Observer@ obs = plr.GetObserver();
			obs.StopObserver(true);
		} 
	}
	
}

HookReturnCode MapChange()
{
	survivalActive = false;
	currentTime = 0;
	return HOOK_CONTINUE;
}


HookReturnCode WeaponPrimaryAttack(CBasePlayer@ pPlayer, CBasePlayerWeapon@ wep) {
	if (wep is null) return HOOK_CONTINUE;

	if (wep.GetClassname() == "weapon_medkit") {
		int ammo = pPlayer.m_rgAmmo(12);
		if(ammo>=5){
			for (int i = 1; i <= g_Engine.maxClients; i++) {
				CBasePlayer@ plr = g_PlayerFuncs.FindPlayerByIndex(i);
				if (plr !is null && (plr.entindex() != pPlayer.entindex()) ){
					Vector dist = pPlayer.EyePosition().opSub(plr.EyePosition());
					float fDist = abs(dist.opIndex(0)) + abs(dist.opIndex(1)) + abs(dist.opIndex(2));
					if(fDist<75.0){
						plr.TakeHealth(3,0,100);
						ammo-=5;
						pPlayer.m_rgAmmo(12,ammo);
					}
				} 
		    }
		}
		return HOOK_HANDLED;
	}
	return HOOK_CONTINUE;
}


void NPC_KILL(){
	g_EngineFuncs.ServerCommand( "mp_npckill 1\n");
	g_EngineFuncs.ServerExecute();
}


void displaySurvival(){
	if(g_SurvivalMode.IsEnabled()==false &&  cvar_survive.GetInt() == 1){
		if(currentTime<survivalTime){
			int oucurrentTime = survivalTime - currentTime;
			for (int i = 1; i <= g_Engine.maxClients; i++) {
				CBasePlayer@ plr = g_PlayerFuncs.FindPlayerByIndex(i);
				if (plr !is null){
					g_EngineFuncs.ClientPrintf(plr, print_center, "Survival mode starting in "+string(oucurrentTime)+" seconds");
				} 
			}
		}
		if(currentTime==survivalTime){
			g_PlayerFuncs.ClientPrintAll(HUD_PRINTTALK, "Survival mode now active. No more respawning allowed.");
			survivalActive = true;
			if (resetTimerStopped && survivalActive  && checkPlayersDead()) {
				@g_pThinkFunc = g_Scheduler.SetInterval("mapChanger", resetTime);
			}
		}
	}
	currentTime+=1;


}

bool checkPlayersDead(){
	int reset = 1;
	int playerHit = 0;
		for (int i = 1; i <= g_Engine.maxClients; i++) {
			CBasePlayer@ plr = g_PlayerFuncs.FindPlayerByIndex(i);
			if (plr !is null && plr.IsAlive()==true ){
				reset=0;
			} 
			if (plr !is null){
				playerHit=1;
			}
		}
	if(reset==1 && playerHit==1){
		return(true);
	}
	return(false);
}

void mapChanger(){
	if(g_SurvivalMode.IsEnabled()==false &&  cvar_survive.GetInt() == 1 && currentTime >= survivalTime){
		if(checkPlayersDead()){
			g_EngineFuncs.ChangeLevel(string(g_Engine.mapname));
		}
	}
	g_Scheduler.RemoveTimer(g_pThinkFunc);
	resetTimerStopped = true;
}



HookReturnCode PlayerTakeDamage( DamageInfo@ pDamageInfo ) {
	CBasePlayer@ plr = cast<CBasePlayer@>(g_EntityFuncs.Instance(pDamageInfo.pVictim.pev));
	CBaseEntity@ attacker = pDamageInfo.pAttacker;

	//g_PlayerFuncs.ClientPrintAll(HUD_PRINTTALK, "damage info");
	//g_PlayerFuncs.ClientPrintAll(HUD_PRINTTALK, pDamageInfo.bitsDamageType );
	//g_PlayerFuncs.ClientPrintAll(HUD_PRINTTALK, pDamageInfo.flDamage);
	
	if(attacker.IsPlayer() && attacker.m_iClassSelection == plr.m_iClassSelection){
		plr.TakeHealth(-pDamageInfo.flDamage,0,100);
	} else {
		if(!attacker.IsPlayer() && attacker.IsPlayerAlly()){
			plr.TakeHealth(-pDamageInfo.flDamage,0,100);
		}
	}
	
	return HOOK_CONTINUE;
}



HookReturnCode PlayerSpawn( CBasePlayer@ pPlayer) {

	if(survivalActive && g_SurvivalMode.IsEnabled()==false && cvar_survive.GetInt() == 1){
		Observer@ obs = pPlayer.GetObserver();
		obs.SetObserverModeControlEnabled( true );
		obs.StartObserver(pPlayer.GetOrigin(), pPlayer.pev.angles, false);
		obs.SetObserverModeControlEnabled( true );
		pPlayer.pev.nextthink = 10000000.0;
		return HOOK_HANDLED;
	}else{
		return HOOK_CONTINUE;
	}
}

HookReturnCode PlayerKilled( CBasePlayer@ pPlayer, CBaseEntity@ pAttacker, int iGib ) {
	if (resetTimerStopped && survivalActive  && checkPlayersDead()) {
		@g_pThinkFunc = g_Scheduler.SetInterval("mapChanger", resetTime);
	}
	return HOOK_CONTINUE;

}

HookReturnCode ClientConnected(CBasePlayer@ plr){
	if (resetTimerStopped && survivalActive && checkPlayersDead()) {
		@g_pThinkFunc = g_Scheduler.SetInterval("mapChanger", resetTime);
	}
	return HOOK_CONTINUE;
}
