"""Bake the shared console model into animated BYOND sprites. Python + Pillow; no runtime rendering."""
from math import floor, ceil, sqrt, sin, cos, pi
from pathlib import Path
from PIL import Image, ImageDraw, PngImagePlugin
import wave

FOLDER = Path(__file__).parent
SIZE = (96, 112)
FACES = []
STEEL = (102, 111, 128)

def face(points, color, texture=None, luminous=False):
    FACES.append((points, color, texture, luminous))

def box(x0, y0, z0, x1, y1, z1, color=STEEL):
    face([(x0,y0,z0),(x1,y0,z0),(x1,y0,z1),(x0,y0,z1)],color)
    face([(x1,y1,z0),(x0,y1,z0),(x0,y1,z1),(x1,y1,z1)],color)
    face([(x0,y1,z0),(x0,y0,z0),(x0,y0,z1),(x0,y1,z1)],color)
    face([(x1,y0,z0),(x1,y1,z0),(x1,y1,z1),(x1,y0,z1)],color)
    face([(x0,y0,z1),(x1,y0,z1),(x1,y1,z1),(x0,y1,z1)],color)

def tube(points, radius=.7, color=(76,83,91)):
    for a,b in zip(points,points[1:]):
        delta = [b[i]-a[i] for i in range(3)]
        length=sqrt(sum(v*v for v in delta)); d=[v/length for v in delta]
        basis=(0,0,1) if abs(d[2])<.9 else (1,0,0)
        u=(d[1]*basis[2]-d[2]*basis[1],d[2]*basis[0]-d[0]*basis[2],d[0]*basis[1]-d[1]*basis[0])
        norm=sqrt(sum(v*v for v in u)); u=[v/norm*radius for v in u]
        v=(d[1]*u[2]-d[2]*u[1],d[2]*u[0]-d[0]*u[2],d[0]*u[1]-d[1]*u[0])
        rings=[]
        for p in (a,b):
            rings.append([tuple(p[i]+su*u[i]+sv*v[i] for i in range(3)) for su,sv in ((1,1),(-1,1),(-1,-1),(1,-1))])
        for index in range(4):
            j=(index+1)%4
            face([rings[0][index],rings[0][j],rings[1][j],rings[1][index]],color)

