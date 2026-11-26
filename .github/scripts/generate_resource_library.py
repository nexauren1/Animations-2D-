#!/usr/bin/env python3
"""Build AnimPro's online-only scene packs and original audio catalogue.

The generated files are placed under docs/ for GitHub Pages. They are never
listed as Flutter assets and are therefore never bundled into the Android APK.
"""
from __future__ import annotations

import hashlib
import json
import math
import random
import struct
import wave
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
DOCS = ROOT / "docs"
PACK_FILES = DOCS / "packs" / "files"
AUDIO_FILES = DOCS / "audio" / "files"
SAMPLE_RATE = 16000
MAX_PACK_BYTES = 5 * 1024 * 1024
MAX_AUDIO_BYTES = 35 * 1024 * 1024

PACK_FILES.mkdir(parents=True, exist_ok=True)
AUDIO_FILES.mkdir(parents=True, exist_ok=True)


def sha256(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def write_json(path: Path, value: object) -> bytes:
    data = (json.dumps(value, ensure_ascii=False, indent=2) + "\n").encode("utf-8")
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(data)
    return data


def stroke(points, color=0xFF2B3550, width=3.0, kind="pen"):
    return {
        "points": [{"x": float(x), "y": float(y)} for x, y in points],
        "color": color,
        "width": width,
        "kind": kind,
        "brushStyle": "lapis",
    }


def path(points, color, width=3.0):
    return stroke(points, color, width, "pen")


def line(x1, y1, x2, y2, color, width=3.0):
    return stroke([(x1, y1), (x2, y2)], color, width, "line")


def ellipse(x1, y1, x2, y2, color, width=3.0):
    return stroke([(x1, y1), (x2, y2)], color, width, "ellipse")


def rect(x1, y1, x2, y2, color, width=3.0):
    return stroke([(x1, y1), (x2, y2)], color, width, "rectangle")


def dot(x, y, color, width=5.0):
    return stroke([(x, y)], color, width, "pen")


def layer(name, strokes):
    return {"name": name, "visible": True, "strokes": strokes}


def frame(uid, layers):
    return {"uid": uid, "layers": layers}


def template(identifier, name, description, icon, tint, frames, tag="CENARIO", fps=12):
    return {
        "id": identifier,
        "name": name,
        "description": description,
        "iconCodePoint": icon,
        "tint": tint,
        "fps": fps,
        "tag": tag,
        "frames": frames,
    }


def cloud(cx, cy, scale=1.0, color=0xFFF4F1E7):
    return [
        ellipse(cx - 23 * scale, cy - 8 * scale, cx + 6 * scale, cy + 10 * scale, color, 2.8),
        ellipse(cx - 7 * scale, cy - 18 * scale, cx + 18 * scale, cy + 7 * scale, color, 2.8),
        ellipse(cx + 7 * scale, cy - 7 * scale, cx + 34 * scale, cy + 11 * scale, color, 2.8),
        path([(cx - 18 * scale, cy + 9 * scale), (cx + 24 * scale, cy + 9 * scale)], color, 2.8),
    ]


def pine(x, base, height, color=0xFF63A77B):
    top = base - height
    return [
        line(x, top + height * 0.36, x, base, 0xFF9A765B, 4),
        path([
            (x, top), (x - height * 0.25, top + height * 0.34),
            (x - height * 0.12, top + height * 0.32),
            (x - height * 0.34, top + height * 0.60),
            (x - height * 0.16, top + height * 0.56),
            (x - height * 0.40, base - height * 0.12),
            (x, base - height * 0.20),
            (x + height * 0.40, base - height * 0.12),
            (x + height * 0.16, top + height * 0.56),
            (x + height * 0.34, top + height * 0.60),
            (x + height * 0.12, top + height * 0.32),
            (x + height * 0.25, top + height * 0.34),
            (x, top),
        ], color, 3),
    ]


def broad_tree(x, base, height, color=0xFF63A77B):
    return [
        line(x - 5, base - height * 0.45, x, base, 0xFF9A765B, 9),
        path([
            (x, base - height), (x - 25, base - height * 0.82),
            (x - 39, base - height * 0.58), (x - 20, base - height * 0.56),
            (x - 31, base - height * 0.37), (x, base - height * 0.46),
            (x + 28, base - height * 0.34), (x + 19, base - height * 0.58),
            (x + 39, base - height * 0.63), (x + 19, base - height * 0.86),
            (x, base - height),
        ], color, 4),
        path([(x - 5, base - height * 0.5), (x - 24, base - height * 0.64)], 0xFF9A765B, 3),
        path([(x + 1, base - height * 0.57), (x + 21, base - height * 0.70)], 0xFF9A765B, 3),
    ]


def person(cx, base, pose, color):
    result = [
        ellipse(cx - 8, base - 93, cx + 8, base - 77, color, 3),
        line(cx, base - 77, cx, base - 66, color, 3),
        line(cx, base - 66, cx, base - 30, color, 4),
    ]
    poses = {
        "guard": [
            [(cx, base - 56), (cx - 16, base - 49), (cx - 22, base - 62)],
            [(cx, base - 56), (cx + 15, base - 48), (cx + 20, base - 62)],
            [(cx, base - 30), (cx - 14, base)], [(cx, base - 30), (cx + 13, base)],
        ],
        "advance": [
            [(cx, base - 56), (cx + 18, base - 48), (cx + 31, base - 49)],
            [(cx, base - 56), (cx - 14, base - 45), (cx - 19, base - 58)],
            [(cx, base - 30), (cx + 20, base - 5)], [(cx, base - 30), (cx - 15, base - 2)],
        ],
        "punch": [
            [(cx, base - 56), (cx - 12, base - 45), (cx - 22, base - 62)],
            [(cx, base - 56), (cx + 22, base - 57), (cx + 49, base - 58)],
            [(cx, base - 30), (cx - 16, base)], [(cx, base - 30), (cx + 17, base)],
        ],
        "block": [
            [(cx, base - 56), (cx - 14, base - 75), (cx - 22, base - 83)],
            [(cx, base - 56), (cx + 15, base - 73), (cx + 24, base - 81)],
            [(cx, base - 30), (cx - 14, base)], [(cx, base - 30), (cx + 14, base)],
        ],
        "kick": [
            [(cx, base - 56), (cx - 18, base - 48), (cx - 28, base - 62)],
            [(cx, base - 56), (cx + 16, base - 48), (cx + 24, base - 60)],
            [(cx, base - 30), (cx - 16, base)], [(cx, base - 30), (cx + 45, base - 52)],
        ],
        "dodge": [
            [(cx, base - 58), (cx - 22, base - 53), (cx - 32, base - 64)],
            [(cx, base - 58), (cx + 11, base - 44), (cx + 22, base - 55)],
            [(cx, base - 30), (cx - 26, base - 8)], [(cx, base - 30), (cx + 16, base)],
        ],
        "jump": [
            [(cx, base - 56), (cx - 20, base - 68), (cx - 27, base - 83)],
            [(cx, base - 56), (cx + 20, base - 68), (cx + 28, base - 83)],
            [(cx, base - 30), (cx - 22, base - 49)], [(cx, base - 30), (cx + 22, base - 48)],
        ],
    }
    result.extend(path(points, color, 3.5) for points in poses.get(pose, poses["guard"]))
    return result


def make_fight_frame(index, pose_a, pose_b, offset_a=0, offset_b=0, base_a=355, base_b=355):
    arena = [
        path([(18, 351), (302, 351)], 0xFF66758D, 3),
        rect(29, 105, 291, 351, 0xFF6A7891, 2),
        line(29, 305, 291, 305, 0xFF6A7891, 2),
        ellipse(136, 288, 184, 336, 0xFF6A7891, 2),
    ]
    for x, y in [(55, 85), (265, 85), (55, 275), (265, 275)]:
        arena.append(line(x, y - 25, x, y + 25, 0xFF8294A5, 2))
    return frame(f"fight-{index}", [
        layer("Arena de treino", arena),
        layer("Lutador azul", person(102 + offset_a, base_a, pose_a, 0xFF58B7E2)),
        layer("Lutador coral", person(224 + offset_b, base_b, pose_b, 0xFFFF9578)),
    ])


def build_packs():
    dark, blue, cyan, green = 0xFF2A354A, 0xFF63A6D9, 0xFF5CC7D4, 0xFF63A77B
    yellow, coral, purple, brown, white = 0xFFFFC96B, 0xFFFF987D, 0xFF9C83DC, 0xFF9A765B, 0xFFF4F1E7
    return [
        {
            "id": "sky-pack", "name": "Ceus e clima",
            "description": "Cenarios de dia, por do sol e noite estrelada.",
            "category": "Ceus", "tags": ["ceu", "nuvens", "por do sol", "noite"],
            "templates": [
                template("blue-sky", "Ceu de dia", "Sol, nuvens e colinas suaves em camadas editaveis.", 0xe51f, 0xFF65B9E8, [
                    frame("sky-day", [
                        layer("Ceu e luz", [ellipse(246, 36, 290, 80, yellow, 3)] +
                              [line(268 + math.cos(i * math.pi / 4) * 28, 58 + math.sin(i * math.pi / 4) * 28,
                                    268 + math.cos(i * math.pi / 4) * 40, 58 + math.sin(i * math.pi / 4) * 40, yellow, 2.5)
                               for i in range(8)] + cloud(85, 105, 1, white) + cloud(210, 142, .72, white)),
                        layer("Montanhas", [path([(0,276),(42,228),(83,267),(132,197),(174,254),(221,212),(276,271),(320,235)], 0xFF7DA6BA, 4),
                                            path([(0,307),(58,276),(105,299),(166,266),(214,300),(269,271),(320,294)], green, 4)]),
                        layer("Primeiro plano", [path([(0,350),(52,331),(98,349),(149,334),(201,354),(260,329),(320,350)], green, 5)] +
                              pine(36,385,87,green) + pine(284,386,93,green) +
                              [path([(145,383),(155,360),(165,383)],brown,3),dot(190,365,coral,5)]),
                    ])
                ], tag="FUNDOS"),
                template("sunset-horizon", "Por do sol", "Sol baixo, montanhas e reflexos para uma cena cinematografica.", 0xe3a4, 0xFFFF9A75, [
                    frame("sky-sunset", [
                        layer("Ceu e sol", [ellipse(115,145,207,237,coral,5)] + cloud(250,98,.56,white) +
                              [path([(0,75),(70,83),(126,76),(194,89),(260,78),(320,84)],purple,2)]),
                        layer("Montanhas", [path([(0,265),(47,194),(83,231),(145,155),(188,224),(231,183),(276,242),(320,211)],0xFF705D86,4),
                                            path([(0,305),(52,278),(106,303),(164,269),(222,298),(276,276),(320,294)],0xFFB47767,4)]),
                        layer("Agua e margem", [path([(0,323),(320,323)],dark,3)] +
                              [line(75+i*21,337+(i%2)*5,240-i*9,337+(i%2)*5,0xFFFFC28D,2) for i in range(7)] +
                              [path([(0,375),(78,359),(148,379),(214,357),(320,374)],green,5)]),
                    ])
                ], tag="FUNDOS"),
                template("starry-night", "Ceu estrelado", "Lua, estrelas e silhuetas para cenas noturnas.", 0xe3a5, 0xFF9D91E8, [
                    frame("sky-night", [
                        layer("Noite", [ellipse(238,53,285,100,white,3),ellipse(250,42,291,91,0xFF202A45,4)] +
                              [dot(x,y,yellow,4) for x,y in [(42,59),(88,89),(142,45),(188,116),(288,145),(55,178),(238,207),(116,228)]] +
                              [path([(x-5,y),(x+5,y)],white,2) for x,y in [(68,132),(167,80),(303,56),(199,180)]]),
                        layer("Montanhas", [path([(0,296),(51,240),(102,286),(159,214),(216,283),(264,233),(320,284)],0xFF687B9C,4),
                                            path([(0,329),(55,313),(110,328),(171,306),(231,332),(280,310),(320,325)],0xFF4B617D,4)]),
                        layer("Silhuetas", pine(48,404,102,0xFF314A50)+pine(102,404,78,0xFF314A50)+pine(280,404,108,0xFF314A50)+[path([(0,397),(320,397)],dark,4)]),
                    ])
                ], tag="FUNDOS"),
            ],
        },
        {
            "id": "forest-pack", "name": "Florestas e natureza",
            "description": "Pinheiros, rios, quedas de agua e bosques encantados.",
            "category": "Natureza", "tags": ["floresta","rio","cascata","arvores"],
            "templates": [
                template("pine-forest","Floresta de pinheiros","Arvores em varias profundidades, caminho e vegetacao.",0xe2c6,0xFF72C78C,[
                    frame("forest-pines",[
                        layer("Arvores distantes",pine(55,348,160,0xFF77AA91)+pine(137,339,125,0xFF82B69A)+pine(245,350,162,0xFF77AA91)+pine(295,345,118,0xFF82B69A)),
                        layer("Troncos e copas",broad_tree(104,385,170,green)+broad_tree(224,384,184,0xFF4E986E)+[path([(0,357),(55,348),(112,360),(177,348),(234,361),(320,347)],brown,3)]),
                        layer("Chao e caminho",[path([(0,391),(320,391)],brown,4),path([(152,420),(137,388),(150,357),(175,389),(190,420)],0xFFB48E69,5)]+[dot(x,y,yellow,4) for x,y in [(25,374),(76,397),(270,382),(300,406)]])
                    ])
                ]),
                template("forest-stream","Rio na floresta","Pequeno rio entre rochas, troncos e colinas.",0xe3bf,0xFF5BBFC8,[
                    frame("forest-river",[
                        layer("Montanhas e arvores",[path([(0,246),(60,173),(113,235),(174,151),(226,224),(278,176),(320,233)],0xFF7192A6,4)]+pine(42,365,102,green)+pine(278,368,115,green)),
                        layer("Rio e margens",[path([(135,230),(126,275),(154,314),(143,351),(170,420)],cyan,8),path([(187,227),(202,278),(180,315),(197,355),(180,420)],0xFF9CE7E2,5),path([(0,340),(76,321),(130,340)],green,4),path([(210,340),(259,320),(320,337)],green,4)]),
                        layer("Rochas e plantas",[ellipse(77,330,112,351,0xFF9A9F9D,4),ellipse(220,350,261,371,0xFF9A9F9D,4)]+[path([(x,y),(x-3,y-13),(x+3,y-22)],green,3) for x,y in [(28,313),(52,298),(297,303),(276,310)]]),
                    ])
                ]),
                template("enchanted-grove","Bosque encantado","Arvores antigas e pequenas luzes para uma floresta magica.",0xe3a5,0xFF9C83DC,[
                    frame("forest-magic",[
                        layer("Copas antigas",broad_tree(54,383,255,0xFF477D6E)+broad_tree(267,388,246,0xFF477D6E)+[path([(0,315),(73,294),(137,309),(202,290),(320,308)],0xFF629A83,4)]),
                        layer("Troncos e clareira",[line(54,160,54,408,brown,10),line(267,170,267,410,brown,10),path([(0,410),(85,386),(156,401),(235,380),(320,405)],green,5),ellipse(114,287,207,360,0xFF446E62,3)]),
                        layer("Luzes e detalhes",[dot(x,y,0xFFFFD76C,7) for x,y in [(112,165),(189,210),(234,270),(91,240),(166,116),(284,112)]]+[ellipse(x-9,y-9,x+9,y+9,0xFFFFD76C,1.5) for x,y in [(112,165),(189,210),(234,270),(91,240)]]),
                    ])
                ]),
            ],
        },
        {
            "id": "home-pack", "name": "Casas e interiores",
            "description": "Casa exterior, sala de estar e cozinha com objetos editaveis.",
            "category": "Interiores", "tags": ["casa","sala","cozinha","moveis"],
            "templates": [
                template("cottage-exterior","Casa no jardim","Casa com telhado, janelas, caminho e jardim para personalizar.",0xe88a,0xFFB88CE8,[
                    frame("home-exterior",[
                        layer("Ceu e jardim",[ellipse(248,35,287,74,yellow,3)]+cloud(73,82,.55,white)+[path([(0,332),(320,332)],green,4)]+broad_tree(36,354,105,green)+broad_tree(286,352,98,green)),
                        layer("Casa",[rect(83,184,252,337,0xFFB78E6B,4),path([(66,190),(163,111),(266,190),(66,190)],0xFF8C5C50,5),rect(139,246,194,337,dark,4),ellipse(178,286,184,292,yellow,2),rect(99,211,139,252,blue,3),rect(201,211,236,252,blue,3),rect(218,126,239,176,brown,3)]),
                        layer("Entrada e detalhes",[path([(155,337),(145,371),(175,393),(205,420)],brown,4),path([(0,386),(85,374),(132,390),(215,373),(320,389)],green,5)]+[dot(x,y,coral,5) for x,y in [(72,362),(95,355),(236,366),(258,355)]]),
                    ])
                ],tag="CASA"),
                template("living-room","Sala de estar","Interior com sofa, mesa, janela, televisao, tapete e plantas.",0xe8ba,0xFF72B7C6,[
                    frame("living-room",[
                        layer("Paredes e janela",[rect(22,25,298,384,0xFF9A9EA9,3),line(22,326,298,326,0xFF9A9EA9,3),rect(52,69,139,157,blue,4),line(96,69,96,157,blue,3),line(52,113,139,113,blue,3),path([(22,25),(298,25)],dark,4)]),
                        layer("Moveis",[rect(57,222,196,286,0xFFB87E6F,5),rect(42,197,211,241,0xFFB87E6F,5),rect(106,287,194,311,brown,4),line(114,311,108,326,brown,4),line(184,311,190,326,brown,4),rect(218,211,276,246,dark,4),rect(229,177,265,211,dark,4),rect(232,185,262,207,cyan,2)]),
                        layer("Luz e decoracao",[rect(52,327,275,359,purple,3),line(251,92,251,174,yellow,4),path([(231,95),(271,95),(251,56),(231,95)],yellow,3),ellipse(225,170,277,184,yellow,3)]+broad_tree(37,324,82,green)+[rect(15,166,47,210,brown,3)]),
                    ])
                ],tag="INTERIORES"),
                template("kitchen","Cozinha acolhedora","Armarios, bancada, lava-louca, frigorifico e mesa.",0xe51c,0xFF83B9A3,[
                    frame("kitchen",[
                        layer("Paredes",[rect(22,28,298,385,0xFF929AAA,3),line(22,322,298,322,0xFF929AAA,3),rect(48,51,123,132,blue,4),line(85,51,85,132,blue,3)]),
                        layer("Armarios e bancada",[rect(41,151,235,195,brown,4),rect(42,196,236,286,0xFFB88D6B,4),line(41,220,236,220,brown,3),line(90,151,90,195,brown,3),line(163,151,163,195,brown,3),rect(247,113,285,287,0xFF99B9C7,4),line(247,165,285,165,dark,3),line(266,165,266,287,dark,2)]),
                        layer("Equipamentos e mesa",[rect(70,231,126,281,dark,3),ellipse(80,240,115,255,coral,2),ellipse(80,258,115,273,coral,2),rect(148,228,206,281,cyan,3),ellipse(157,236,199,249,blue,2),line(177,281,177,310,brown,3),rect(135,314,220,331,brown,3),line(142,331,137,354,brown,3),line(211,331,216,354,brown,3)]),
                    ])
                ],tag="INTERIORES"),
            ],
        },
        {
            "id": "city-pack", "name": "Cidades e ruas",
            "description": "Horizontes urbanos, lojas, passeios e telhados noturnos.",
            "category": "Cidade", "tags": ["cidade","rua","edificios","noite"],
            "templates": [
                template("modern-skyline","Cidade moderna","Edificios, janelas, rua e carros em perspetiva.",0xe1d8,0xFF70A9D6,[
                    frame("city-skyline",[
                        layer("Ceu e edificios",cloud(72,67,.52,white)+[rect(20,147,83,330,0xFF788BA7,4),rect(96,94,170,330,0xFF8B91B5,4),rect(183,127,240,330,0xFF718DA3,4),rect(251,174,308,330,0xFF8B91B5,4)]+[rect(34,168+i*37,52,190+i*37,yellow,2) for i in range(4)]+[rect(113,117+i*35,133,139+i*35,cyan,2) for i in range(5)]+[rect(198,150+i*37,215,171+i*37,yellow,2) for i in range(4)]),
                        layer("Rua e passeio",[path([(0,330),(320,330)],dark,4),path([(0,420),(105,330)],dark,4),path([(320,420),(213,330)],dark,4),line(157,353,162,385,yellow,3),line(150,402,154,419,yellow,3)]),
                        layer("Transito e luzes",[rect(87,348,138,371,coral,3),ellipse(96,365,110,379,dark,2),ellipse(119,365,133,379,dark,2),rect(205,378,254,401,cyan,3),ellipse(212,394,224,407,dark,2),ellipse(237,394,249,407,dark,2),line(18,248,18,328,dark,4),ellipse(7,233,29,254,yellow,2)]),
                    ])
                ],tag="URBANO"),
                template("street-shop","Rua comercial","Lojas, passeio, candeeiro e fachadas para uma cena urbana.",0xe88a,0xFFDEA66E,[
                    frame("city-street",[
                        layer("Fachadas",[rect(12,69,112,312,0xFF8F91A8,4),rect(122,39,228,312,0xFFAF8B79,4),rect(237,93,310,312,0xFF778DA4,4),path([(12,116),(112,116)],dark,4),path([(122,88),(228,88)],dark,4),path([(237,140),(310,140)],dark,4)]),
                        layer("Lojas e janelas",[rect(27,151,95,240,cyan,3),rect(141,127,209,211,blue,3),rect(249,169,296,241,yellow,3),line(170,127,170,211,dark,2),line(188,127,188,211,dark,2),rect(145,238,205,312,brown,3),line(175,238,175,312,brown,2)]),
                        layer("Rua e mobiliario",[path([(0,315),(320,315)],dark,4),line(35,251,35,385,dark,4),ellipse(21,234,49,262,yellow,3),rect(237,337,295,352,brown,3),line(244,352,242,375,brown,3),line(287,352,290,375,brown,3),path([(72,420),(123,350),(194,350),(248,420)],0xFFB1A0A0,3)]),
                    ])
                ],tag="URBANO"),
                template("night-rooftops","Telhados da cidade a noite","Predios, antenas, lua e luzes de janelas.",0xe3a5,0xFF8F8BE0,[
                    frame("city-night",[
                        layer("Ceu e lua",[ellipse(236,38,280,82,white,3)]+[dot(x,y,yellow,4) for x,y in [(44,55),(94,101),(178,47),(295,113),(137,151)]]),
                        layer("Predios",[rect(10,174,77,354,0xFF56617C,4),rect(89,123,160,354,0xFF4B5874,4),rect(170,192,235,354,0xFF56617C,4),rect(246,153,311,354,0xFF4B5874,4)]+[rect(24,192+i*35,39,211+i*35,cyan,2) for i in range(4)]+[rect(103,144+i*32,120,164+i*32,yellow,2) for i in range(5)]+[rect(264,173+i*36,286,193+i*36,coral,2) for i in range(4)]),
                        layer("Telhados e antenas",[line(0,355,320,355,dark,4),line(48,174,48,134,white,3),path([(40,135),(48,119),(56,135)],white,2),line(205,192,205,149,purple,3),line(195,159,215,159,purple,2),path([(0,398),(320,398)],dark,5)]),
                    ])
                ],tag="URBANO"),
            ],
        },
        {
            "id": "action-pack", "name": "Personagens e acao",
            "description": "Lutadores em camadas independentes, poses e sequencias de combate sem violencia grafica.",
            "category": "Acao", "tags": ["personagens","luta","poses","stickman"],
            "templates": [
                template("sparring-sequence","Treino de luta - sequencia","Oito frames com aproximacao, soco, bloqueio, pontape e esquiva. Cada lutador tem a sua propria camada.",0xe91d,0xFFFF9977,[
                    make_fight_frame("01","guard","guard"),make_fight_frame("02","advance","guard",-4,0),make_fight_frame("03","punch","block",0,0),make_fight_frame("04","guard","advance",0,-3),make_fight_frame("05","dodge","kick",-4,0),make_fight_frame("06","jump","guard",-8,2,342,355),make_fight_frame("07","guard","dodge",0,0),make_fight_frame("08","guard","guard")
                ],tag="ACAO"),
                template("dojo-duel","Duelo no dojo","Sala de treino com dois personagens em pose de combate e elementos de fundo.",0xe91d,0xFFFFB15C,[
                    frame("dojo-duel",[
                        layer("Dojo",[rect(22,40,298,378,0xFFB68D6D,3),path([(22,110),(298,110)],brown,4),path([(22,322),(298,322)],brown,4),rect(56,60,103,109,0xFF8D675C,3),rect(217,60,264,109,0xFF8D675C,3)]),
                        layer("Piso",[path([(22,378),(298,378)],dark,4)]+[line(40+i*52,322,40+i*52,378,0xFFB68D6D,1.5) for i in range(5)]),
                        layer("Personagens",person(108,350,"guard",0xFF58B7E2)+person(220,350,"guard",0xFFFF9578)),
                    ])
                ],tag="ACAO"),
                template("hero-poses","Poses de combate","Poses para iniciar uma luta, uma esquiva ou uma defesa.",0xe91d,0xFF8FC9F5,[
                    frame("hero-poses",[
                        layer("Guia",[path([(25,372),(295,372)],0xFF65728A,3),ellipse(46,300,114,385,0xFF65728A,2),ellipse(205,300,273,385,0xFF65728A,2)]),
                        layer("Personagem 1",person(82,370,"punch",0xFF58B7E2)),
                        layer("Personagem 2",person(238,370,"block",0xFFFF9578)),
                    ])
                ],tag="PERSONAGENS"),
            ],
        },
        {
            "id": "fantasy-pack", "name": "Fantasia e aventura",
            "description": "Castelos, cavernas, cristais e portais para mundos imaginarios.",
            "category": "Fantasia", "tags": ["castelo","caverna","magia","aventura"],
            "templates": [
                template("hilltop-castle","Castelo na colina","Castelo com torres, bandeiras, muralhas e caminho sinuoso.",0xe88a,0xFFB69AE8,[
                    frame("castle-hill",[
                        layer("Ceu",cloud(77,82,.55,white)+[dot(270,74,yellow,5),dot(291,109,yellow,4)]),
                        layer("Castelo",[path([(62,276),(62,173),(89,173),(89,142),(118,142),(118,173),(145,173),(145,124),(174,124),(174,173),(203,173),(203,145),(231,145),(231,173),(259,173),(259,276)],0xFF837AA6,4),path([(49,276),(49,205),(88,205),(88,276)],purple,4),path([(145,276),(145,187),(176,187),(176,276)],purple,4),path([(232,276),(232,205),(271,205),(271,276)],purple,4)]+[line(x,y-18,x,y-35,coral,3) for x,y in [(104,142),(159,124),(245,145)]]+[rect(145,225,176,276,dark,3)]),
                        layer("Colina e caminho",[path([(0,320),(67,290),(124,306),(189,285),(252,305),(320,284)],green,5),path([(158,276),(144,317),(171,344),(153,380),(182,420)],brown,5),path([(0,404),(320,404)],green,4)]),
                    ])
                ],tag="FANTASIA"),
                template("dragon-cave","Caverna do dragao","Entrada rochosa, cristais e um pequeno tesouro.",0xe3c9,0xFF7F9CB7,[
                    frame("dragon-cave",[
                        layer("Rochas",[path([(0,0),(35,45),(42,105),(76,137),(61,210),(96,270),(68,330),(0,355)],0xFF69788C,5),path([(320,0),(285,45),(280,111),(249,151),(265,218),(230,281),(251,340),(320,355)],0xFF69788C,5)]),
                        layer("Caverna",[path([(70,355),(82,245),(111,176),(160,149),(209,176),(238,245),(250,355)],0xFF566174,5),path([(95,352),(108,266),(132,218),(160,205),(189,218),(212,266),(225,352)],0xFF28384C,4),path([(0,355),(75,355),(115,375),(205,375),(250,355),(320,355)],brown,4)]),
                        layer("Cristais e tesouro",[path([(98,301),(109,258),(122,301)],cyan,4),path([(205,305),(216,252),(230,305)],purple,4),ellipse(132,345,188,376,yellow,4)]+[dot(x,y,white,4) for x,y in [(143,349),(160,340),(177,350)]]),
                    ])
                ],tag="FANTASIA"),
                template("magic-portal","Portal magico","Portal circular com runas, estrelas e energia a sair do chao.",0xe3a5,0xFF9C83DC,[
                    frame("magic-portal",[
                        layer("Fundo",[path([(0,343),(320,343)],0xFF5C667C,4)]+[dot(x,y,yellow,4) for x,y in [(36,73),(78,124),(266,64),(287,150),(46,246)]]),
                        layer("Portal",[ellipse(96,91,224,310,purple,6),ellipse(111,105,209,294,cyan,3),ellipse(126,120,194,278,0xFF6D69BE,2),path([(160,90),(176,61),(189,91)],white,3),path([(96,201),(72,211),(96,224)],white,3),path([(224,201),(248,211),(224,224)],white,3)]),
                        layer("Energia",[path([(160+i*5-15,311),(150+i*5-12,330),(164+i*5-9,340)],cyan,2) for i in range(7)]+[dot(x,y,coral,5) for x,y in [(75,175),(246,153),(89,272),(230,280)]]),
                    ])
                ],tag="FANTASIA"),
            ],
        },
    ]


def make_noise(rng):
    return rng.uniform(-1.0, 1.0)


def sound_sample(sound_id, duration, sample_rate=SAMPLE_RATE):
    rng = random.Random(sum(ord(c) for c in sound_id) * 97)
    count = int(duration * sample_rate)
    noise_values = [make_noise(rng) for _ in range(count + 12)]
    values = []
    for i in range(count):
        t = i / sample_rate
        n = noise_values[i]
        if sound_id == "soft-whoosh":
            env = max(0.0, math.sin(math.pi * t / duration)) ** 1.35
            value = env * ((n - noise_values[max(0, i - 1)]) * .24 +
                           math.sin(2 * math.pi * (90 + 520 * t) * t) * .08)
        elif sound_id == "cartoon-pop":
            env = math.exp(-8 * t)
            freq = 620 * math.exp(-3.5 * t) + 115
            value = math.sin(2 * math.pi * freq * t) * env * .45 + n * math.exp(-85 * t) * .18
        elif sound_id == "light-footsteps":
            value = 0.0
            for at in (.12, .62, 1.16, 1.72):
                dt = t - at
                if 0 <= dt < .32:
                    env = math.exp(-18 * dt)
                    value += math.sin(2 * math.pi * (92 - 18 * dt) * dt) * env * .34
                    value += n * env * .12
        elif sound_id == "forest-birds":
            value = (noise_values[i] + noise_values[max(0, i - 3)] + noise_values[max(0, i - 9)]) / 3 * .055
            for at, freq in ((.28,1900),(.78,2350),(1.48,2050),(2.16,2500),(2.62,1800)):
                dt = t - at
                if 0 <= dt < .25:
                    env = math.sin(math.pi * dt / .25) ** 1.4
                    value += math.sin(2 * math.pi * (freq + 650 * dt) * dt) * env * .12
        elif sound_id == "rain-window":
            value = n * .12 + noise_values[max(0, i - 4)] * .05
            for k in range(13):
                at = (k * .257 + .08) % 3.05
                dt = t - at
                if 0 <= dt < .13:
                    value += math.sin(2 * math.pi * (420 - 1300 * dt) * dt) * math.exp(-31 * dt) * .13
        elif sound_id == "punch-impact":
            thump = math.sin(2 * math.pi * 72 * t) * math.exp(-13 * (t - .025)) * .48 if t >= .025 else 0
            crack = n * math.exp(-55 * max(0, t - .035)) * .27 if t > .035 else 0
            sub = math.sin(2 * math.pi * 145 * t) * math.exp(-20 * (t - .02)) * .12 if t > .02 else 0
            value = thump + crack + sub
        elif sound_id == "magic-sparkle":
            value = 0.0
            for at, freq, amp in ((.06,880,.22),(.32,1320,.18),(.64,1760,.15),(1.02,1175,.14),(1.42,1980,.1),(1.78,1568,.12)):
                dt = t - at
                if dt >= 0:
                    env = math.exp(-3.6 * dt)
                    value += math.sin(2 * math.pi * freq * dt) * env * amp
                    value += math.sin(2 * math.pi * freq * 2.01 * dt) * env * amp * .16
        else:  # wood-door-creak
            p = max(0.0, min(1.0, (t - .12) / 1.45))
            squeak = math.sin(2 * math.pi * (260 + 380 * p) * t) * (.08 + .1 * math.sin(math.pi * p)) if .12 < t < 1.6 else 0
            wood = n * math.exp(-5 * t) * .14 if t > .03 else 0
            latch = math.sin(2 * math.pi * 100 * (t - 1.55)) * math.exp(-35 * (t - 1.55)) * .3 if t > 1.55 else 0
            value = squeak + wood + latch
        values.append(value)
    peak = max((abs(v) for v in values), default=1.0)
    scale = min(1.0, .82 / peak) if peak else 1.0
    samples = bytearray()
    for i, value in enumerate(values):
        edge = min(1.0, i / (sample_rate * .02), (count - 1 - i) / (sample_rate * .04))
        clipped = max(-1.0, min(1.0, value * scale * max(0.0, edge)))
        samples.extend(struct.pack("<h", round(clipped * 32767)))
    return bytes(samples)


def write_wav(path, duration, sound_id):
    pcm = sound_sample(sound_id, duration)
    path.parent.mkdir(parents=True, exist_ok=True)
    with wave.open(str(path), "wb") as output:
        output.setnchannels(1)
        output.setsampwidth(2)
        output.setframerate(SAMPLE_RATE)
        output.writeframes(pcm)
    return path.read_bytes()


def main():
    pack_catalog = {"schemaVersion": 1, "updatedAt": "2026-11-26", "packs": []}
    for pack in build_packs():
        data = write_json(PACK_FILES / f"{pack['id']}.json", {
            "schemaVersion": 1,
            "id": pack["id"],
            "name": pack["name"],
            "description": pack["description"],
            "templates": pack["templates"],
        })
        if len(data) > MAX_PACK_BYTES:
            raise SystemExit(f"Pack too large: {pack['id']}")
        pack_catalog["packs"].append({
            "id": pack["id"],
            "title": pack["name"],
            "description": pack["description"],
            "category": pack["category"],
            "tags": pack["tags"],
            "path": f"files/{pack['id']}.json",
            "sizeBytes": len(data),
            "sha256": sha256(data),
            "templateCount": len(pack["templates"]),
        })

    # Retain the two original starter packs, now served from the same CDN path.
    legacy = [
        ("space-pack", "Ceus", ["espaco", "planeta", "movimento"]),
        ("character-pack", "Personagens", ["personagens", "expressoes", "poses"]),
    ]
    for pack_id, category, tags in legacy:
        source = ROOT / "content" / "packs" / f"{pack_id}.json"
        if not source.exists():
            continue
        data = source.read_bytes()
        parsed = json.loads(data.decode("utf-8"))
        destination = PACK_FILES / f"{pack_id}.json"
        destination.write_bytes(data)
        pack_catalog["packs"].append({
            "id": pack_id,
            "title": parsed["name"],
            "description": parsed.get("description", ""),
            "category": category,
            "tags": tags,
            "path": f"files/{pack_id}.json",
            "sizeBytes": len(data),
            "sha256": sha256(data),
            "templateCount": len(parsed.get("templates", [])),
        })

    write_json(DOCS / "packs" / "catalog.json", pack_catalog)

    specs = [
        ("soft-whoosh", "Passagem de ar", "Movimento", "Sopro curto e suave para movimentos de camera, entradas e transicoes.", 1.35),
        ("cartoon-pop", "Pop de cartoon", "Cartoon", "Pequeno pop com ataque brilhante e queda divertida.", .62),
        ("light-footsteps", "Passos leves", "Movimento", "Sequencia curta de quatro passos sobre uma superficie firme.", 2.2),
        ("forest-birds", "Aves na floresta", "Ambiente", "Ambiencia curta de vento macio e pequenos cantos de aves.", 3.2),
        ("rain-window", "Chuva na janela", "Ambiente", "Chuva continua com gotas pequenas a bater no vidro e no chao.", 3.2),
        ("punch-impact", "Impacto de combate", "Combate", "Impacto seco e estilizado para socos, bloqueios e quedas sem violencia grafica.", .58),
        ("magic-sparkle", "Brilho magico", "Fantasia", "Pequenos sinos cintilantes para portais, magia e transicoes.", 2.4),
        ("wood-door-creak", "Porta de madeira", "Casa", "Som de dobradica e madeira a abrir devagar.", 1.8),
    ]
    audio_catalog = []
    for sound_id, name, category, description, duration in specs:
        audio_path = AUDIO_FILES / f"{sound_id}.wav"
        audio_data = write_wav(audio_path, duration, sound_id)
        if len(audio_data) > MAX_AUDIO_BYTES:
            raise SystemExit(f"Audio file too large: {sound_id}")
        audio_catalog.append({
            "id": sound_id,
            "name": name,
            "category": category,
            "description": description,
            "file": f"files/{sound_id}.wav",
            "preview": f"files/{sound_id}.wav",
            "pro": False,
            "license": "AnimPro Original Sound - use in AnimPro projects without attribution",
            "sourceUrl": "https://nexauren1.github.io/Animations-2D-/audio/README.md",
            "sizeBytes": len(audio_data),
            "durationSeconds": duration,
            "sha256": sha256(audio_data),
        })

    write_json(DOCS / "audio" / "catalog.json", audio_catalog)
    (ROOT / "audio" / "catalog.json").write_text(
        json.dumps(audio_catalog, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )

    # Verify every download link's exact size and digest before Pages deployment.
    for entry in pack_catalog["packs"]:
        data = (PACK_FILES / f"{entry['id']}.json").read_bytes()
        assert len(data) == entry["sizeBytes"]
        assert sha256(data) == entry["sha256"]
    for entry in audio_catalog:
        data = (AUDIO_FILES / Path(entry["file"]).name).read_bytes()
        assert len(data) == entry["sizeBytes"]
        assert sha256(data) == entry["sha256"]

    print(f"Generated {len(pack_catalog['packs'])} scene packs and {len(audio_catalog)} original sounds.")
    print(f"Scene pack templates: {sum(p['templateCount'] for p in pack_catalog['packs'])}.")
    print("All catalogue sizes and SHA-256 checks passed.")


if __name__ == "__main__":
    main()
