extends 'res://original_board/scripts/pumpkin_interaction.gd'
## The eleven enabled, independently gated source flower FSMs.
func source_kinds()->Array:
 return ['BushFlower01','BushFlower02','BushFlower03','BushFlower04','BushFlower05','BushFlower06','BushFlower07','BushFlower08','BushFlower09','BushFlower10','BushFlower011']
func target_screen(kind='BushFlower01')->Vector2:return super.target_screen(kind)