def screen(width,height,kind,frame,lit,active):
    if not lit:
        return Image.new('RGB',(width,height),(14,19,21))
    image=Image.new('RGB',(width,height),(14,36,23)); d=ImageDraw.Draw(image)
    for y in range(1,height,2): d.line((0,y,width-1,y),fill=(20,46,26))
    green=(145,209,98); dim=(61,115,57)
    if kind=='sonar':
        cx,cy=width//2,height//2; r=min(width,height)//2-2 if active else 3
        for rr in (r,max(2,r//2)):
            d.ellipse((cx-rr,cy-rr,cx+rr,cy+rr),outline=dim)
        d.line((cx-r,cy,cx+r,cy),fill=dim); d.line((cx,cy-r,cx,cy+r),fill=dim)
        if active:
            angle=-pi/4+frame*pi/2
            d.line((cx,cy,cx+round(cos(angle)*r),cy+round(sin(angle)*r)),fill=green)
        d.rectangle((cx-4,cy+2,cx-3,cy+3),fill=green)
    elif kind=='status':
        for y,length in ((3,10),(6,7),(9,12)):
            d.rectangle((2,y,3,y+1),fill=green)
            d.line((6,y,min(width-2,6+length+(frame%3)-1),y),fill=dim)
    else:
        d.line((2,height-3,width-5,3,width-7,height-5),fill=dim)
        for x,y in ((2,height-3),(width-5,3),(width-7,height-5)):
            d.rectangle((x,y,x+1,y+1),fill=green)
    return image

def build(frame=0,lit=True,active=False,engines=False):
    FACES.clear()
    # The floor, cabinet, sloping worktop and leaning CRT wall are actual shared geometry.
    box(-45,-11,0,45,10,3,(57,63,73))
    box(-43,-13,3,43,8,10,(77,85,99))
    box(-44,-11,1,44,-9,3,(124,134,149))
    for x in (-35,31): box(x,-10,0,x+4,10,2,(36,41,49))
    top=[(-46,-14,12),(46,-14,12),(46,-3,17),(-46,-3,17)]
    bottom=[(x,y,z-3) for x,y,z in top]
    face(top,(126,137,155))
    for i in range(4):
        j=(i+1)%4; face([bottom[i],bottom[j],top[j],top[i]],STEEL)
    keyboard=Image.new('RGB',(88,11),(39,46,54)); d=ImageDraw.Draw(keyboard)
    for x0,width in ((3,20),(30,27),(65,20)):
        d.rectangle((x0,1,x0+width,8),fill=(18,23,26),outline=(76,86,98))
        for x in range(x0+3,x0+width-1,3):
            for y in (3,6): d.rectangle((x,y,x+1,y+1),fill=(62,91,63) if lit else (41,48,51))
        d.rectangle((x0+width-3,2,x0+width-2,4),fill=(123,182,79) if lit else (35,43,47))
    d.rectangle((1,4,4,8),fill=(149,56,43))
    d.rectangle((6,1,7,2),fill=(178,235,112) if lit and engines else (27,34,37))
    face([(-44,-13,12.6),(44,-13,12.6),(44,-4,16.7),(-44,-4,16.7)],(255,255,255),keyboard)
    for x in (-44,42):
        box(x,-13,12,x+2,-3,17,(114,128,149))
        box(x+.4,-12.5,13,x+1.4,-11.5,13.6,(45,52,62))
    # One cabinet face rather than three individual monitor stands.
    wall=[(-44,0,15),(44,0,15),(44,7,36),(-44,7,36)]
    back=[(x,y+4,z) for x,y,z in wall]
    face(wall,(99,109,128))
    face(list(reversed(back)),(73,82,99))
    for i in range(4):
        j=(i+1)%4; face([wall[i],back[i],back[j],wall[j]],(127,139,159))
    box(-45,6.5,35.5,45,11.5,37.5,(126,138,156))
    box(-44,6.4,35.5,44,7.3,36.3,(71,81,100))
    box(-44,7,37.5,44,10.5,38,(150,161,179))
    for x in (-42,-19,19,41): box(x,8,38,x+1,9,38.3,(48,57,70))
    box(-45,-.8,14,45,3,16,(131,143,162))
    for left,right,bottom_z,top_z,kind in ((-40,-22,18,31,'status'),(-15,14,17,34,'sonar'),(22,40,18,32,'map')):
        def point(x,z,offset=0): return (x,(z-15)/3-offset,z)
        face([point(left-1,bottom_z-1,.16),point(right+1,bottom_z-1,.16),point(right+1,top_z+1,.16),point(left-1,top_z+1,.16)],(28,34,42))
        texture=screen(round(right-left),round(top_z-bottom_z),kind,frame,lit,active)
        face([point(left,bottom_z,.3),point(right,bottom_z,.3),point(right,top_z,.3),point(left,top_z,.3)],(255,255,255),texture,True)
    # The same service boxes and plumbing appear at the same positions in every view.
    box(-30,10,17,-15,15,26,(83,92,107))
    box(24,9,11,37,14,21,(96,105,120))
    for x in range(-28,-16,3): box(x,10.5,26,x+1,14,26.4,(36,42,51))
    for x in range(26,36,3): box(x,10,21,x+1,13,21.4,(40,46,55))
    tube([(-10,11,13),(-10,14,19),(-7,14,22),(12,14,22),(16,11,19)],1,(120,128,138))
    tube([(-37,10,26),(-39,14,23),(-39,15,13),(-35,11,10)],.8,(55,57,59))
    tube([(35,10,17),(39,13,15),(39,14,8),(34,10,6)],.6,(125,105,66))
    vents=Image.new('RGB',(84,7),(72,80,94)); d=ImageDraw.Draw(vents)
    for x in (5,32,60):
        d.rectangle((x,1,x+17,5),fill=(32,38,46),outline=(110,122,140))
        for xx in range(x+3,x+16,3): d.line((xx,2,xx,4),fill=(57,66,79))
    face([(-42,-13.1,1.5),(42,-13.1,1.5),(42,-13.1,8),(-42,-13.1,8)],(255,255,255),vents)

def rotated(p,turn):
    x,y,z=p
    if turn in (0,1,2,3):
        return ((x,y,z),(-y,x,z),(-x,-y,z),(y,-x,z))[int(turn)]
    angle=turn*pi/2
    return (x*cos(angle)-y*sin(angle),x*sin(angle)+y*cos(angle),z)

def render(turn):
    horizontal=turn in (0,2)
    size=(96,48) if horizontal else (32,112)
    origin=(48,32) if horizontal else (16,64)
    if turn % 1:
        size,origin=(112,96),(56,64)
    image=Image.new('RGBA',size); pixels=image.load()
    zbuffer=[-1e9]*(size[0]*size[1]); mask=Image.new('RGBA',size); mp=mask.load()
    def projection(p):
        x,y,z=rotated(p,turn)
        return (x+origin[0],-y-z*.55+origin[1],z-.55*y)
    for points,color,texture,luminous in FACES:
        world=[rotated(p,turn) for p in points]
        a=[world[1][i]-world[0][i] for i in range(3)]; b=[world[2][i]-world[0][i] for i in range(3)]
        normal=(a[1]*b[2]-a[2]*b[1],a[2]*b[0]-a[0]*b[2],a[0]*b[1]-a[1]*b[0])
        norm=sqrt(sum(v*v for v in normal)) or 1
        shade=1 if luminous else .70+.32*max(0,(-normal[0]-.6*normal[1]+1.5*normal[2])/norm/1.9)
        projected=[projection(p) for p in points]; uv=((0,1),(1,1),(1,0),(0,0))
        for indices in ((0,1,2),(0,2,3)):
            v=[projected[i] for i in indices]
            det=(v[1][1]-v[2][1])*(v[0][0]-v[2][0])+(v[2][0]-v[1][0])*(v[0][1]-v[2][1])
            if abs(det)<1e-8: continue
            for y in range(max(0,floor(min(p[1] for p in v))),min(size[1],ceil(max(p[1] for p in v)))):
                for x in range(max(0,floor(min(p[0] for p in v))),min(size[0],ceil(max(p[0] for p in v)))):
                    w0=((v[1][1]-v[2][1])*(x+.5-v[2][0])+(v[2][0]-v[1][0])*(y+.5-v[2][1]))/det
                    w1=((v[2][1]-v[0][1])*(x+.5-v[2][0])+(v[0][0]-v[2][0])*(y+.5-v[2][1]))/det
                    weights=(w0,w1,1-w0-w1)
                    if min(weights)<-1e-7: continue
                    depth=sum(weights[i]*v[i][2] for i in range(3)); index=y*size[0]+x
                    if depth<zbuffer[index]-1e-6: continue
                    rgb=color
                    if texture:
                        u=sum(weights[i]*uv[indices[i]][0] for i in range(3)); vv=sum(weights[i]*uv[indices[i]][1] for i in range(3))
                        rgb=texture.getpixel((min(texture.width-1,max(0,int(u*texture.width))),min(texture.height-1,max(0,int(vv*texture.height)))))
                    pixels[x,y]=tuple(min(255,round(c*shade)) for c in rgb)+(255,)
                    mp[x,y]=(255,255,255,255) if luminous else (0,0,0,0)
                    zbuffer[index]=depth
    return image,mask



def full(frame=0, lit=True, active=False, engines=False):
    build(frame, lit, active, engines)
    bank = []
    for turn in (0, 2, 1, 3):  # BYOND: south, north, east, west.
        picture, _ = render(turn)
        image = Image.new('RGBA', SIZE)
        image.paste(picture, (0, SIZE[1] - picture.height))
        bank.append(image)
    return bank


def mask(image):
    result = Image.new('RGBA', image.size)
    for y in range(image.height):
        for x in range(image.width):
            r, g, b, alpha = image.getpixel((x, y))
            if alpha and g > r * 1.15 and g > b * 1.25 and g > 25:
                result.putpixel((x, y), (255, 255, 255, 255))
    return result


def parts(bank):
    result = []
    for direction, picture in enumerate(bank):
        tiles = []
        for index in range(3):
            if direction < 2:
                tile = picture.crop((index * 32, 64, index * 32 + 32, 112))
            else:
                # Bottom-to-top map ordering; only the uppermost section owns the 16px overhang.
                tile = Image.new('RGBA', (32, 48))
                tile.paste(picture.crop((0, 80 - index * 32, 32, 112 - index * 32)), (0, 16))
                if index == 2:
                    tile.paste(picture.crop((0, 0, 32, 16)), (0, 0))
            tiles.append(tile)
        result.append(tiles)
    return [[result[d][i] for d in range(4)] for i in range(3)]


def write_dmi(path, size, states):
    with wave.open(str(FOLDER.parent/'sounds/sonar.wav'), 'rb') as sound:
        ping_delay = round(sound.getnframes() / sound.getframerate() * 10 / 4, 4)
    tiles, metadata = [], ['# BEGIN DMI', 'version = 4.0', '\twidth = ' + str(size[0]), '\theight = ' + str(size[1])]
    for name, frames in states.items():
        metadata += ['state = "' + name + '"', '\tdirs = 4', '\tframes = ' + str(len(frames))]
        if len(frames) > 1:
            delay = str(ping_delay) if name.startswith('active-') else '4'
            metadata += ['\tdelay = ' + ','.join([delay] * len(frames))]
        for frame in frames:
            assert len(frame) == 4 and all(tile.size == size for tile in frame)
            tiles.extend(frame)
    atlas = Image.new('RGBA', (size[0] * 8, size[1] * ((len(tiles) + 7) // 8)))
    for index, tile in enumerate(tiles):
        atlas.paste(tile, (index % 8 * size[0], index // 8 * size[1]))
    info = PngImagePlugin.PngInfo()
    info.add_text('Description', '\n'.join(metadata) + '\n', zip=True)
    atlas.save(path, format='PNG', pnginfo=info)
    assert Image.open(path).convert('RGBA').tobytes() == atlas.tobytes()


def main():
    banks = {'off': [full(lit=False)], 'passive': [full(frame) for frame in range(4)],
             'active': [full(frame, active=True) for frame in range(4)]}
    editor = {'navigation': [banks['passive'][0]], '_broken': [[Image.new('RGBA', SIZE) for _ in range(4)]]}
    states = {}
    for mode, frames in banks.items():
        frames = [parts(bank) for bank in frames]
        for index in range(3):
            states[mode + '-' + str(index + 1)] = [frame[index] for frame in frames]
    for index, directional in enumerate(parts(banks['passive'][0])):
        states['mask-' + str(index + 1)] = [[mask(image) for image in directional]]
    powered = parts(full(engines=True))
    normal = parts(banks['passive'][0])
    lamps = []
    for direction, owner in enumerate((0, 2, 0, 2)):
        lamp = Image.new('RGBA', (32, 48))
        for index in range(3):
            changed = Image.new('RGBA', (32, 48))
            for y in range(48):
                for x in range(32):
                    value = powered[index][direction].getpixel((x, y))
                    if value != normal[index][direction].getpixel((x, y)):
                        changed.putpixel((x, y), value)
            if index == owner:
                lamp = changed
            else:
                assert not changed.getbbox(), ('Engine lamp crossed its physical section', direction, index)
        assert lamp.getbbox(), ('Missing engine lamp', direction)
        lamps.append(lamp)
    states['engine'] = [lamps]
    states['engine-mask'] = [[mask(image) for image in lamps]]
    count = 0
    for frames in banks.values():
        for bank in frames:
            for direction, picture in enumerate(bank):
                assembled = Image.new('RGBA', SIZE)
                for index, directional in enumerate(parts(bank)):
                    assembled.alpha_composite(directional[direction], (index * 32 if direction < 2 else 0, 64 if direction < 2 else 64 - index * 32))
                assert assembled.tobytes() == picture.tobytes(), (direction, count)
                assert picture.getbbox()
                count += 1
    for picture in banks['off'][0]:
        assert not mask(picture).getbbox(), 'Unpowered keyboard or screen is still green'
    assert banks['passive'][0][0].tobytes() != banks['passive'][1][0].tobytes(), 'Missing screen animation'
    assert banks['passive'][0][0].tobytes() != banks['active'][0][0].tobytes()
    write_dmi(FOLDER / 'navigation.dmi', SIZE, editor)
    write_dmi(FOLDER / 'navigation_sections.dmi', (32, 48), states)
    print('PASS:', count, 'editor/runtime composites; four model projections; animation, off states and physical engine lamps')


if __name__ == '__main__':
    main()
