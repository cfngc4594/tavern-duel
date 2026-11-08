extends "res://scripts/native_combat_particles.gd"
## Death's SetVisibilityRecursiveAction enables initially disabled renderers,
## including source subemitters. Visibility is a runtime property, not new art.
func setup(spec: Dictionary,assets,parent_root: Node3D,seed_value: int) -> void:
 var instance: Dictionary=spec.duplicate()
 instance.renderer=spec.renderer.duplicate(true)
 if is_instance_valid(spec.node) and spec.node.has_meta("source_renderer_enabled"):
  instance.renderer.data.m_Enabled=bool(spec.node.get_meta("source_renderer_enabled"))
 super.setup(instance,assets,parent_root,seed_value)
