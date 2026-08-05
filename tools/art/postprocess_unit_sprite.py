from __future__ import annotations

import argparse
from collections import deque
from pathlib import Path

from PIL import Image, ImageChops, ImageFilter


def is_green_screen(pixel: tuple[int, int, int, int]) -> bool:
	r, g, b, a = pixel
	if a < 8:
		return True
	return g >= 64 and g >= int(r * 1.08) and g >= int(b * 1.02) and (g - min(r, b)) >= 12


def flood_background(image: Image.Image) -> Image.Image:
	rgba = image.convert("RGBA")
	width, height = rgba.size
	pixels = rgba.load()
	mask = Image.new("L", rgba.size, 0)
	mask_pixels = mask.load()
	queue: deque[tuple[int, int]] = deque()

	for x in range(width):
		queue.append((x, 0))
		queue.append((x, height - 1))
	for y in range(height):
		queue.append((0, y))
		queue.append((width - 1, y))

	while queue:
		x, y = queue.popleft()
		if x < 0 or y < 0 or x >= width or y >= height:
			continue
		if mask_pixels[x, y] != 0:
			continue
		if not is_green_screen(pixels[x, y]):
			continue
		mask_pixels[x, y] = 255
		queue.append((x + 1, y))
		queue.append((x - 1, y))
		queue.append((x, y + 1))
		queue.append((x, y - 1))

	return mask


def transparent_from_green_screen(source: Image.Image) -> Image.Image:
	rgba = source.convert("RGBA")
	background = flood_background(rgba)
	soft_background = background.filter(ImageFilter.GaussianBlur(1.25))
	alpha = ImageChops.subtract(Image.new("L", rgba.size, 255), soft_background)
	rgba.putalpha(alpha)
	return rgba


def is_green_spill(pixel: tuple[int, int, int, int]) -> bool:
	r, g, b, a = pixel
	if a <= 0:
		return False
	if g < 56:
		return False
	if a < 128 and g >= max(r, b) + 6:
		return True
	return g >= int(r * 1.08) and g >= int(b * 1.05) and (g - max(r, b)) >= 14


def neutralize_green_spill(pixel: tuple[int, int, int, int]) -> tuple[int, int, int, int]:
	r, g, b, a = pixel
	if a < 96:
		return (0, 0, 0, 0)
	if g > max(r, b) + 8:
		g = max(r, b)
	return (r, g, b, a)


def decontaminate_green_spill(sprite: Image.Image) -> Image.Image:
	rgba = sprite.convert("RGBA")
	width, height = rgba.size
	pixels = rgba.load()
	known = bytearray(width * height)
	unknown = bytearray(width * height)
	queue: deque[tuple[int, int]] = deque()

	for y in range(height):
		for x in range(width):
			index = y * width + x
			r, g, b, a = pixels[x, y]
			if a <= 0:
				pixels[x, y] = (0, 0, 0, 0)
				continue
			if is_green_spill((r, g, b, a)):
				unknown[index] = 1
			else:
				known[index] = 1

	for y in range(height):
		for x in range(width):
			index = y * width + x
			if not unknown[index]:
				continue
			for nx, ny in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)):
				if nx < 0 or ny < 0 or nx >= width or ny >= height:
					continue
				if known[ny * width + nx]:
					queue.append((x, y))
					break

	while queue:
		x, y = queue.popleft()
		index = y * width + x
		if not unknown[index]:
			continue

		colors: list[tuple[int, int, int]] = []
		for nx, ny in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)):
			if nx < 0 or ny < 0 or nx >= width or ny >= height:
				continue
			if known[ny * width + nx]:
				nr, ng, nb, na = pixels[nx, ny]
				if na > 8:
					colors.append((nr, ng, nb))

		if not colors:
			continue

		r, g, b, a = pixels[x, y]
		count = len(colors)
		pixels[x, y] = (
			sum(color[0] for color in colors) // count,
			sum(color[1] for color in colors) // count,
			sum(color[2] for color in colors) // count,
			a,
		)
		pixels[x, y] = neutralize_green_spill(pixels[x, y])
		unknown[index] = 0
		known[index] = 1

		for nx, ny in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)):
			if nx < 0 or ny < 0 or nx >= width or ny >= height:
				continue
			if unknown[ny * width + nx]:
				queue.append((nx, ny))

	for y in range(height):
		for x in range(width):
			index = y * width + x
			if not unknown[index]:
				continue
			pixels[x, y] = neutralize_green_spill(pixels[x, y])

	for y in range(height):
		for x in range(width):
			if is_green_spill(pixels[x, y]):
				pixels[x, y] = neutralize_green_spill(pixels[x, y])

	return rgba


def center_on_canvas(sprite: Image.Image, canvas_size: int, padding: int) -> Image.Image:
	alpha = sprite.getchannel("A")
	bbox = alpha.getbbox()
	if bbox is None:
		return Image.new("RGBA", (canvas_size, canvas_size), (0, 0, 0, 0))

	cropped = sprite.crop(bbox)
	max_size = max(1, canvas_size - padding * 2)
	cropped.thumbnail((max_size, max_size), Image.Resampling.LANCZOS)

	canvas = Image.new("RGBA", (canvas_size, canvas_size), (0, 0, 0, 0))
	x = (canvas_size - cropped.width) // 2
	y = canvas_size - padding - cropped.height
	canvas.alpha_composite(cropped, (x, y))
	return canvas


