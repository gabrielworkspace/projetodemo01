# Masmorra das Cartas

Roguelike cooperativo para Roblox, de 1 a 4 jogadores, inspirado em Ember Knights e Warcraft. Escolha entre **Cavaleiro**, **Mago** e **Arqueiro** e desça por salas sorteadas. Use combos, esquiva e supremos, e monte sua build com cartas próprias da sua classe. A cada 5 salas vem um chefe, e depois dele você decide: **subir e guardar o ouro** ou **descer mais fundo**.

## Abrir e jogar

1. Instale o [Roblox Studio](https://create.roblox.com/).
2. Dê dois cliques em `MasmorraDasCartas.rbxlx` (ou, no Studio, use **File > Open from File**).
3. Clique em **Play** (F5).

Tudo é criado por código quando o jogo começa (terreno, salas, monstros, interface). Por isso, no modo de edição, o mundo aparece vazio.

**Testar em grupo no Studio:** aba **Test > Clients and Servers**, escolha 2 jogadores e clique em **Start**.

## Controles

| Ação | Computador | Celular | Controle |
|---|---|---|---|
| Atacar (combo de 3) | Segurar clique esquerdo (mira no mouse) | Botão ⚔️ (mira sozinho) | R2 |
| Habilidade | E | Botão de cima | X |
| Esquiva | Q | Botão 💨 | B |
| Supremo | R (com a barra dourada cheia) | Botão do topo | Y |

## As classes

| Classe | Estilo | Habilidade (E) | Supremo (R) |
|---|---|---|---|
| 🛡️ Cavaleiro | Corpo a corpo, muita vida, atrai os inimigos | Redemoinho | Julgamento (esmaga o chão e atordoa) |
| 🔮 Mago | Orbes que explodem, frágil | Meteoro | Tempestade Arcana |
| 🏹 Arqueiro | Rápido, atira de longe | Chuva de Flechas | Saraivada |

Cada classe tem **11 cartas próprias**, e existem **11 cartas universais**.

## Mecânicas

- **Combo:** todo terceiro ataque é um golpe final mais forte.
- **Esquiva:** você fica invulnerável por um instante e atravessa projéteis.
- **Avisos no chão:** áreas vermelhas mostram onde o golpe do inimigo vai cair. O círculo de dentro enche até a hora do golpe.
- **Caído e reviver:** quem perde toda a vida cai. Um aliado precisa ficar perto por 3 segundos para levantar quem caiu. Sem ajuda em 15 segundos, a pessoa só volta quando a sala for limpa.
- **Ameaça:** os inimigos atacam quem causa mais dano. O Cavaleiro chama o dobro de atenção, então ele funciona como o tanque do grupo.
- **Elites:** inimigos com ★ e um poder (Blindado, Veloz, Gélido, Explosivo, Gigante). Dão 3x mais ouro.
- **Temas e chefes:** Calabouço (Rei Esqueleto), Caverna (Rainha Aranha), Cripta (Lich Gélido) e Fornalha (Senhor das Chamas). Os chefes têm uma segunda fase com metade da vida.

## Publicar no Roblox

1. **File > Publish to Roblox**.
2. Para o progresso salvar também no Studio: **Game Settings > Security > Enable Studio Access to API Services**.
3. Em **Game Settings > Avatar**, deixe **R15** (as animações das armas funcionam melhor).

## Onde mudar cada coisa

| Arquivo | Para quê |
|---|---|
| `src/shared/Config.luau` | Balanceamento geral, temas e inimigos de cada andar |
| `src/shared/Classes.luau` | Números das três classes |
| `src/shared/Cartas.luau` | Cartas e seus efeitos |
| `src/server/Inimigos.luau` | Vida, dano e ataques de inimigos e chefes |
| `src/server/Combate.luau` | Combos, habilidades, supremos, esquiva, dano |
| `src/server/Masmorra.luau` | Construção e decoração das salas |
| `src/server/Lobby.luau` | Acampamento, altares, portal, mercador |
| `src/client/Modelos.luau` | **Aparência dos inimigos** (peças, cores, armas) |
| `src/client/VisualInimigos.luau` | Animações dos inimigos |
| `src/client/Vfx.luau` | Efeitos visuais |
| `src/client/Hud.luau` e `Menus.luau` | Interface |
| `src/client/UI.luau` | Cores, fontes e estilo dos painéis e botões |

Depois de editar os arquivos em `src/`, rode `py build.py` para gerar o `.rbxlx` de novo e reabra no Studio. Se preferir, use o [Rojo](https://rojo.space/) (`rojo serve`) para sincronizar ao vivo.

## Sons

O jogo usa só sons que já vêm com o Roblox. Para deixar mais imersivo, pegue sons na Creator Store do Roblox (golpes, explosões, música ambiente) e coloque os IDs em `UI.SONS` (`src/client/UI.luau`).
