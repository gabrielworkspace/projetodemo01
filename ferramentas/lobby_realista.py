"""Deixa o lobby (mapas/Lobby.rbxmx) com cara realista, mantendo tudo o que foi editado no Studio:
cada peça continua no mesmo lugar, só troca o material (grama, terra, pedra, madeira, tecido,
metal) e as cores ficam mais naturais (menos saturadas e um pouco mais escuras).

    py ferramentas/lobby_realista.py

Guarda uma cópia do arquivo antigo em .backups/ antes de mudar. Para voltar ao estilo liso,
restaure a cópia (ou o arquivo pelo git).
"""
import colorsys
import os
import re
import shutil
import xml.etree.ElementTree as ET
from datetime import datetime

RAIZ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ARQUIVO = os.path.join(RAIZ, "mapas", "Lobby.rbxmx")

# valores de Enum.Material
M = {
    "Plastic": 256, "SmoothPlastic": 272, "Neon": 288, "Wood": 512, "WoodPlanks": 528,
    "Marble": 784, "Basalt": 788, "Slate": 800, "Concrete": 816, "Limestone": 820,
    "Granite": 832, "Pavement": 836, "Brick": 848, "Pebble": 864, "Cobblestone": 880,
    "Rock": 896, "Sandstone": 912, "Metal": 1088, "Grass": 1280, "LeafyGrass": 1284,
    "Sand": 1296, "Fabric": 1312, "Mud": 1344, "Ground": 1360, "Glass": 1568,
}

# nome da peça -> (material, saturação, brilho). saturação/brilho multiplicam os da cor atual.
# None no material = mantém o material; None nas cores = mantém a cor.
REGRAS = {
    # chão e vegetação
    "Grama": ("Grass", 0.55, 0.62), "Colina": ("Grass", 0.55, 0.6), "Mancha": ("Grass", 0.55, 0.6),
    "Talo": ("Grass", 0.6, 0.65), "Taboa": ("Grass", 0.6, 0.65), "FolhaDeLirio": ("Grass", 0.6, 0.65),
    "Flor": (None, 0.7, 0.85), "FlorDeLirio": (None, 0.7, 0.85), "Miolo": (None, 0.7, 0.8),
    "Praia": ("Sand", 0.55, 0.82), "Margem": ("Sand", 0.55, 0.78), "Ponta": ("Sand", 0.55, 0.8),
    "Caminho": ("Ground", 0.5, 0.62), "Raio": ("Cobblestone", 0.3, 0.72),
    # pedra
    "Praca": ("Cobblestone", 0.3, 0.78), "Plataforma": ("Pavement", 0.35, 0.78), "Borda": ("Cobblestone", 0.35, 0.72),
    "Arco": ("Limestone", 0.22, 0.78), "Ameia": ("Limestone", 0.22, 0.76), "Pilar": ("Limestone", 0.22, 0.76),
    "Pedestal": ("Limestone", 0.22, 0.76), "Degrau": ("Slate", 0.22, 0.72), "Faixa": ("Limestone", 0.22, 0.78),
    "TopoPedestal": ("Slate", 0.22, 0.75), "BasePilar": ("Slate", 0.3, 0.75), "Pe": ("Slate", 0.3, 0.75),
    "PedraRunica": ("Slate", 0.3, 0.78), "Tigela": ("Metal", 0.3, 0.8),
    # madeira
    "Poste": ("Wood", 0.65, 0.72), "Braco": ("Wood", 0.65, 0.72), "Estaca": ("Wood", 0.65, 0.72),
    "Cabo": ("Wood", 0.65, 0.72), "Espiga": ("Wood", 0.65, 0.72), "Flecha": ("Wood", 0.65, 0.75),
    "Topo": ("WoodPlanks", 0.65, 0.72), "Tabua": ("WoodPlanks", 0.65, 0.72), "Teto": ("WoodPlanks", 0.65, 0.72),
    "Ripa": ("WoodPlanks", 0.55, 0.7),
    # telhados, tecidos e metais
    "Telhado": ("Slate", 0.3, 0.6), "Toldo": ("Fabric", 0.7, 0.78), "Estandarte": ("Fabric", 0.75, 0.8),
    "PontaEstandarte": ("Fabric", 0.75, 0.8), "Livro": ("Fabric", 0.7, 0.8), "Paginas": (None, 0.6, 0.9),
    "Capitel": ("Metal", 0.7, 0.75), "Aro": ("Metal", 0.7, 0.75), "FaixaEstandarte": ("Metal", 0.7, 0.75),
    "Guarda": ("Metal", 0.7, 0.75), "MolduraEmblema": ("Metal", 0.7, 0.75), "PontaEmblema": ("Metal", 0.7, 0.75),
    "Moeda": ("Metal", 0.8, 0.85), "Lamina": ("Metal", 0.5, 0.85), "Caixa": ("Glass", None, None),
    "Cristal": ("Glass", None, None),
    # pacote de natureza
    "Grass1": ("Grass", 0.55, 0.62), "Grass2": ("Grass", 0.55, 0.62), "Grass3": ("Grass", 0.55, 0.62),
    "Leaf": ("LeafyGrass", 0.55, 0.62), "Fern1": ("Grass", 0.6, 0.65), "Fern2": ("Grass", 0.6, 0.65),
    "Fern3": ("Grass", 0.6, 0.65), "Trunk": ("Wood", 0.6, 0.8),
    "HallowLogSmall": ("Wood", 0.6, 0.72), "Stick1": ("Wood", 0.6, 0.72), "Stick2": ("Wood", 0.6, 0.72),
    "StickCluster": ("Wood", 0.6, 0.72),
    "Stem1": (None, 0.6, 0.85), "Stem2": (None, 0.6, 0.85), "LargeStem": (None, 0.6, 0.85),
    "Tip": (None, 0.7, 0.8), "LargeStop": (None, 0.7, 0.8),
}
# pedras do pacote (Rock1..10, LargeRock1..3)
PEDRA = ("Rock", 0.2, 0.82)
# o que é sinal de classe ou mágico continua com a cor (só o material liso vira plástico)
MANTER = {"Chama", "Runa", "RunaPedra", "SimboloEstandarte", "Emblema", "AnelClasse", "FaixaPedestal", "Limite", "Agua"}