def remove_small_alpha_islands(sprite: Image.Image, min_area: int) -> Image.Image:
	if min_area <= 0:
		return sprite

	rgba = sprite.convert("RGBA")
	width, height = rgba.size
	alpha = rgba.getchannel("A")
	alpha_pixels = alpha.load()
	visited = bytearray(width * height)
	to_clear: list[tuple[int, int]] = []

	for y in range(height):
		for x in range(width):
			index = y * width + x
			if visited[index] or alpha_pixels[x, y] <= 20:
				continue

			component: list[tuple[int, int]] = []
			queue: deque[tuple[int, int]] = deque([(x, y)])
			visited[index] = 1
			while queue:
				cx, cy = queue.popleft()
				component.append((cx, cy))
				for nx, ny in ((cx + 1, cy), (cx - 1, cy), (cx, cy + 1), (cx, cy - 1)):
					if nx < 0 or ny < 0 or nx >= width or ny >= height:
						continue
					next_index = ny * width + nx
					if visited[next_index] or alpha_pixels[nx, ny] <= 20:
						continue
					visited[next_index] = 1
					queue.append((nx, ny))

			if len(component) < min_area:
				to_clear.extend(component)

	if not to_clear:
		return rgba

	pixels = rgba.load()
	for x, y in to_clear:
		r, g, b, _a = pixels[x, y]
		pixels[x, y] = (r, g, b, 0)
	return rgba


def largest_mask_component(mask: Image.Image) -> Image.Image:
	width, height = mask.size
	mask_pixels = mask.load()
	visited = bytearray(width * height)
	largest: list[tuple[int, int]] = []

	for y in range(height):
		for x in range(width):
			index = y * width + x
			if visited[index] or mask_pixels[x, y] == 0:
				continue

			component: list[tuple[int, int]] = []
			queue: deque[tuple[int, int]] = deque([(x, y)])
			visited[index] = 1
			while queue:
				cx, cy = queue.popleft()
				component.append((cx, cy))
				for nx, ny in ((cx + 1, cy), (cx - 1, cy), (cx, cy + 1), (cx, cy - 1)):
					if nx < 0 or ny < 0 or nx >= width or ny >= height:
						continue
					next_index = ny * width + nx
					if visited[next_index] or mask_pixels[nx, ny] == 0:
						continue
					visited[next_index] = 1
					queue.append((nx, ny))

			if len(component) > len(largest):
				largest = component

	clean = Image.new("L", mask.size, 0)
	clean_pixels = clean.load()
	for x, y in largest:
		clean_pixels[x, y] = 255
	return clean


def keep_near_solid_alpha(sprite: Image.Image, threshold: int, radius: int) -> Image.Image:
	if radius <= 0:
		return sprite

	rgba = sprite.convert("RGBA")
	alpha = rgba.getchannel("A")
	solid = alpha.point(lambda value: 255 if value >= threshold else 0)
	solid = largest_mask_component(solid)
	size = radius * 2 + 1
	keep = solid.filter(ImageFilter.MaxFilter(size))
	filtered_alpha = ImageChops.multiply(alpha, keep)
	rgba.putalpha(filtered_alpha)
	return rgba


def make_preview(sprite: Image.Image, output_path: Path) -> None:
	tile_sizes = [96, 128, 192, 256]
	padding = 24
	label_h = 0
	width = sum(tile_sizes) + padding * (len(tile_sizes) + 1)
	height = max(tile_sizes) + padding * 2 + label_h
	preview = Image.new("RGBA", (width, height), (18, 19, 22, 255))
	x = padding
	for tile_size in tile_sizes:
		tile = Image.new("RGBA", (tile_size, tile_size), (31, 34, 38, 255))
		check = Image.new("RGBA", (tile_size, tile_size), (0, 0, 0, 0))
		for yy in range(0, tile_size, 12):
			for xx in range(0, tile_size, 12):
				if ((xx // 12) + (yy // 12)) % 2 == 0:
					for py in range(yy, min(yy + 12, tile_size)):
						for px in range(xx, min(xx + 12, tile_size)):
							check.putpixel((px, py), (43, 47, 52, 255))
		tile.alpha_composite(check)
		unit = sprite.copy()
		unit.thumbnail((tile_size, tile_size), Image.Resampling.LANCZOS)
		tile.alpha_composite(unit, ((tile_size - unit.width) // 2, tile_size - unit.height))
		preview.alpha_composite(tile, (x, padding))
		x += tile_size + padding
	preview.save(output_path)


def main() -> None:
	parser = argparse.ArgumentParser(description="Post-process a generated Blood Will Pay unit sprite.")
	parser.add_argument("input", type=Path)
	parser.add_argument("output", type=Path)
	parser.add_argument("--canvas-size", type=int, default=1024)
	parser.add_argument("--padding", type=int, default=56)
	parser.add_argument("--min-alpha-island-area", type=int, default=96)
	parser.add_argument("--solid-alpha-threshold", type=int, default=176)
	parser.add_argument("--solid-keep-radius", type=int, default=0)
	parser.add_argument("--preview", type=Path)
	args = parser.parse_args()

	source = Image.open(args.input)
	cutout = transparent_from_green_screen(source)
	cutout = remove_small_alpha_islands(cutout, args.min_alpha_island_area)
	cutout = keep_near_solid_alpha(cutout, args.solid_alpha_threshold, args.solid_keep_radius)
	cutout = decontaminate_green_spill(cutout)
	sprite = center_on_canvas(cutout, args.canvas_size, args.padding)
	sprite = remove_small_alpha_islands(sprite, args.min_alpha_island_area)
	sprite = keep_near_solid_alpha(sprite, args.solid_alpha_threshold, args.solid_keep_radius)
	sprite = decontaminate_green_spill(sprite)
	args.output.parent.mkdir(parents=True, exist_ok=True)
	sprite.save(args.output)
	if args.preview:
		args.preview.parent.mkdir(parents=True, exist_ok=True)
		make_preview(sprite, args.preview)


if __name__ == "__main__":
	main()
