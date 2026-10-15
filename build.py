"""Gera MasmorraDasCartas.rbxlx a partir do default.project.json, sem precisar do Rojo.

Uso:  py build.py
Depois abra o arquivo .rbxlx no Roblox Studio.

Também gera sourcemap.json (usado por ferramentas de análise de código Luau).

Modelos salvos do Studio (.rbxmx, "Save to File...") dentro das pastas do projeto também
entram no jogo, por exemplo os efeitos da pasta vfx/ (ReplicatedStorage > EfeitosVFX).
"""

import json
import os
import sys
import xml.etree.ElementTree as ET
from xml.sax.saxutils import escape

RAIZ = os.path.dirname(os.path.abspath(__file__))
PROJETO = os.path.join(RAIZ, "default.project.json")
SAIDA = os.path.join(RAIZ, "MasmorraDasCartas.rbxlx")
SOURCEMAP = os.path.join(RAIZ, "sourcemap.json")

# Classes que o Rojo deduz pelo nome quando ficam dentro de StarterPlayer
FILHOS_ESPECIAIS = {"StarterPlayer": {"StarterPlayerScripts", "StarterCharacterScripts"}}


def classe_do_arquivo(nome):
    """Retorna (classe, nome_da_instancia) para um arquivo de script, ou None."""
    for sufixo, classe in ((".server.luau", "Script"), (".server.lua", "Script"),
                           (".client.luau", "LocalScript"), (".client.lua", "LocalScript"),
                           (".luau", "ModuleScript"), (".lua", "ModuleScript")):
        if nome.endswith(sufixo):
            return classe, nome[: -len(sufixo)]
    return None


def no_do_caminho(caminho, nome):
    if os.path.isdir(caminho):
        filhos = []
        for entrada in sorted(os.listdir(caminho)):
            filho = no_do_caminho(os.path.join(caminho, entrada), None)
            if filho:
                filhos.append(filho)
        return {"name": nome or os.path.basename(caminho), "className": "Folder", "children": filhos, "props": {}}
    if caminho.lower().endswith(".rbxmx"):
        return no_do_modelo(caminho)
    info = classe_do_arquivo(os.path.basename(caminho))
    if not info:
        return None
    classe, nome_instancia = info
    with open(caminho, encoding="utf-8") as arquivo:
        codigo = arquivo.read().replace("\r\n", "\n")
    return {
        "name": nome or nome_instancia,
        "className": classe,
        "source": codigo,
        "filePaths": [os.path.relpath(caminho, RAIZ).replace("\\", "/")],
        "children": [],
        "props": {},
    }


modelos = 0
textos_compartilhados = {}  # SharedStrings dos modelos (md5 -> conteúdo)


def no_do_modelo(caminho):
    """Modelo .rbxmx salvo pelo Studio: os itens entram no jogo do jeito que estão."""
    global modelos
    modelos += 1
    raiz = ET.parse(caminho).getroot()
    itens = [item for item in raiz if item.tag == "Item"]
    if not itens:
        return None
    # segurança: efeitos e modelos não precisam de script. Pacotes do Toolbox às vezes trazem
    # scripts escondidos (vírus/backdoor) dentro de partículas; eles são removidos aqui.
    for pai in list(raiz.iter("Item")):
        for filho in list(pai.findall("Item")):
            if filho.get("class") in ("Script", "LocalScript", "ModuleScript"):
                nome_script = filho.find("./Properties/string[@name='Name']")
                print(f"AVISO: script '{nome_script.text if nome_script is not None else '?'}' removido de "
                      f"{os.path.relpath(caminho, RAIZ)} (efeitos e modelos não precisam de script)")
                pai.remove(filho)
    # identificadores que o Studio grava em cada objeto (UniqueId, HistoryId): saem daqui e o
    # Studio cria novos ao abrir. Se ficassem, usar o mesmo efeito duas vezes daria o erro
    # "DM contains duplicate Unique ids".
    for propriedades in raiz.iter("Properties"):
        for p in list(propriedades):
            if p.get("name") in ("UniqueId", "HistoryId"):
                propriedades.remove(p)
    # referências únicas (dois modelos salvos do Studio podem repetir as mesmas)
    prefixo = f"M{modelos}_"
    for elemento in raiz.iter():
        if elemento.tag == "Item" and elemento.get("referent"):
            elemento.set("referent", prefixo + elemento.get("referent"))
        elif elemento.tag == "Ref" and elemento.text and elemento.text.strip() not in ("", "null"):
            elemento.text = prefixo + elemento.text.strip()
    for bloco in raiz.findall("SharedStrings"):
        for texto in bloco:
            textos_compartilhados[texto.get("md5")] = texto.text or ""
    primeiro = itens[0]
    nome = primeiro.find("./Properties/string[@name='Name']")
    return {
        "name": nome.text if nome is not None else os.path.basename(caminho)[:-6],
        "className": primeiro.get("class"),
        "xml": [ET.tostring(item, encoding="unicode") for item in itens],
        "filePaths": [os.path.relpath(caminho, RAIZ).replace("\\", "/")],
        "children": [],
        "props": {},
    }


