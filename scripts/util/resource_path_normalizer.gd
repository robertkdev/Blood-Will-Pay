extends RefCounted
class_name ResourcePathNormalizer


static func source_name(entry_name: String) -> String:
	var normalized_name: String = entry_name
	if normalized_name.ends_with(".remap") or normalized_name.ends_with(".import"):
		normalized_name = normalized_name.get_basename()
	return normalized_name
