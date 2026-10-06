"""Gera a galeria de avatares prontos do RUNOVER (flat, 512px, fundo em
degrade + glifo branco com recortes). Rode: python tools/gen_preset_avatars.py"""
import math
import os

from PIL import Image, ImageChops, ImageDraw

SIZE = 512
CX, CY = SIZE // 2, SIZE // 2
OUT = os.path.join(os.path.dirname(__file__), '..', 'app', 'assets', 'avatars')
WHITE = (255, 255, 255, 255)


def gradient(top, bottom):
    img = Image.new('RGBA', (SIZE, SIZE))
    px = img.load()
    for y in range(SIZE):
        t = y / (SIZE - 1)
        line = tuple(int(top[i] + (bottom[i] - top[i]) * t) for i in range(3)) + (255,)
        for x in range(SIZE):
            px[x, y] = line
    return img


def _layer():
    return Image.new('RGBA', (SIZE, SIZE), (0, 0, 0, 0))


def _compose(base, paint):
    """paint(layer_draw, hole_draw): branco no layer, preto nos furos."""
    layer = _layer()
    holes = Image.new('L', (SIZE, SIZE), 255)
    paint(ImageDraw.Draw(layer), ImageDraw.Draw(holes))
    coverage = layer.getchannel('A')
    layer.putalpha(ImageChops.darker(coverage, holes))
    return Image.alpha_composite(base, layer)


def p_runner(d, _):
    d.ellipse([CX - 52, CY - 200, CX + 52, CY - 96], fill=WHITE)
    d.line([CX, CY - 80, CX - 20, CY + 60], fill=WHITE, width=56, joint='curve')
    d.line([CX - 14, CY - 60, CX - 130, CY, ], fill=WHITE, width=44, joint='curve')
    d.line([CX - 8, CY - 50, CX + 120, CY - 120], fill=WHITE, width=44, joint='curve')
    d.line([CX - 20, CY + 60, CX - 140, CY + 180], fill=WHITE, width=50, joint='curve')
    d.line([CX - 20, CY + 60, CX + 110, CY + 140], fill=WHITE, width=50, joint='curve')


def p_bolt(d, _):
    d.polygon([(300, 90), (170, 300), (250, 300), (210, 430),
               (350, 250), (265, 250)], fill=WHITE)


def p_peak(d, h):
    d.polygon([(66, 400), (206, 170), (286, 300), (336, 220), (446, 400)], fill=WHITE)
    d.rectangle([66, 400, 446, 424], fill=WHITE)
    h.polygon([(206, 170), (246, 230), (206, 262), (176, 222)], fill=0)


def p_star(d, _):
    pts = []
    for i in range(10):
        r = 165 if i % 2 == 0 else 70
        a = -math.pi / 2 + i * math.pi / 5
        pts.append((CX + r * math.cos(a), CY + r * math.sin(a)))
    d.polygon(pts, fill=WHITE)


def p_flag(d, _):
    d.rectangle([196, 110, 216, 410], fill=WHITE)
    d.polygon([(216, 120), (396, 170), (216, 230)], fill=WHITE)
    d.ellipse([150, 400, 262, 430], fill=WHITE)


def p_flame(d, h):
    d.polygon([(256, 80), (330, 230), (370, 200), (360, 330),
               (300, 420), (200, 420), (150, 320), (170, 220),
               (200, 260)], fill=WHITE)
    h.ellipse([222, 308, 290, 376], fill=0)


def p_wave(d, _):
    d.arc([60, 180, 250, 370], start=200, end=340, fill=WHITE, width=44)
    d.arc([130, 150, 320, 340], start=200, end=340, fill=WHITE, width=44)
    d.arc([200, 120, 390, 310], start=200, end=340, fill=WHITE, width=44)
    d.ellipse([330, 330, 420, 420], fill=WHITE)


def p_sun(d, h):
    d.ellipse([CX - 95, CY - 95, CX + 95, CY + 95], fill=WHITE)
    for i in range(12):
        a = i * math.pi / 6
        d.line([CX + 125 * math.cos(a), CY + 125 * math.sin(a),
                CX + 175 * math.cos(a), CY + 175 * math.sin(a)],
               fill=WHITE, width=30)
    h.ellipse([CX - 45, CY - 45, CX + 45, CY + 45], fill=0)


def p_moon(d, h):
    d.ellipse([156, 116, 396, 356], fill=WHITE)
    h.ellipse([216, 66, 456, 306], fill=0)


def p_comet(d, _):
    d.line([130, 360, 330, 160], fill=WHITE, width=46, joint='curve')
    d.line([110, 300, 250, 160], fill=WHITE, width=26, joint='curve')
    d.ellipse([300, 100, 430, 230], fill=WHITE)


def p_shield(d, h):
    d.polygon([(256, 100), (386, 150), (386, 260), (256, 420),
               (126, 260), (126, 150)], fill=WHITE)
    h.polygon([(256, 160), (331, 191), (331, 260), (256, 343),
               (181, 260), (181, 191)], fill=0)


def p_crown(d, _):
    d.polygon([(140, 330), (140, 190), (210, 260), (256, 150),
               (302, 260), (372, 190), (372, 330)], fill=WHITE)
    d.rectangle([140, 348, 372, 380], fill=WHITE)


PRESETS = [
    ('corredor', (16, 42, 48), (216, 73, 28), p_runner),
    ('raio', (24, 24, 60), (120, 60, 200), p_bolt),
    ('pico', (10, 60, 50), (20, 160, 120), p_peak),
    ('estrela', (60, 20, 80), (200, 40, 120), p_star),
    ('bandeira', (120, 20, 20), (230, 90, 30), p_flag),
    ('chama', (80, 20, 10), (240, 120, 20), p_flame),
    ('onda', (10, 40, 90), (20, 150, 220), p_wave),
    ('sol', (90, 50, 5), (235, 150, 20), p_sun),
    ('lua', (10, 10, 35), (50, 50, 120), p_moon),
    ('cometa', (20, 60, 90), (40, 200, 180), p_comet),
    ('escudo', (20, 70, 40), (60, 190, 90), p_shield),
    ('coroa', (70, 55, 10), (215, 170, 30), p_crown),
]


def main():
    os.makedirs(OUT, exist_ok=True)
    for name, top, bottom, paint in PRESETS:
        img = _compose(gradient(top, bottom), paint)
        path = os.path.join(OUT, f'avatar_{name}.png')
        img.save(path, optimize=True)
        print(f'{path}: {os.path.getsize(path) // 1024} KB')


if __name__ == '__main__':
    main()
