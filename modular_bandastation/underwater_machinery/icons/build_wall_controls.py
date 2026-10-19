"""Build directional APC-style controls and a cast mechanical flood alarm. Python + Pillow."""
from pathlib import Path
import re
from PIL import Image, ImageDraw, PngImagePlugin

FOLDER = Path(__file__).parent
ROOT = FOLDER.parents[2]
SIZE = 32


def read_state(path, state):
    image = Image.open(path).convert('RGBA')
    description = Image.open(path).info['Description']
    index = 0
    for block in description.split('state = ')[1:]:
        name = re.match(r'"([^"]*)"', block)[1]
        dirs = int(re.search(r'dirs = (\d+)', block)[1])
        frames = int(re.search(r'frames = (\d+)', block)[1])
        if name == state:
            columns = image.width // SIZE
            return [image.crop((i % columns * SIZE, i // columns * SIZE,
                                i % columns * SIZE + SIZE, i // columns * SIZE + SIZE))
                    for i in range(index, index + dirs)]
        index += dirs * frames
    raise ValueError(state)


def directions(image):
    return [image, image.transpose(Image.Transpose.ROTATE_180),
            image.transpose(Image.Transpose.ROTATE_90), image.transpose(Image.Transpose.ROTATE_270)]


def alarm_panel(lit=True, alert=False, opened=False):
    image = Image.new('RGBA', (SIZE, SIZE))
    draw = ImageDraw.Draw(image)
    # A thick cast enclosure, push plate and grille follow the old mechanical alarm silhouette.
    draw.rectangle((4, 13, 27, 21), fill='#24282c')
    draw.ellipse((5, 5, 26, 29), fill='#20262b')
    draw.ellipse((5, 4, 26, 27), fill='#4c292c', outline='#25292e')
    draw.ellipse((6, 4, 25, 26), fill='#8c3f3b')
    draw.arc((6, 4, 25, 26), 190, 295, fill='#c47b68')
    draw.arc((6, 4, 25, 26), 5, 105, fill='#582d31', width=2)
    draw.arc((8, 6, 23, 25), 140, 200, fill='#a65549')
    for x in (4, 26):
        draw.rectangle((x, 14, x + 1, 20), fill='#703934')
        draw.point((x, 15), fill='#b38b78')
        draw.point((x + 1, 16), fill='#32272a')
    draw.ellipse((12, 6, 19, 12), fill='#23282b', outline='#686867')
    color = '#ed6755' if alert else '#67c47a'
    dim = '#763c32' if alert else '#326947'
    draw.ellipse((13, 7, 18, 11), fill=dim if lit else '#252c28')
    if lit:
        draw.rectangle((14, 8, 17, 10), fill=color)
        draw.point((14, 8), fill='#ffcebb' if alert else '#c3e8c6')
    draw.rectangle((8, 13, 23, 22), fill='#25282c')
    draw.rectangle((8, 13, 22, 21), fill='#857b68', outline='#b19c7e')
    draw.rectangle((10, 15, 21, 20), fill='#302e2b', outline='#575b5a')
    if opened:
        draw.line((11, 17, 14, 17, 14, 19, 20, 19), fill='#ac7650')
    else:
        draw.rectangle((11, 15, 20, 19), fill='#7d8984')
        draw.line((11, 15, 19, 15), fill='#a9b6a9')
        draw.line((12, 19, 20, 19), fill='#4b5b5d')
        draw.line((15, 16, 15, 18, 17, 18), fill='#45595e')
    for x in range(11, 22, 2):
        draw.line((x, 24, x, 25), fill='#2b272b')
        draw.point((x + 1, 25), fill='#a05c4b')
    draw.point((10, 8), fill='#ad8c76')
    draw.point((23, 22), fill='#b57e66')
    return directions(image)


def make_states():
    casing = read_state(ROOT / 'modular_bandastation/aesthetics/apc/icons/apc.dmi', 'apc0')
    states = {}

    def add(name, frames):
        states[name] = frames

    def panel(kind, lit=True, running=False, opened=False):
        face = Image.new('RGBA', (SIZE, SIZE))
        draw = ImageDraw.Draw(face)
        # Keep the original APC's highlights, recess, vents and four directional silhouettes.
        if opened:
            draw.rectangle((13, 12, 21, 19), fill='#171d1c', outline='#565d60')
            draw.line((14, 14, 19, 14, 19, 18), fill='#ad8854')
            draw.line((15, 18, 15, 16, 20, 16), fill='#485e77')
        else:
            draw.rectangle((13, 12, 21, 19), fill='#121916', outline='#3c4546')
            color = '#67c47a'
            dim = '#326947'
            draw.rectangle((14, 13, 20, 18), fill='#172b20' if lit else '#141a17')
            if lit:
                draw.line((14, 13, 20, 13), fill=dim)
                draw.line((14, 16, 15, 16, 16, 14, 17, 17, 18, 15, 20, 15), fill=color)
            # Blue water-lock key and amber pump-running indicator.
            key = '#405b68' if kind == 'button' else '#414743'
            draw.rectangle((9, 14, 10, 17), fill=key)
            if running:
                draw.rectangle((9, 14, 10, 15), fill='#e4c366')
                draw.point((9, 14), fill='#fff1b7')
        faces = directions(face)
        return [Image.alpha_composite(base, overlay) for base, overlay in zip(casing, faces)]

    def mask(frames):
        result = []
        for frame in frames:
            image = Image.new('RGBA', (SIZE, SIZE))
            for y in range(SIZE):
                for x in range(SIZE):
                    r, g, b, alpha = frame.getpixel((x, y))
                    if alpha and ((g > r * 1.3 and g > b * 1.2 and g > 85)
                                  or (r > 200 and g > 170 and b < 190)):
                        image.putpixel((x, y), (255, 255, 255, 255))
            result.append(image)
        return result

    for kind in ('controller', 'button'):
        normal = panel(kind)
        add(kind, [normal])
        add(kind + '-nopower', [panel(kind, lit=False)])
        add(kind + '-open', [panel(kind, opened=True)])
        add(kind + '-light-mask', [mask(normal)])
    running = panel('controller', running=True)
    add('controller_on', [running])
    add('controller_on-light-mask', [mask(running)])
    normal = alarm_panel()
    add('alarm', [normal])
    add('alarm-nopower', [alarm_panel(lit=False)])
    add('alarm-open', [alarm_panel(opened=True)])
    lamp = Image.new('RGBA', (SIZE, SIZE))
    ImageDraw.Draw(lamp).ellipse((13, 7, 18, 11), fill='white')
    light_mask = directions(lamp)
    add('alarm-light-mask', [light_mask])
    alert = alarm_panel(alert=True)
    add('alarm_alert', [alert, alarm_panel(lit=False)])
    add('alarm_alert-light-mask', [light_mask, [Image.new('RGBA', (SIZE, SIZE)) for _ in range(4)]])
    # Native button maintenance and press feedback remain compatible with the custom casing.
    for suffix, color in (('success', '#73d585'), ('error', '#ed6755'),
                          ('board', '#42634c'), ('device', '#716957'), ('signaler', '#526b7e')):
        overlay = Image.new('RGBA', (SIZE, SIZE))
        ImageDraw.Draw(overlay).rectangle((9, 14, 10, 17), fill=color)
        add('button-overlay-' + suffix, [directions(overlay)])
    return states


def main():
    states = make_states()
    tiles = []
    metadata = ['# BEGIN DMI', 'version = 4.0', '\twidth = 32', '\theight = 32']
    for name, frames in states.items():
        metadata += ['state = "' + name + '"', '\tdirs = 4', '\tframes = ' + str(len(frames))]
        if len(frames) > 1:
            metadata += ['\tdelay = 5,5']
        for frame in frames:
            assert len(frame) == 4
            tiles.extend(frame)
    metadata.append('# END DMI')
    atlas = Image.new('RGBA', (SIZE * 8, SIZE * ((len(tiles) + 7) // 8)))
    for i, tile in enumerate(tiles):
        atlas.paste(tile, (i % 8 * SIZE, i // 8 * SIZE))
    info = PngImagePlugin.PngInfo()
    info.add_text('Description', '\n'.join(metadata) + '\n', zip=True)
    path = FOLDER / 'wall_controls.dmi'
    atlas.save(path, format='PNG', pnginfo=info)
    saved = Image.open(path)
    assert saved.convert('RGBA').tobytes() == atlas.tobytes()
    for kind in ('controller', 'alarm', 'button'):
        for index in range(4):
            assert states[kind][0][index].getbbox() == states[kind + '-nopower'][0][index].getbbox()
            assert states[kind + '-light-mask'][0][index].getbbox()
            assert states[kind][0][index].tobytes() != states[kind + '-nopower'][0][index].tobytes()
    print('PASS:', len(states), 'states,', len(tiles), 'directional frames')


if __name__ == '__main__':
    main()
