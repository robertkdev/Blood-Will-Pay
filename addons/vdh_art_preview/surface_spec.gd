extends RefCounted
## Compact controls compiled to native CanvasItem shaders and procedural textures.

const PREFIX: String = "vdh_surface/1|"
const NOISE_TYPES: Dictionary = {"simplex":1,"perlin":3,"cubic":4}
const FRACTALS: Dictionary = {"none":0,"fbm":1,"ridged":2,"ping_pong":3}

func fail(message: String) -> Dictionary:
	return {"ok":false,"error":message}

func number(value: Variant, low: float, high: float) -> bool:
	return (value is int or value is float) and is_finite(value) and value>=low and value<=high

func vector(value: Variant, low: float = -1000000, high: float = 1000000) -> bool:
	return value is Array and value.size()==2 and number(value[0],low,high) and number(value[1],low,high)

func color(value: Variant) -> bool:
	return value is Array and value.size()==4 and number(value[0],0,8) and number(value[1],0,8) and number(value[2],0,8) and number(value[3],0,1)

func fields(value: Variant, allowed: Array) -> bool:
	return value is Dictionary and not value.keys().any(func(k: Variant): return k not in allowed)

func normalize(value: Variant) -> Dictionary:
	if not fields(value,["space","blend","paint_mode","opacity","paint","masks","mask_base"]):
		return fail("Surface uses space, blend, paint_mode, opacity, paint, masks and mask_base")
	var result: Dictionary = {"space":"local","blend":"mix","paint_mode":"multiply","opacity":1.0,
		"paint":{"kind":"solid","color":[1,1,1,1]},"masks":[],"mask_base":0.0}
	result.merge(value,true)
	if result.space not in ["local","screen"] or result.blend not in ["mix","add","subtract","multiply"] or result.paint_mode not in ["multiply","replace"]:
		return fail("space local|screen, blend mix|add|subtract|multiply, paint_mode multiply|replace")
	if not number(result.opacity,0,1) or not number(result.mask_base,0,1):
		return fail("opacity and mask_base must be 0..1")
	var paint: Variant = result.paint
	if not paint is Dictionary:
		return fail("paint must be an object with kind")
	var kind: Variant = paint.get("kind","solid")
	var allowed: Array = ["kind"]
	var defaults: Dictionary = {"kind":kind}
	match kind:
		"solid":
			allowed += ["color"]
			defaults["color"] = [1,1,1,1]
		"linear":
			allowed += ["from","to","stops"]
			defaults.merge({"from":[0,0],"to":[100,0]})
		"radial":
			allowed += ["center","radii","stops"]
			defaults.merge({"center":[0,0],"radii":[100,100]})
		"noise":
			allowed += ["scale","offset","drift","seed","noise_type","fractal","octaves","roughness","warp","relief","light_angle","stops"]
			defaults.merge({"scale":[100,100],"offset":[0,0],"drift":[0,0],"seed":1,"noise_type":"simplex",
				"fractal":"fbm","octaves":4,"roughness":0.5,"warp":0.0,"relief":0.0,"light_angle":-45.0})
		_: return fail("paint kind solid|linear|radial|noise")
	if not fields(paint,allowed):
		return fail("Unknown field for paint kind " + str(kind))
	defaults.merge(paint,true)
	paint = defaults
	if kind=="solid":
		if not color(paint.color):
			return fail("Solid color needs RGBA, RGB 0..8 and alpha 0..1")
	else:
		var stops: Variant = paint.get("stops")
		if not stops is Array or stops.size()<2 or stops.size()>16:
			return fail("Paint needs 2..16 increasing {offset,color} stops including 0 and 1")
		var previous: float = -1
		for stop: Variant in stops:
			if not fields(stop,["offset","color"]) or not number(stop.get("offset"),0,1) or not color(stop.get("color")) or stop.offset<=previous:
				return fail("Gradient stops need strictly increasing offsets and RGBA colors")
			previous = float(stop.offset)
		if stops[0].offset!=0 or stops[-1].offset!=1:
			return fail("Gradient endpoints must be 0 and 1")
	if kind=="linear" and (not vector(paint.from) or not vector(paint.to) or Vector2(paint.from[0],paint.from[1]).distance_to(Vector2(paint.to[0],paint.to[1]))<0.01):
		return fail("Linear from/to need distinct local or screen pixel coordinates")
	if kind=="radial" and (not vector(paint.center) or not vector(paint.radii,0.01,1000000)):
		return fail("Radial center/radii need pixel vectors with positive radii")
	if kind=="noise":
		if not vector(paint.scale,1,100000) or not vector(paint.offset) or not vector(paint.drift,-10000,10000):
			return fail("Noise scale 1..100000 pixels, offset in pixels, drift in pixels/second")
		if paint.noise_type not in NOISE_TYPES or paint.fractal not in FRACTALS or not number(paint.seed,-2147483648,2147483647) or paint.seed!=floor(paint.seed) or not number(paint.octaves,1,8) or paint.octaves!=floor(paint.octaves):
			return fail("Noise type simplex|perlin|cubic, fractal none|fbm|ridged|ping_pong; integer seed and octaves 1..8")
		if not number(paint.roughness,0,1) or not number(paint.warp,0,256) or not number(paint.relief,0,200) or not number(paint.light_angle,-360,360):
			return fail("Noise roughness 0..1, warp 0..256 texture pixels, relief 0..200, light_angle -360..360 degrees")
	result.paint = paint
	if not result.masks is Array or result.masks.size()>16:
		return fail("Use at most 16 masks")
	var masks: Array = []
	for raw: Variant in result.masks:
		if not fields(raw,["kind","op","center","radii","rotation","feather","radius","points"]):
			return fail("Mask uses kind, op, center, radii, rotation, feather, radius or points")
		var mask: Dictionary = {"kind":"ellipse","op":"add","center":[0,0],"rotation":0.0,"feather":1.0}
		mask.merge(raw,true)
		if mask.kind not in ["ellipse","rect","roundrect","polygon"] or mask.op not in ["add","subtract","intersect","xor","replace"]:
			return fail("Mask kind ellipse|rect|roundrect|polygon; op add|subtract|intersect|xor|replace")
		if not vector(mask.center) or not number(mask.rotation,-360,360) or not number(mask.feather,0,100000):
			return fail("Masks need pixel center, rotation in degrees and nonnegative feather radius in pixels")
		if mask.kind=="polygon":
			if mask.has("radii") or mask.has("radius") or not mask.get("points") is Array or mask.points.size()<3 or mask.points.size()>64:
				return fail("Polygon needs 3..64 points relative to center; no radii/radius")
			var distinct: Dictionary = {}
			for i: int in mask.points.size():
				if not vector(mask.points[i]):
					return fail("Polygon points must be finite pixel vectors")
				distinct[JSON.stringify(mask.points[i])] = true
				if mask.points[i]==mask.points[(i+1)%mask.points.size()]:
					return fail("Polygon cannot have zero-length edges or a repeated closing endpoint")
			if distinct.size()<3:
				return fail("Polygon needs three distinct points")
		else:
			if mask.has("points") or not vector(mask.get("radii"),0.01,1000000):
				return fail("Ellipse/rect masks need positive radii (half-size) in pixels and no points")
			if mask.kind=="roundrect":
				mask["radius"] = mask.get("radius",0.0)
				if not number(mask.radius,0,minf(mask.radii[0],mask.radii[1])):
					return fail("Rounded corner radius cannot exceed either half-size")
			elif mask.has("radius"):
				return fail("Only roundrect uses radius")
		masks.append(mask)
	result.masks = masks
	return {"ok":true,"value":result}

