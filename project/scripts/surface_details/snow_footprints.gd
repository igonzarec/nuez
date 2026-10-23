extends RefCounted
## Máscaras temporales de depresión. Se actualiza sólo el bloque tocado por cada paso.
const SIDE := 512
const TILE := 16.0
var clock := 0.0
var tiles: Dictionary = {}
var empty: ImageTexture

func _init() -> void:
	var image := Image.create(1,1,false,Image.FORMAT_RGBAF)
	image.fill(Color(0,0,0,0))
	empty = ImageTexture.create_from_image(image)

func advance(delta: float, lifetime: float, limit: int) -> void:
	clock += delta
	for key in tiles.keys():
		if clock-float(tiles[key].last) > lifetime: tiles.erase(key)
	while tiles.size() > limit:
		var oldest: Vector2i = tiles.keys()[0]
		for key: Vector2i in tiles:
			if tiles[key].last < tiles[oldest].last: oldest = key
		tiles.erase(oldest)

func texture_for(key: Vector2i) -> Texture2D:
	return tiles[key].texture if tiles.has(key) else empty

func stamp(point: Vector2, forward: Vector2, depth: float, style: Resource) -> void:
	if depth < 0.0001: return
	var radius := maxf(style.snow_footprint_width,style.snow_footprint_length)*0.7
	var first := Vector2i(((point-Vector2.ONE*radius)/TILE).floor())
	var last := Vector2i(((point+Vector2.ONE*radius)/TILE).floor())
	var right := Vector2(forward.y,-forward.x)
	for z in range(first.y,last.y+1):
		for x in range(first.x,last.x+1):
			var key := Vector2i(x,z)
			if not tiles.has(key):
				var image := Image.create(SIDE,SIDE,false,Image.FORMAT_RGBAF)
				image.fill(Color(0,0,0,0))
				tiles[key] = {"image":image,"texture":ImageTexture.create_from_image(image),"last":clock}
			var tile: Dictionary = tiles[key]
			var image: Image = tile.image
			var origin := Vector2(key)*TILE
			var low := Vector2i(((point-Vector2.ONE*radius-origin)*SIDE/TILE).floor()).clamp(Vector2i.ZERO,Vector2i(SIDE-1,SIDE-1))
			var high := Vector2i(((point+Vector2.ONE*radius-origin)*SIDE/TILE).ceil()).clamp(Vector2i.ZERO,Vector2i(SIDE-1,SIDE-1))
			for py in range(low.y,high.y+1):
				for px in range(low.x,high.x+1):
					var offset := origin+(Vector2(px,py)+Vector2(0.5,0.5))*TILE/SIDE-point
					var q := Vector2(offset.dot(right)/(style.snow_footprint_width*0.5),offset.dot(forward)/(style.snow_footprint_length*0.5))
					var shape := 1.0-smoothstep(0.45,1.0,Vector2(q.x/0.85,(q.y+0.15)/0.8).length())
					for toe in [-0.5,0.0,0.5]:
						shape = maxf(shape,1.0-smoothstep(0.1,0.38,(q-Vector2(toe,0.62)).length()))
					if shape <= 0.0: continue
					var old := image.get_pixel(px,py)
					var age := clock-old.g/maxf(old.r,0.000001)
					var previous := old.r*(1.0-smoothstep(style.snow_footprint_lifetime*0.65,style.snow_footprint_lifetime,age))
					var value := maxf(previous,shape*depth)
					# Tiempo ponderado por profundidad: el filtrado no envejece los bordes.
					image.set_pixel(px,py,Color(value,value*clock,0,0))
			tile.last = clock
			tile.texture.update(image)
	advance(0.0,style.snow_footprint_lifetime,style.snow_footprint_tiles)
