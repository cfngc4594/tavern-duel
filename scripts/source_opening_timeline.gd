extends RefCounted
## Ordinary classic opening, build37.0.0.255130.254477.
## DealStartingCards.MoveNext0x06005c90:05e4-0688,0713-0806,081c-0c84.
## All ages measured from FIRST base-card launch, not coroutine/intro start.
## Game-specific coroutine yields, assets, GameState.IsBusy and server waits
## are readiness gates owned by caller. Numbers here are minimum fixed waits.
const BASE_CARD_COUNT:int=3
const COIN_WAIT:float=2.0
const AFTER_BONUS_WAIT:float=1.75
const BEFORE_CHOOSING_WAIT:float=0.6
const SPREAD_DURATION:float=0.9333333373069763
const REPLACEMENT_STAGGER:float=0.5

static func base_card_launch(index:int)->float:
	assert(index>=0 and index<BASE_CARD_COUNT)
	return 0.0 if index==0 else 0.19+0.09*float(index-1)

static func base_loop_end()->float:
	# Every launch yields.04 before audio then.05; first adds.10 bonus wait.
	return 0.37

static func coin_launch()->float:
	return base_loop_end()

static func bonus_card_launch(coin_exists:bool=true)->float:
	# Fourth card is only for second player; caller must enforce seat/identity.
	return coin_launch()+(COIN_WAIT if coin_exists else 0.0)

static func card_launch(index:int,goes_first:bool,coin_exists:bool=true)->float:
	assert(index>=0 and index<(3 if goes_first else 4))
	return base_card_launch(index) if index<BASE_CARD_COUNT else bonus_card_launch(coin_exists)

static func after_bonus_gate(goes_first:bool,coin_exists:bool=true)->float:
	# Second-player fourth-card coroutine yields.04 for its sound before1.75 wait.
	return bonus_card_launch(coin_exists)+(0.0 if goes_first else 0.04)+AFTER_BONUS_WAIT

static func spread_start(coin_exists:bool=true)->float:
	return after_bonus_gate(true,coin_exists)

static func spread_end(coin_exists:bool=true)->float:
	return spread_start(coin_exists)+SPREAD_DURATION

static func choices_ready(goes_first:bool,coin_exists:bool=true)->float:
	# .6 is unconditional; first-player spread is still moving when choices unlock.
	return after_bonus_gate(goes_first,coin_exists)+BEFORE_CHOOSING_WAIT

static func deal_duration(goes_first:bool,coin_exists:bool=true)->float:
	# Phase transition to choosing, NOT completion of every outstanding animation.
	return choices_ready(goes_first,coin_exists)

static func deal_motion_end(goes_first:bool,coin_exists:bool=true)->float:
	return spread_end(coin_exists) if goes_first else bonus_card_launch(coin_exists)+1.5

static func deal_age_during_choices(choices_age:float,goes_first:bool,coin_exists:bool=true)->float:
	return choices_ready(goes_first,coin_exists)+choices_age

static func first_launch_from_coroutine(intro_ready_age:float)->float:
	# Initial1s wait and introComplete wait overlap, not1s AFTER intro completes.
	# Before-base/after-intro game hooks and readiness stalls must be added by caller.
	return maxf(1.0,intro_ready_age)

static func replacement_out_launch(selected_rank:int)->float:
	assert(selected_rank>=0)
	return REPLACEMENT_STAGGER*float(selected_rank)

static func replacement_choices_send(selected_count:int)->float:
	assert(selected_count>=0)
	# Send after each selected launch+.5, not after its1.5s movement completes.
	return REPLACEMENT_STAGGER*float(selected_count)

static func replacement_in_launch(selected_rank:int,selected_count:int,server_ready_age:float)->float:
	assert(selected_rank>=0 and selected_rank<selected_count)
	# Negative server-ready age means unavailable; caller must NOT start this phase.
	assert(server_ready_age>=0.0)
	return maxf(replacement_choices_send(selected_count),server_ready_age)+REPLACEMENT_STAGGER*float(selected_rank)

static func replacement_shuffle(selected_count:int,server_ready_age:float)->float:
	assert(selected_count>=0 and server_ready_age>=0.0)
	return maxf(replacement_choices_send(selected_count),server_ready_age)+REPLACEMENT_STAGGER*float(selected_count)+1.0

static func replacement_minimum_end(selected_count:int,server_ready_age:float)->float:
	# Must ALSO wait opponent replacement readiness before EndMulligan/gather.
	return replacement_shuffle(selected_count,server_ready_age)+1.5
