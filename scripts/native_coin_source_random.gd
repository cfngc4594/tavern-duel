extends RefCounted
## Original autoRandomSeed transition0x180f60273..0x180f602c7.
## Initial entropy is a named Godot-runtime bridge, not the original session state.
static var auto_state:Array=[]
static func next_state(state:Array) -> Array:
	assert(state.size()==4)
	var x=int(state[0])&0xffffffff
	var w=int(state[3])&0xffffffff
	var t=(x^(x<<11))&0xffffffff
	var next=(w^(w>>19)^t^(t>>8))&0xffffffff
	return [int(state[1])&0xffffffff,int(state[2])&0xffffffff,w,next]
static func next_auto_seed() -> int:
	if auto_state.is_empty():
		var entropy=Crypto.new().generate_random_bytes(16)
		assert(entropy.size()==16)
		for i in 4:auto_state.append(entropy.decode_u32(i*4))
	auto_state=next_state(auto_state)
	return auto_state[3]
