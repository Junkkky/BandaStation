"""Recessed floor drains and hull-edge water fittings. Run with Python + Pillow."""
from pathlib import Path
from PIL import Image, ImageDraw, PngImagePlugin

FOLDER = Path(__file__).parent / 'icons'
DARK = '#202326'
EDGE = '#373c40'
STEEL = '#565c60'
LIGHT = '#858b8b'


def screw(draw, x, y):
    draw.point((x, y), fill='#a0a4a0')
    draw.point((x + 1, y + 1), fill='#24292c')


def fitting(hull=False, intake=False, opened=False, welded=False, phase=0):
    image = Image.new('RGBA', (32, 32))
    draw = ImageDraw.Draw(image)
    box = (0, 20, 31, 31) if hull else (4, 5, 27, 26)
    x0, y0, x1, y1 = box
    draw.rectangle(box, fill=DARK)
    draw.rectangle((x0, y0, x1, y0 + 1), fill=LIGHT)
    draw.rectangle((x0 + 1, y0 + 2, x1 - 1, y1 - 1), fill=STEEL)
    draw.line((x0 + 1, y0 + 2, x0 + 1, y1 - 1), fill='#727a7d')
    draw.line((x0 + 1, y1 - 1, x1 - 1, y1 - 1), fill=EDGE)
    draw.rectangle((x0 + 4, y0 + 3, x1 - 4, y1 - 3), fill='#141c21', outline=EDGE)
    if not opened:
        if intake:
            for x in range(x0 + 6, x1 - 4, 3):
                draw.line((x, y0 + 4, x, y1 - 4), fill='#777f81')
                draw.line((x + 1, y0 + 4, x + 1, y1 - 4), fill='#30393e')
        else:
            for y in range(y0 + 4, y1 - 3, 3):
                draw.line((x0 + 5, y, x1 - 5, y), fill='#7b8384')
                draw.line((x0 + 5, y + 1, x1 - 5, y + 1), fill='#3b4449')
    for x in (x0 + 2, x1 - 2):
        for y in (y0 + 3, y1 - 3):
            screw(draw, x, y)
    # A small blue enamel notch identifies the water circuit without tinting the metal.
    draw.line((x1 - 3, y0 + 5, x1 - 3, y0 + 7), fill='#64828c')
    if phase:
        draw.point((x0 + 6 + phase % (x1 - x0 - 12), y0 + 4), fill='#80adb3')
    if welded:
        draw.line((x0 + 4, y0 + 3, x1 - 4, y1 - 3), fill='#91734b', width=2)
        draw.line((x0 + 4, y0 + 3, x1 - 4, y1 - 3), fill='#b29567')
    return image


def directions(image):
    return (image, image.transpose(Image.Transpose.ROTATE_180),
            image.transpose(Image.Transpose.ROTATE_90), image.transpose(Image.Transpose.ROTATE_270))


def make_states():
    states = {}
    for name in ('drain', 'drain_welded', 'bigdrain', 'bigdrain_welded'):
        states[name] = ([fitting(intake=True, welded=name.endswith('welded'))], None)
    for prefix in ('active_input', 'active_output'):
        for suffix in ('', '-open', '-pumping', '-idle', '-mapping', '-mapping2'):
            animated = suffix in ('-pumping', '-idle')
            frames = [fitting(hull=prefix == 'active_output', intake=prefix == 'active_input',
                              opened=suffix == '-open', phase=i + 1 if animated else 0)
                      for i in range(8 if animated else 1)]
            states[prefix + suffix] = (frames, 1 if suffix == '-pumping' else 3 if animated else None)
    states['hull_intake'] = ([fitting(hull=True, intake=True)], None)
    return states


def main():
    states = make_states()
    tiles = []
    metadata = ['# BEGIN DMI', 'version = 4.0', '\twidth = 32', '\theight = 32']
    for name, (frames, delay) in states.items():
        metadata += ['state = "' + name + '"', '\tdirs = 4', '\tframes = ' + str(len(frames))]
        if delay:
            metadata.append('\tdelay = ' + ','.join([str(delay)] * len(frames)))
        for frame in frames:
            tiles.extend(directions(frame))
    metadata.append('# END DMI')
    atlas = Image.new('RGBA', (32 * 8, 32 * ((len(tiles) + 7) // 8)))
    for i, tile in enumerate(tiles):
        atlas.paste(tile, (i % 8 * 32, i // 8 * 32))
    info = PngImagePlugin.PngInfo()
    info.add_text('Description', '\n'.join(metadata) + '\n', zip=True)
    path = FOLDER / 'drains.dmi'
    atlas.save(path, format='PNG', pnginfo=info)
    assert Image.open(path).convert('RGBA').tobytes() == atlas.tobytes()
    for name in ('active_output', 'hull_intake'):
        south, north, east, west = directions(states[name][0][0])
        assert south.getbbox() == (0, 20, 32, 32)
        assert north.getbbox() == (0, 0, 32, 12)
        assert east.getbbox() == (20, 0, 32, 32)
        assert west.getbbox() == (0, 0, 12, 32)
    print('PASS:', len(states), 'states,', len(tiles), 'directional frames')


if __name__ == '__main__':
    main()
