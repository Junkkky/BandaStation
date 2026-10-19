"""Extend the native steel ladder with the module's mechanical hatch palette."""
from pathlib import Path
import re
from PIL import Image, ImageDraw, PngImagePlugin

ROOT = Path(__file__).resolve().parents[3]
DESTINATION = Path(__file__).parent / 'icons' / 'ladder_hatch.dmi'
SIZE = (32, 48)


def native_ladder():
    atlas = Image.open(ROOT / 'icons/obj/structures.dmi')
    offset = 0
    for block in atlas.info['Description'].split('state = ')[1:]:
        name = re.match(r'"([^"]*)"', block)[1]
        if name == 'ladder10':
            x, y = offset % (atlas.width // 32) * 32, offset // (atlas.width // 32) * 32
            return atlas.convert('RGBA').crop((x, y, x + 32, y + 32))
        offset += int(re.search(r'dirs = (\d+)', block)[1]) * int(re.search(r'frames = (\d+)', block)[1])
    raise AssertionError('Native ladder state missing')


def hanging_ladder():
    image = Image.new('RGBA', SIZE)
    image.alpha_composite(native_ladder().crop((0, 0, 32, 22)), (0, 1))
    return image


def hatch(opened):
    image = Image.new('RGBA', SIZE)
    draw = ImageDraw.Draw(image)

    def octagon(box, corner=2):
        x0, y0, x1, y1 = box
        return [(x0 + corner, y0), (x1 - corner, y0), (x1, y0 + corner),
                (x1, y1 - corner), (x1 - corner, y1), (x0 + corner, y1),
                (x0, y1 - corner), (x0, y0 + corner)]

    def bolt(x, y):
        draw.rectangle((x - 1, y - 1, x + 1, y + 1), fill='#20282b')
        draw.line((x - 1, y - 1, x + 1, y - 1), fill='#a4acad')
        draw.point((x - 1, y), fill='#7a8588')
        draw.point((x, y), fill='#c0c5bc')

    # Extrusion and a separate bevel make the fixed frame sit above the deck.
    draw.polygon(octagon((6, 27, 31, 47)), fill='#131a1d')
    draw.polygon(((9, 42), (28, 42), (30, 44), (28, 47), (9, 47), (7, 45)), fill='#394448')
    draw.line((10, 45, 27, 45), fill='#69767a')
    draw.line((10, 47, 27, 47), fill='#172024')
    draw.polygon(octagon((7, 25, 30, 44)), fill='#333e42')
    draw.polygon(octagon((8, 26, 29, 43)), fill='#7d898c')
    draw.line((10, 25, 27, 25), fill='#b1b8b6')
    draw.line((7, 28, 7, 40), fill='#9aa5a5')
    draw.line((29, 29, 29, 40), fill='#343f43')
    draw.line((11, 43, 26, 43), fill='#202b30')
    draw.polygon(octagon((10, 28, 27, 41)), fill='#172125')
    if opened:
        # Recess walls surround the live lower-deck view, rather than a painted black square.
        draw.line((12, 29, 25, 29), fill='#080f12')
        draw.line((11, 30, 11, 38), fill='#0e171b')
        draw.line((27, 31, 27, 39), fill='#4d5c60')
        draw.line((14, 41, 25, 41), fill='#9aa3a1')
        draw.rectangle((13, 31, 26, 40), fill=(0, 0, 0, 0))
        draw.line((14, 31, 14, 40), fill='#4b585e')
        draw.line((25, 31, 25, 40), fill='#818d91')
        for y, inset in ((32, 2), (35, 1), (39, 0)):
            draw.line((15 + inset, y + 1, 24 - inset, y + 1), fill='#172024')
            draw.line((14 + inset, y, 25 - inset, y), fill='#859398')
        # The upright cover has a visible edge, inset backplate and foreshortened wheel.
        draw.polygon(((6, 24), (8, 26), (8, 44), (6, 42)), fill='#2e3a3e')
        draw.polygon(((0, 20), (6, 24), (6, 42), (0, 38)), fill='#657276', outline='#a1adad')
        draw.polygon(((1, 23), (4, 25), (4, 38), (1, 36)), fill='#3f4c51')
        draw.line((1, 26, 4, 28), fill='#8a989b')
        draw.line((1, 34, 4, 36), fill='#28353b')
        draw.ellipse((1, 28, 5, 35), fill='#253034', outline='#b4a57f')
        draw.line((3, 30, 3, 34), fill='#c5b995')
        draw.point((3, 32), fill='#e0ddd0')
    else:
        draw.polygon(octagon((11, 29, 26, 40)), fill='#59676c')
        draw.line((13, 29, 24, 29), fill='#a3adad')
        draw.line((11, 31, 11, 38), fill='#89979a')
        draw.line((14, 40, 24, 40), fill='#303e44')
        # Recessed strengthening ribs and radial dogs sit below the raised handwheel.
        draw.line((12, 31, 25, 38), fill='#3d4d54', width=2)
        draw.line((13, 31, 25, 37), fill='#7d8d91')
        draw.line((13, 38, 24, 31), fill='#3b4a50', width=2)
        draw.line((13, 37, 24, 30), fill='#77868b')
        draw.line((12, 35, 25, 35), fill='#263238', width=2)
        draw.line((18, 30, 18, 39), fill='#263238')
        draw.ellipse((14, 31, 24, 41), fill='#233037')
        draw.ellipse((14, 30, 23, 39), fill='#302f27', outline='#7c7561')
        draw.ellipse((15, 30, 22, 37), outline='#cabd97')
        draw.ellipse((16, 31, 21, 36), fill='#344148')
        draw.line((18, 31, 18, 34, 16, 36), fill='#c5b98d')
        draw.line((18, 34, 21, 35), fill='#a6956b')
        draw.rectangle((17, 33, 19, 35), fill='#939b95')
        draw.point((17, 33), fill='#e1dfc8')
        draw.point((20, 30), fill='#e0d4ad')
    for y in (29, 38):
        draw.rectangle((6, y, 9, y + 2), fill='#1c282d')
        draw.line((6, y, 8, y), fill='#b0b9b7')
        draw.line((7, y + 1, 9, y + 1), fill='#6b7b80')
    for x, y in ((10, 27), (27, 27), (10, 42), (27, 42)):
        bolt(x, y)
    draw.point((24, 26), fill='#c4c6bb')
    draw.point((12, 44), fill='#899796')
    return image


def main():
    states = {}
    rails = hanging_ladder()
    for up in (0, 1):
        for down in (0, 1):
            for opened in (False, True):
                image = Image.new('RGBA', SIZE)
                if down:
                    image.alpha_composite(hatch(opened))
                if up or not down:
                    # Raised, cropped feet leave a visible gap above the deck and hatch.
                    image.alpha_composite(rails)
                states[f'ladder{up}{down}_{"open" if opened else "closed"}'] = image
    mask = Image.new('RGBA', SIZE)
    ImageDraw.Draw(mask).rectangle((13, 31, 26, 40), fill='white')
    states['ladder_hole'] = mask
    rim = hatch(True)
    ImageDraw.Draw(rim).rectangle((0, 0, 31, 24), fill=(0, 0, 0, 0))
    states['ladder_rim'] = rim
    atlas = Image.new('RGBA', (32 * len(states), 48))
    metadata = ['# BEGIN DMI', 'version = 4.0', '\twidth = 32', '\theight = 48']
    for index, (name, image) in enumerate(states.items()):
        atlas.paste(image, (32 * index, 0))
        metadata += [f'state = "{name}"', '\tdirs = 1', '\tframes = 1']
    metadata.append('# END DMI')
    info = PngImagePlugin.PngInfo()
    info.add_text('Description', '\n'.join(metadata) + '\n', zip=True)
    atlas.save(DESTINATION, format='PNG', pnginfo=info)
    assert Image.open(DESTINATION).convert('RGBA').tobytes() == atlas.tobytes()
    assert all(states[f'ladder1{down}_{state}'].getbbox()[1] < 3 for down in (0, 1) for state in ('open', 'closed'))
    assert not states['ladder10_open'].crop((0, 25, 32, 48)).getbbox()
    assert states['ladder11_closed'].tobytes() != states['ladder11_open'].tobytes()
    print('PASS: 10 native DMI states, shortened raised ladder, hatch and transparency mask')


if __name__ == '__main__':
    main()
