"""Copia um pacote de cenário (árvores, pedras, cogumelos...) salvo no Studio para cenario/.

Uso: py ferramentas/extrair_cenario.py <arquivo .rbxlx salvo pelo Studio> <nome no Workspace> <saida.rbxmx>

O pacote sai limpo para virar biblioteca do gerador do lobby (ferramentas/gerar_lobby.py):
- sem scripts e sem soldas (tudo fica ancorado);
- sem texturas (o jogo usa peças lisas, estilo fantasia; textura realista destoa);
- com as cores mais vivas: verdes saturados, marrons quentes e pedras lilás-acinzentadas.
"""
import colorsys
import copy
import sys
import xml.etree.ElementTree as ET


def nome(item):
    n = item.find("./Properties/string[@name='Name']")
    return n.text if n is not None else "?"


def cor_viva(rgb):
    r, g, b = (c / 255 for c in rgb)
    h, s, v = colorsys.rgb_to_hsv(r, g, b)
    grau = h * 360
    if s < 0.15:
        if v > 0.68:  # creme / branco (talos de cogumelo, neve): só clareia um pouco
            novo = colorsys.hsv_to_rgb(h, min(s, 0.12), min(0.97, v * 1.12))
        else:  # pedra cinza: lilás-acinzentado claro, de fantasia
            novo = colorsys.hsv_to_rgb(255 / 360, 0.13, min(0.8, v * 1.4))
    elif 65 <= grau <= 175:  # folhas e grama: verde vivo, puxando para o amarelado
        novo = colorsys.hsv_to_rgb((grau - 6) / 360, min(0.7, s * 1.35), min(0.84, v * 1.42))
    elif grau < 55 or grau > 330:  # madeira, terra, chapéus vermelhos: quente e mais claro
        novo = colorsys.hsv_to_rgb(h, min(0.72, s * 1.2), min(0.86, v * 1.25))
    else:  # roxos, azuis e verde-água dos cogumelos: mais vivos
        novo = colorsys.hsv_to_rgb(h, min(0.75, s * 1.3), min(0.9, v * 1.25))
    return tuple(round(c * 255) for c in novo)


def _ativos(item):
    """Árvores, pedras, cogumelos... (modelos e peças soltas dentro das pastas do pacote)."""
    for filho in item.findall("Item"):
        if filho.get("class") == "Folder":
            yield from _ativos(filho)
        elif filho.get("class") in ("Model", "MeshPart", "Part"):
            yield filho


def centralizar(pacote):
    """Põe a base (centro de baixo) de cada ativo na origem: colado no Studio, ele aparece no
    meio do mapa (pronto para arrastar), e não onde o pacote estava."""
    raizes = [pacote] if pacote.get("class") != "Folder" and pacote.get("class") != "Model" else list(_ativos(pacote))
    if pacote.get("class") == "Model" and not raizes:
        raizes = [pacote]
    for ativo in raizes:
        # (iter já inclui o próprio ativo; somar [ativo] fazia a MeshPart solta andar duas vezes)
        pecas = [p for p in ativo.iter("Item") if p.get("class") in ("MeshPart", "Part")]
        menor = [float("inf")] * 3
        maior = [float("-inf")] * 3
        for p in pecas:
            e = p.find("./Properties/CoordinateFrame[@name='CFrame']")
            pos = [float(e.find(k).text) for k in "XYZ"]
            tam = [float(c.text) for c in p.find("./Properties/Vector3[@name='size']")]
            rot = [[abs(float(e.find(f"R{i}{j}").text)) for j in range(3)] for i in range(3)]
            meio = [sum(rot[i][j] * tam[j] / 2 for j in range(3)) for i in range(3)]
            for i in range(3):
                menor[i] = min(menor[i], pos[i] - meio[i])
                maior[i] = max(maior[i], pos[i] + meio[i])
        if not pecas:
            continue
        base = [(menor[0] + maior[0]) / 2, menor[1], (menor[2] + maior[2]) / 2]
        for e in [p.find("./Properties/CoordinateFrame[@name='CFrame']") for p in pecas] +                  list(ativo.iter("CFrame")):
            if e is None:
                continue
            for i, k in enumerate("XYZ"):
                e.find(k).text = f"{float(e.find(k).text) - base[i]:.4f}"


def main():
    origem, nome_pacote, saida = sys.argv[1], sys.argv[2], sys.argv[3]
    raiz = ET.parse(origem).getroot()
    compartilhados = {}
    for bloco in raiz.findall("SharedStrings"):
        for texto in bloco:
            compartilhados[texto.get("md5")] = texto.text or ""
    workspace = next(s for s in raiz.findall("Item") if s.get("class") == "Workspace")
    pacote = copy.deepcopy(next(f for f in workspace.findall("Item") if nome(f) == nome_pacote))

    removidos = 0
    for pai in list(pacote.iter("Item")):
        for filho in list(pai.findall("Item")):
            if filho.get("class") in ("Script", "LocalScript", "ModuleScript", "Weld", "WeldConstraint", "Motor6D", "Snap"):
                pai.remove(filho)
                removidos += 1
    trocas = {}
    for peca in [pacote] + list(pacote.iter("Item")):
        if peca.get("class") not in ("Part", "MeshPart", "WedgePart", "CornerWedgePart", "UnionOperation"):
            continue
        props = peca.find("Properties")
        ancorado = props.find("./bool[@name='Anchored']")
        if ancorado is not None:
            ancorado.text = "true"
        textura = props.find("./Content[@name='TextureID']")
        if textura is not None:
            for filho in list(textura):
                textura.remove(filho)
            ET.SubElement(textura, "null")
        cor = props.find("./Color3uint8[@name='Color3uint8']")
        if cor is not None:
            valor = int(cor.text)
            rgb = ((valor >> 16) & 255, (valor >> 8) & 255, valor & 255)
            novo = cor_viva(rgb)
            trocas[rgb] = novo
            cor.text = str(0xFF000000 | (novo[0] << 16) | (novo[1] << 8) | novo[2])
        for p in list(props):
            if p.get("name") in ("UniqueId", "HistoryId"):
                props.remove(p)

    centralizar(pacote)
    usados = {e.text.strip() for e in pacote.iter("SharedString") if e.text}
    documento = ET.Element("roblox", {"version": "4"})
    documento.append(pacote)
    if usados:
        bloco = ET.SubElement(documento, "SharedStrings")
        for md5 in sorted(usados):
            ET.SubElement(bloco, "SharedString", {"md5": md5}).text = compartilhados.get(md5, "")
    ET.ElementTree(documento).write(saida, encoding="utf-8")
    print(f"{nome_pacote} -> {saida}: {removidos} script(s)/solda(s) removido(s)")
    for antes, depois in sorted(trocas.items()):
        print(f"  cor {antes} -> {depois}")


if __name__ == "__main__":
    main()
