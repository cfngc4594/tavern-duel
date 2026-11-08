shader_type canvas_item;
uniform sampler2D restored : source_color, filter_linear;
// Explicit source-pixel removal regions. Outside these regions source RGB is unchanged.
float patch_mask(vec2 p, vec4 r) {
    vec2 a=p-r.xy; vec2 b=r.xy+r.zw-p;
    float d=min(min(a.x,a.y),min(b.x,b.y));
    // The restoration is fully selected inside the first three source pixels.
    return smoothstep(0.0,3.0,d);
}
float ellipse_mask(vec2 p,vec2 c,vec2 r){return 1.0-smoothstep(0.96,1.0,length((p-c)/r));}
float portrait_mask(vec2 p,vec2 c){
    float dome=ellipse_mask(p,vec2(c.x,c.y-5.0),vec2(51.0,51.0));
    float lower=patch_mask(p,vec4(c.x-51.0,c.y-5.0,102.0,66.0));
    return max(dome,lower);
}
void fragment() {
    vec2 p=UV*vec2(1280.0,720.0);
    float m=0.0;
    m=max(m,patch_mask(p,vec4(-8.0,3.0,135.0,53.0))); // opponent_name
    m=max(m,patch_mask(p,vec4(506.0,-8.0,272.0,71.0))); // opponent_hand
    m=max(m,patch_mask(p,vec4(778.0,24.0,77.0,43.0))); // opponent_mana
    m=max(m,portrait_mask(p,vec2(640.0,129.0))); // portrait interior; physical board arch preserved
    m=max(m,ellipse_mask(p,vec2(757.0,158.0),vec2(53.0,53.0)));
    m=max(m,patch_mask(p,vec4(741.0,100.0,31.0,35.0))); // original power cost removed
    m=max(m,patch_mask(p,vec4(1051.0,165.0,65.0,119.0))); // tighter deck silhouette
    m=max(m,patch_mask(p,vec4(966.0,287.0,137.0,81.0))); // turn_button_and_socket
    m=max(m,patch_mask(p,vec4(1052.0,372.0,65.0,109.0)));
    m=max(m,portrait_mask(p,vec2(640.0,547.0))); // portrait interior; physical board arch preserved
    m=max(m,ellipse_mask(p,vec2(757.0,551.0),vec2(53.0,53.0)));
    m=max(m,patch_mask(p,vec4(742.0,491.0,32.0,35.0)));
    m=max(m,patch_mask(p,vec4(400.0,614.0,420.0,114.0))); // player_hand
    m=max(m,patch_mask(p,vec4(809.0,644.0,76.0,47.0))); // player_mana
    m=max(m,patch_mask(p,vec4(469.0,524.0,31.0,34.0))); // cursor
    m=max(m,patch_mask(p,vec4(-8.0,639.0,120.0,49.0))); // player_name
    m=max(m,patch_mask(p,vec4(-8.0,683.0,136.0,45.0))); // friends_and_clock
    m=max(m,patch_mask(p,vec4(887.0,702.0,49.0,26.0))); // performance_readout
    m=max(m,patch_mask(p,vec4(1223.0,684.0,65.0,44.0))); // settings_gear
    m=max(m,ellipse_mask(p,vec2(688.0,184.0),vec2(18.0,21.0)));
    m=max(m,ellipse_mask(p,vec2(688.0,602.0),vec2(18.0,21.0)));
    vec4 source=texture(TEXTURE,UV);
    vec4 repair=texture(restored,UV);
    COLOR=vec4(mix(source.rgb,repair.rgb,m),1.0);
}
