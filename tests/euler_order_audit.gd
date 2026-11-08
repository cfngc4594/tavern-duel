extends SceneTree
func _initialize():
 var a=Vector3(0.2,0.5,0.8)
 var source=Basis(Vector3.UP,a.y)*Basis(Vector3.RIGHT,a.x)*Basis(Vector3.BACK,a.z)
 for order in [EULER_ORDER_YXZ,EULER_ORDER_ZXY]:
  var b=Basis.from_euler(a,order)
  print("ORDER ",order," SOURCE_DIFF=",(b.x-source.x).length()+(b.y-source.y).length()+(b.z-source.z).length())
 quit()
