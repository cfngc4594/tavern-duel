extends SceneTree
class Host extends Node:
	var native_card_renderer
	var definitions={"YETI":{"kind":"minion"},"FIREBALL":{"kind":"spell"}}
	var card_face_textures={}
	var elapsed=0.5
func _initialize():call_deferred("run")
func run():
	var host=Host.new();root.add_child(host)
	var renderer=load("res://scripts/native_card_renderer.gd").new()
	var data=JSON.parse_string(FileAccess.get_file_as_string("res://assets/native_cards/OriginalCards/card_assets.json"))
	for p in data.profiles:renderer.profiles[p.name]=p
	for m in data.meshes:
		if str(m.key).ends_with(":-7756402925575413283"):renderer.meshes[m.key]=m
	for t in data.textures:
		if str(t.key).ends_with(":-3103092934676384505") or str(t.key).ends_with(":-6423977007338542110") or str(t.key).ends_with(":575926003976946273"):renderer.textures[t.key]=load("res://assets/native_cards/"+t.resource+".png")
	host.native_card_renderer=renderer
	var face=ImageTexture.create_from_image(Image.create(492,726,false,Image.FORMAT_RGBA8));host.card_face_textures={"YETI":face,"FIREBALL":face}
	var glow=load("res://scripts/native_opening_highlight.gd").new();host.add_child(glow);glow.setup(host)
	var failed=0
	var seeds={}
	for key in ["YETI","FIREBALL"]:
		for hover in [false,true]:
			var pose={"key":key,"pos":Vector2(800,450),"scale":1.14,"angle":0.0}
			if not glow.show_card(pose,hover):failed+=1
			var kind="minion_in_hand" if key=="YETI" else "spell_in_hand"
			if not glow.audit.has(kind):failed+=1;continue
			print("HIGHLIGHT ",key," hover=",hover," ",glow.audit[kind])
			if glow.audit[kind].state!=(7 if hover else 5):failed+=1
			var row=glow.rows[str(key)+":"+str(pose.pos)]
			if not (row.face.scale*Vector2(face.get_size())).is_equal_approx(Vector2(164,242)):failed+=1
			if not row.root.position.is_equal_approx(pose.pos):failed+=1
			if not seeds.has(key):seeds[key]=row.seed
			elif seeds[key]!=row.seed:failed+=1
			if float(row.material.get_shader_parameter("_Seed"))!=row.seed:failed+=1
			var expected_intensity=1.399999976158142 if hover else 1.2999999523162842
			if not is_equal_approx(float(row.material.get_shader_parameter("_Intensity")),expected_intensity):failed+=1
			if row.material.get_shader_parameter("_FlareTex")==null:failed+=1
	glow.begin_frame()
	for row in glow.rows.values():
		if row.root.visible:failed+=1
	host.card_face_textures.erase("YETI")
	if glow.show_card({"key":"YETI","pos":Vector2(800,450),"scale":1.14,"angle":0.0},false):failed+=1
	glow.clear_rows()
	if not glow.rows.is_empty():failed+=1
	print("OPENING_HIGHLIGHT_FAILURES=",failed)
	renderer.free();host.queue_free();quit(failed)