def no_do_projeto(nome, especificacao, nome_pai):
    if "$path" in especificacao:
        no = no_do_caminho(os.path.join(RAIZ, especificacao["$path"]), nome)
    else:
        no = {"name": nome, "className": "Folder", "children": [], "props": {}}

    if "$className" in especificacao:
        no["className"] = especificacao["$className"]
    elif nome_pai == "DataModel":
        no["className"] = nome  # serviços: a classe é o próprio nome
    elif nome in FILHOS_ESPECIAIS.get(nome_pai, ()):
        no["className"] = nome

    no["props"] = especificacao.get("$properties", {})
    for chave, valor in especificacao.items():
        if not chave.startswith("$"):
            no["children"].append(no_do_projeto(chave, valor, no["className"]))
    return no


def propriedade_xml(nome, valor):
    if isinstance(valor, bool):
        return f'<bool name="{nome}">{"true" if valor else "false"}</bool>'
    if isinstance(valor, (int, float)):
        return f'<float name="{nome}">{valor}</float>'
    if isinstance(valor, str):
        return f'<string name="{nome}">{escape(valor)}</string>'
    if isinstance(valor, dict) and len(valor) == 1:
        tipo, dado = next(iter(valor.items()))
        if tipo == "Enum":
            return f'<token name="{nome}">{int(dado)}</token>'
        if tipo == "Color3":
            r, g, b = dado
            return f'<Color3 name="{nome}"><R>{r}</R><G>{g}</G><B>{b}</B></Color3>'
        if tipo in ("Float32", "Float64"):
            return f'<float name="{nome}">{dado}</float>'
        if tipo == "Bool":
            return propriedade_xml(nome, bool(dado))
        if tipo == "String":
            return propriedade_xml(nome, str(dado))
    raise ValueError(f"Tipo de propriedade não suportado em {nome}: {valor!r}")


def cdata(texto):
    return "<![CDATA[" + texto.replace("]]>", "]]]]><![CDATA[>") + "]]>"


contador = 0


def escrever_item(no, linhas, nivel):
    global contador
    if "xml" in no:
        linhas.extend(no["xml"])
        return
    contador += 1
    recuo = "  " * nivel
    linhas.append(f'{recuo}<Item class="{no["className"]}" referent="RBX{contador:08d}">')
    linhas.append(f"{recuo}  <Properties>")
    linhas.append(f'{recuo}    <string name="Name">{escape(no["name"])}</string>')
    if "source" in no:
        linhas.append(f'{recuo}    <ProtectedString name="Source">{cdata(no["source"])}</ProtectedString>')
    for nome, valor in no["props"].items():
        linhas.append(f"{recuo}    {propriedade_xml(nome, valor)}")
    linhas.append(f"{recuo}  </Properties>")
    for filho in no["children"]:
        escrever_item(filho, linhas, nivel + 1)
    linhas.append(f"{recuo}</Item>")


def para_sourcemap(no):
    saida = {"name": no["name"], "className": no["className"]}
    if no.get("filePaths"):
        saida["filePaths"] = no["filePaths"]
    if no["children"]:
        saida["children"] = [para_sourcemap(filho) for filho in no["children"]]
    return saida


def main():
    with open(PROJETO, encoding="utf-8") as arquivo:
        projeto = json.load(arquivo)
    arvore = projeto["tree"]

    servicos = [no_do_projeto(nome, especificacao, "DataModel")
                for nome, especificacao in arvore.items() if not nome.startswith("$")]

    linhas = ['<roblox xmlns:xmime="http://www.w3.org/2005/05/xmlmime" '
              'xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" '
              'xsi:noNamespaceSchemaLocation="http://www.roblox.com/roblox.xsd" version="4">']
    for servico in servicos:
        escrever_item(servico, linhas, 1)
    if textos_compartilhados:
        linhas.append("  <SharedStrings>")
        for md5, conteudo in textos_compartilhados.items():
            linhas.append(f'    <SharedString md5="{escape(md5)}">{escape(conteudo)}</SharedString>')
        linhas.append("  </SharedStrings>")
    linhas.append("</roblox>")

    with open(SAIDA, "w", encoding="utf-8", newline="\n") as arquivo:
        arquivo.write("\n".join(linhas) + "\n")

    sourcemap = {"name": projeto.get("name", "Jogo"), "className": "DataModel",
                 "filePaths": ["default.project.json"],
                 "children": [para_sourcemap(servico) for servico in servicos]}
    with open(SOURCEMAP, "w", encoding="utf-8", newline="\n") as arquivo:
        json.dump(sourcemap, arquivo, indent=2, ensure_ascii=False)

    scripts = sum(1 for linha in linhas if 'name="Source"' in linha)
    extra = f" e {modelos} modelo(s) .rbxmx" if modelos else ""
    print(f"Pronto! {os.path.basename(SAIDA)} gerado com {scripts} scripts{extra}.")


if __name__ == "__main__":
    sys.exit(main())