def natural(rgb, sat, val):
    h, s, v = colorsys.rgb_to_hsv(*(c / 255 for c in rgb))
    r, g, b = colorsys.hsv_to_rgb(h, s * sat, v * val)
    return tuple(max(0, min(255, round(c * 255))) for c in (r, g, b))


def main():
    os.makedirs(os.path.join(RAIZ, ".backups"), exist_ok=True)
    copia = os.path.join(RAIZ, ".backups", datetime.now().strftime("Lobby_%Y%m%d_%H%M%S.rbxmx"))
    shutil.copy2(ARQUIVO, copia)
    texto = open(ARQUIVO, encoding="utf-8").read()
    raiz = ET.fromstring(texto)
    mudadas = 0
    for item in raiz.iter("Item"):
        if item.get("class") not in ("Part", "MeshPart", "WedgePart", "CornerWedgePart", "TrussPart"):
            continue
        props = item.find("Properties")
        nome_el = props.find("string[@name='Name']")
        nome = nome_el.text if nome_el is not None else ""
        if nome in MANTER:
            continue
        regra = REGRAS.get(nome)
        if regra is None and re.fullmatch(r"(Large)?Rock\d+", nome or ""):
            regra = PEDRA
        material_el = props.find("token[@name='Material']")
        cor_el = props.find("Color3uint8[@name='Color3uint8']")
        if regra is None:
            # resto: só cores mais naturais
            regra = (None, 0.7, 0.85)
        material, sat, val = regra
        if material and material_el is not None:
            material_el.text = str(M[material])
        if sat is not None and cor_el is not None:
            valor = int(cor_el.text) & 0xFFFFFF
            rgb = ((valor >> 16) & 255, (valor >> 8) & 255, valor & 255)
            r, g, b = natural(rgb, sat, val)
            cor_el.text = str(0xFF000000 | (r << 16) | (g << 8) | b)
        mudadas += 1
    # mantém a declaração e o formato do Studio: escreve de volta só a árvore
    saida = ET.tostring(raiz, encoding="unicode")
    with open(ARQUIVO, "w", encoding="utf-8") as arquivo:
        arquivo.write(saida)
    print(f"{mudadas} peças do lobby ficaram realistas (cópia do original em {os.path.relpath(copia, RAIZ)})")


if __name__ == "__main__":
    main()
