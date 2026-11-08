extends SceneTree
func _initialize():call_deferred("run")
func run():
 var game=load("res://scripts/game.gd").new();root.add_child(game);game.set_process(false);game.set_physics_process(false)
 var snapshots:Array=[]
 for seat in [0,1]:
  for seed_value in [7,3001,255130,8372]:
   for mask in range(1<<(3 if seat==0 else 4)):
    game.start_match("normal",seat,seed_value)
    game.flow.phase="mulligan";game.flow.phase_time=0
    for index in game.flow.first_hand_count:
     if mask&(1<<index):game.flow.toggle_mulligan(index)
    game.flow.confirm_mulligan()
    var guard=0
    while game.flow.phase!="playing" and guard<2000:
     game.flow.tick(.02);guard+=1
    assert(game.flow.phase=="playing","Opening failed to finish")
    var hand:Array=[]
    for card in game.cards:hand.append(card.key)
    snapshots.append({"seat":seat,"seed":seed_value,"mask":mask,"hand":hand,"deck":game.deck.duplicate(),"enemy_hand":game.enemy_hand.duplicate(),"enemy_deck":game.enemy_deck.duplicate(),"replacement_history":game.flow.replacement_history.duplicate(true),"turn":game.turn,"side_turn":game.side_turn.duplicate(),"player_turn":game.player_turn,"mana":game.mana,"max_mana":game.max_mana,"enemy_mana":game.enemy_mana,"enemy_max_mana":game.enemy_max_mana})
 var payload=JSON.stringify(snapshots)
 print("OPENING_RULES_STATE_SHA256=",payload.sha256_text()," CASES=",snapshots.size())
 game.queue_free();await process_frame;quit()
