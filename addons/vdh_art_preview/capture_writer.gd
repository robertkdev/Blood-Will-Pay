extends RefCounted
## Worker-owned CPU Images and files only; never access the scene tree or GPU.

func write(actual: Image, reference: Image, size: Vector2i, directory: String, source: String, expected_hash: String) -> Dictionary:
	var started: int = Time.get_ticks_usec()
	var actual_path: String = directory.path_join("actual.png")
	var comparison_path: String = directory.path_join("comparison.png")
	var reference_path: String = directory.path_join("reference." + source.get_extension())
	var copied: Error = DirAccess.copy_absolute(source,reference_path)
	var saved: Error = actual.save_png(actual_path)
	var board: Image = Image.create(size.x*2,size.y,false,Image.FORMAT_RGB8)
	board.fill(Color("080e18"))
	var ratio: float = minf(float(size.x)/reference.get_width(),float(size.y)/reference.get_height())
	reference.resize(roundi(reference.get_width()*ratio),roundi(reference.get_height()*ratio),Image.INTERPOLATE_LANCZOS)
	reference.convert(Image.FORMAT_RGB8)
	actual.convert(Image.FORMAT_RGB8)
	board.blit_rect(reference,Rect2i(Vector2i.ZERO,reference.get_size()),(size-reference.get_size())/2)
	board.blit_rect(actual,Rect2i(Vector2i.ZERO,size),Vector2i(size.x,0))
	var board_saved: Error = board.save_png(comparison_path)
	var reference_hash: String = FileAccess.get_sha256(reference_path)
	if saved != OK or copied != OK or board_saved != OK or reference_hash != expected_hash:
		return {"ok":false,"error":"Capture could not be saved completely. Check output directory permissions and free space."}
	return {"ok":true,"actual_sha256":FileAccess.get_sha256(actual_path),"reference_sha256":reference_hash,
		"seconds":float(Time.get_ticks_usec()-started)/1000000.0}
