extends RefCounted
## Godot integration policy, not an assertion of Unity mixer equivalence.
## Preserve the existing app SFX volume/mute and final-exit retirement barrier.
static func permitted(host) -> bool:
 if not is_instance_valid(host) or not host.sound_enabled:return false
 var manager=host.get_node_or_null("/root/SoundManager")
 return manager==null or (not manager.shutdown_pending and manager.sfx_enabled)

static func stop_tree(node:Node) -> void:
 var manager=node.get_node_or_null("/root/SoundManager") if node.is_inside_tree() else null
 if is_instance_valid(manager):manager._track_tree_playbacks(node)
 _stop(node)

static func _stop(node:Node) -> void:
 if node is AudioStreamPlayer:
  node.stop();node.stream=null
 for child in node.get_children():_stop(child)
