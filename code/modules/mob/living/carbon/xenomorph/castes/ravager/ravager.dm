/mob/living/carbon/xenomorph/ravager
	caste_base_type = /mob/living/carbon/xenomorph/ravager
	name = "Ravager"
	desc = "A huge, nasty red alien with enormous scythed claws."
	icon = 'icons/Xeno/castes/ravager.dmi'
	icon_state = "Ravager Walking"
	health = 250
	maxHealth = 250
	plasma_stored = 50
	mob_size = MOB_SIZE_BIG
	drag_delay = 6 //pulling a big dead xeno is hard
	tier = XENO_TIER_THREE
	upgrade = XENO_UPGRADE_NORMAL
	pixel_x = -16
	old_x = -16
	bubble_icon = "alienroyal"
	var/rage_power
	var/rage = FALSE
	var/on_cooldown = FALSE

/mob/living/carbon/xenomorph/ravager/Initialize(mapload)
	. = ..()
	ADD_TRAIT(src, TRAIT_LIGHT_STEP, XENO_TRAIT)

/mob/living/carbon/xenomorph/ravager/Life()
	. = ..()
	if(health > maxHealth * RAVAGER_RAGE_MIN_HEALTH_THRESHOLD)
		rage = FALSE
		on_cooldown = FALSE
		rage_power = 0
		remove_filter("ravager_rage_outline")
		xeno_melee_damage_modifier = initial(xeno_melee_damage_modifier)
		remove_movespeed_modifier(MOVESPEED_ID_RAVAGER_RAGE)
		REMOVE_TRAIT(src, TRAIT_STUNIMMUNE, RAGE_TRAIT)
		REMOVE_TRAIT(src, TRAIT_SLOWDOWNIMMUNE, RAGE_TRAIT)
		REMOVE_TRAIT(src, TRAIT_STAGGERIMMUNE, RAGE_TRAIT)
		UnregisterSignal(src, COMSIG_XENOMORPH_ATTACK_LIVING)
		return

	var/rage_threshold = maxHealth * (1 - RAVAGER_RAGE_MIN_HEALTH_THRESHOLD)
	rage_power = max(0, (1 - ((health - RAVAGER_ENDURE_HP_LIMIT) / (maxHealth - RAVAGER_ENDURE_HP_LIMIT - rage_threshold))))

	add_filter("ravager_rage_outline", 5, outline_filter(rage_power, COLOR_RED))

	if(!rage)
		RegisterSignal(src, COMSIG_XENOMORPH_ATTACK_LIVING, PROC_REF(drain_slash))
		ADD_TRAIT(src, TRAIT_STUNIMMUNE, RAGE_TRAIT)
		ADD_TRAIT(src, TRAIT_SLOWDOWNIMMUNE, RAGE_TRAIT)
		ADD_TRAIT(src, TRAIT_STAGGERIMMUNE, RAGE_TRAIT)
		rage = TRUE

	xeno_melee_damage_modifier = initial(xeno_melee_damage_modifier) + rage_power
	add_movespeed_modifier(MOVESPEED_ID_RAVAGER_RAGE, TRUE, 0, NONE, TRUE, xeno_caste.speed * 0.5 * rage_power)

	if((health < 0) && !on_cooldown)
		plasma_stored += xeno_caste.plasma_max
		var/datum/action/ability/xeno_action/charge = actions_by_path[/datum/action/ability/activable/xeno/charge]
		var/datum/action/ability/xeno_action/ravage = actions_by_path[/datum/action/ability/activable/xeno/ravage]
		if(charge)
			charge.clear_cooldown()
		if(ravage)
			ravage.clear_cooldown()
		on_cooldown = TRUE

/mob/living/carbon/xenomorph/ravager/proc/drain_slash(datum/source, mob/living/target, damage, list/damage_mod, list/armor_mod)
	SIGNAL_HANDLER
	var/brute_damage = getBruteLoss()
	var/burn_damage = getFireLoss()
	if(!brute_damage && !burn_damage)
		return
	var/health_recovery = rage_power * RAVAGER_RAGE_HEALTH_RECOVERY_PER_SLASH
	var/health_modifier
	if(brute_damage)
		health_modifier = min(brute_damage, health_recovery)*-1
		adjustBruteLoss(health_modifier)
		health_recovery += health_modifier
	if(burn_damage)
		health_modifier = min(burn_damage, health_recovery)*-1
		adjustFireLoss(health_modifier)

	var/datum/action/ability/xeno_action/endure/endure_ability = actions_by_path[/datum/action/ability/xeno_action/endure]
	if(endure_ability.endure_duration) //Check if Endure is active
		var/new_duration = min(RAVAGER_ENDURE_DURATION, (timeleft(endure_ability.endure_duration) + RAVAGER_RAGE_ENDURE_INCREASE_PER_SLASH * rage_power))
		deltimer(endure_ability.endure_duration) //Reset timers
		deltimer(endure_ability.endure_warning_duration)
		endure_ability.endure_duration = addtimer(CALLBACK(endure_ability, TYPE_PROC_REF(/datum/action/ability/xeno_action/endure, endure_deactivate)), new_duration, TIMER_UNIQUE|TIMER_STOPPABLE|TIMER_OVERRIDE)
		if(new_duration > 3 SECONDS) //Check timing
			endure_ability.endure_warning_duration = addtimer(CALLBACK(endure_ability, TYPE_PROC_REF(/datum/action/ability/xeno_action/endure, endure_warning)), new_duration - 3 SECONDS, TIMER_UNIQUE|TIMER_STOPPABLE|TIMER_OVERRIDE)

// ***************************************
// *********** Mob overrides
// ***************************************

/mob/living/carbon/xenomorph/ravager/flamer_fire_act(burnlevel)
	. = ..()
	if(stat)
		return
	if(pass_flags & PASS_FIRE) // RUTGMC ADDITION START
		return FALSE // RUTGMC ADDITION END
	if(TIMER_COOLDOWN_CHECK(src, COOLDOWN_RAVAGER_FLAMER_ACT))
		return FALSE
	gain_plasma(50)
	TIMER_COOLDOWN_START(src, COOLDOWN_RAVAGER_FLAMER_ACT, 1 SECONDS)
	if(prob(30))
		emote("roar")
		to_chat(src, span_xenodanger("The heat of the fire roars in our veins! KILL! CHARGE! DESTROY!"))

// ***************************************
// *********** Ability related
// ***************************************
/mob/living/carbon/xenomorph/ravager/get_crit_threshold()
	. = ..()
	if(!endure)
		return
	var/datum/action/ability/xeno_action/endure/endure_ability = actions_by_path[/datum/action/ability/xeno_action/endure]
	return endure_ability.endure_threshold

/mob/living/carbon/xenomorph/ravager/get_death_threshold()
	. = ..()
	if(!endure)
		return
	var/datum/action/ability/xeno_action/endure/endure_ability = actions_by_path[/datum/action/ability/xeno_action/endure]
	return endure_ability.endure_threshold

/mob/living/carbon/xenomorph/ravager/med_hud_set_health()
	var/image/holder = hud_list[HEALTH_HUD_XENO]
	if(!holder)
		return
	if(stat == DEAD)
		holder.icon_state = "xenohealth0"
		return

	var/amount = health > 0 ? round(health * 100 / maxHealth, 10) : CEILING(health, 10)
	if(!amount && health < 0)
		amount = -1 //don't want the 'zero health' icon when we are crit
	holder.icon_state = "ravagerhealth[amount]"