func _uniform(program: Dictionary, name: String, type: String, path: Array, value: Variant) -> void:
	program.code += "uniform vec4 %s : source_color;\n" % name if type=="vec4 : source_color" else "uniform %s %s;\n" % [type,name]
	program.bindings[name] = path
	if type=="vec2":
		value = Vector2(value[0],value[1])
	elif type=="vec4 : source_color":
		value = Color(value[0],value[1],value[2],value[3])
	elif type=="float":
		value = float(value)
	program.uniforms[name] = value

func compile(value: Dictionary, group: bool = false) -> Dictionary:
	var modes: Dictionary = {"mix":"mix","add":"add","subtract":"sub","multiply":"mul"}
	var program: Dictionary = {"code":"shader_type canvas_item;\nrender_mode unshaded, blend_%s;\n" % modes[value.blend],"uniforms":{},"bindings":{}}
	_uniform(program,"opacity","float",["opacity"],value.opacity)
	_uniform(program,"mask_base","float",["mask_base"],value.mask_base)
	program.code += "varying vec2 surface_point;\nvoid vertex(){surface_point=VERTEX;}\n"
	if group:
		program.code += "uniform sampler2D group_screen : hint_screen_texture, repeat_disable, filter_nearest;\n"
	var paint: Dictionary = value.paint
	var body: String = "vec2 p=%s;\n" % ("surface_point" if value.space=="local" else "SCREEN_UV/SCREEN_PIXEL_SIZE")
	if paint.kind=="solid":
		_uniform(program,"paint_color","vec4 : source_color",["paint","color"],paint.color)
		body += "vec4 ink=paint_color;\n"
	else:
		for key: String in (["from","to"] if paint.kind=="linear" else (["center","radii"] if paint.kind=="radial" else ["scale","offset","drift"])):
			_uniform(program,"paint_"+key,"vec2",["paint",key],paint[key])
		if paint.kind=="linear":
			body += "vec2 axis=paint_to-paint_from; float t=clamp(dot(p-paint_from,axis)/max(dot(axis,axis),0.0001),0.0,1.0);\n"
		elif paint.kind=="radial":
			body += "float t=clamp(length((p-paint_center)/paint_radii),0.0,1.0);\n"
		else:
			program.code += "uniform sampler2D surface_noise : repeat_enable, filter_linear_mipmap;\n"
			_uniform(program,"paint_relief","float",["paint","relief"],paint.relief)
			_uniform(program,"paint_light_angle","float",["paint","light_angle"],paint.light_angle)
			body += "vec2 nuv=(p+paint_offset+TIME*paint_drift)/(paint_scale*8.0); float t=texture(surface_noise,nuv).r;\n"
		for i: int in paint.stops.size():
			_uniform(program,"stop_%d_at"%i,"float",["paint","stops",i,"offset"],paint.stops[i].offset)
			_uniform(program,"stop_%d_color"%i,"vec4 : source_color",["paint","stops",i,"color"],paint.stops[i].color)
		body += "vec4 ink=stop_0_color;\n"
		for i: int in range(1,paint.stops.size()):
			body += "ink=mix(ink,stop_%d_color,clamp((t-stop_%d_at)/(stop_%d_at-stop_%d_at),0.0,1.0));\n" % [i,i-1,i,i-1]
		if paint.kind=="noise":
			body += """vec2 du=1.0/(paint_scale*8.0);
float dx=texture(surface_noise,nuv-vec2(du.x,0.0)).r-texture(surface_noise,nuv+vec2(du.x,0.0)).r;
float dy=texture(surface_noise,nuv-vec2(0.0,du.y)).r-texture(surface_noise,nuv+vec2(0.0,du.y)).r;
vec3 n=normalize(vec3(vec2(dx,dy)*paint_relief,1.0));
float angle=radians(paint_light_angle); vec3 light=normalize(vec3(cos(angle),sin(angle),1.0));
ink.rgb*=max(0.0,1.0+dot(n,light)-light.z);
"""
	body += "float coverage=%s;\n" % ("1.0" if value.masks.is_empty() else "mask_base")
	for i: int in value.masks.size():
		var mask: Dictionary = value.masks[i]
		var name: String = "mask_%d_"%i
		for key: String in ["center","rotation","feather"]:
			_uniform(program,name+key,"vec2" if key=="center" else "float",["masks",i,key],mask[key])
		body += "{ float a=radians(%srotation); vec2 q=p-%scenter; q=mat2(vec2(cos(a),-sin(a)),vec2(sin(a),cos(a)))*q; float d;\n" % [name,name]
		if mask.kind=="polygon":
			program.code += "uniform vec2 %spoints[%d];\n" % [name,mask.points.size()]
			var points := PackedVector2Array()
			for point: Array in mask.points:
				points.append(Vector2(point[0],point[1]))
			program.uniforms[name+"points"] = points
			program.bindings[name+"points"] = ["masks",i,"points"]
			body += "d=1e30; float sg=1.0; for(int j=0;j<%d;j++){vec2 u=%spoints[j]; vec2 v=%spoints[(j+1)%%%d]; vec2 edge=v-u; vec2 w=q-u; vec2 c=w-edge*clamp(dot(w,edge)/dot(edge,edge),0.0,1.0); d=min(d,dot(c,c)); if((u.y>q.y)!=(v.y>q.y)){if(q.x<(v.x-u.x)*(q.y-u.y)/(v.y-u.y)+u.x){sg=-sg;}}} d=sqrt(d)*sg;\n" % [mask.points.size(),name,name,mask.points.size()]
		else:
			_uniform(program,name+"radii","vec2",["masks",i,"radii"],mask.radii)
			if mask.kind=="ellipse":
				body += "d=(length(q/%sradii)-1.0)*min(%sradii.x,%sradii.y);\n"%[name,name,name]
			else:
				var corner: String = "0.0"
				if mask.kind=="roundrect":
					_uniform(program,name+"radius","float",["masks",i,"radius"],mask.radius)
					corner = name+"radius"
				body += "vec2 b=abs(q)-%sradii+vec2(%s); d=length(max(b,vec2(0.0)))+min(max(b.x,b.y),0.0)-%s;\n"%[name,corner,corner]
		body += "float f=max(%sfeather,max(fwidth(d)*0.5,0.001)); float m=1.0-smoothstep(-f,f,d);\n"%name
		var folds: Dictionary = {"add":"max(coverage,m)","subtract":"max(coverage-m,0.0)","intersect":"min(coverage,m)","xor":"abs(coverage-m)","replace":"m"}
		body += "coverage=%s; }\n" % folds[mask.op]
	if group:
		body += "vec4 original=textureLod(group_screen,SCREEN_UV,0.0); if(original.a>0.0001){original.rgb/=original.a;} original*=COLOR;\n"
	else:
		body += "vec4 original=COLOR;\n"
	body += "COLOR=vec4(%s,original.a*ink.a*coverage*opacity);\n" % ("original.rgb*ink.rgb" if value.paint_mode=="multiply" else "ink.rgb")
	program.code += "void fragment(){\n"+body+"}\n"
	return program

func generator(paint: Dictionary) -> FastNoiseLite:
	var generator := FastNoiseLite.new()
	generator.seed = int(paint.seed)
	generator.noise_type = NOISE_TYPES[paint.noise_type]
	generator.frequency = 8.0/512.0
	generator.fractal_type = FRACTALS[paint.fractal]
	generator.fractal_octaves = int(paint.octaves)
	generator.fractal_gain = paint.roughness
	generator.domain_warp_enabled = paint.warp>0
	generator.domain_warp_amplitude = paint.warp
	generator.domain_warp_frequency = 8.0/512.0
	return generator

func noise(paint: Dictionary) -> NoiseTexture2D:
	var texture := NoiseTexture2D.new()
	texture.seamless = true
	texture.noise = generator(paint)
	return texture

func material(value: Dictionary, program: Dictionary) -> ShaderMaterial:
	var shader := Shader.new()
	shader.resource_name = PREFIX+JSON.stringify(value)
	shader.code = program.code
	var result := ShaderMaterial.new()
	result.shader = shader
	for key: String in program.uniforms:
		result.set_shader_parameter(key,program.uniforms[key])
	if value.paint.kind=="noise":
		result.set_shader_parameter("surface_noise",noise(value.paint))
	return result
