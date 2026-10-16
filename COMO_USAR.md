# Masmorra das Cartas

Roguelike cooperativo para Roblox, de 1 a 4 jogadores, inspirado em Ember Knights e Warcraft. Escolha entre **Cavaleiro**, **Mago**, **Arqueiro** e **Assassino** e desça por salas sorteadas. Use combos, esquiva e supremos, e monte sua build com cartas próprias da sua classe. A cada 5 salas vem um chefe, e depois dele você decide: **subir e guardar o ouro** ou **descer mais fundo**.

## Abrir e jogar

1. Instale o [Roblox Studio](https://create.roblox.com/).
2. Dê dois cliques em `MasmorraDasCartas.rbxlx` (ou, no Studio, use **File > Open from File**).
3. Clique em **Play** (F5).

Tudo é criado por código quando o jogo começa (terreno, salas, monstros, interface). Por isso, no modo de edição, o mundo aparece vazio.

**Testar em grupo no Studio:** aba **Test > Clients and Servers**, escolha 2 jogadores e clique em **Start**.

## Controles

| Ação | Computador | Celular | Controle |
|---|---|---|---|
| Atacar (combo de 3) | Clique esquerdo (mira no mouse) | Botão ⚔️ (mira sozinho) | R2 |
| Golpe carregado | Segurar e soltar o clique esquerdo | Segurar e soltar ⚔️ | Segurar e soltar R2 |
| Habilidade | E | Botão de cima | X |
| Esquiva | Q | Botão 💨 | B |
| Supremo | R (com a barra dourada cheia) | Botão do topo | Y |
| Defender com o escudo (Cavaleiro) | Segurar F ou o botão direito | Segurar 🛡️ | Segurar L2 |
| Correr (corrida leve, 35% mais rápido) | Segurar Shift esquerdo | — | Apertar o analógico esquerdo (L3) |
| Travar a mira (liga/desliga) | Alt esquerdo | — | Apertar o analógico direito (R3) |

A corrida não vale enquanto você ataca, carrega o golpe ou defende. Correndo, o personagem inclina, os braços balançam ao contrário das pernas e a câmera abre um pouco. O "Shift Lock" do Roblox fica desligado (o Shift é da corrida); no lugar dele, o **Alt trava a mira**: o mouse fica preso no centro da tela (aparece uma mira), a câmera vai para trás do ombro, o personagem olha sempre para onde a câmera aponta e os ataques saem nessa direção. Aperte Alt de novo para soltar. Abrir um menu solta o mouse sozinho.

Essas são as teclas padrão. Para trocar, use o botão **⚙️ TECLAS** no acampamento ou a engrenagem ao lado da barra de ações durante a partida. Cada ação aceita uma tecla principal e uma alternativa (tecla ou botão do mouse), e a escolha fica salva no seu perfil. W, A, S, D, Espaço, Esc e Tab ficam reservadas para o Roblox.

## As classes

| Classe | Estilo | Ponto forte | Ponto fraco | Habilidade (E) | Supremo (R) |
|---|---|---|---|---|---|
| 🛡️ Cavaleiro | Espada e escudo, tanque, atrai os inimigos | Muita vida e armadura, defende com o escudo | Lento, esquiva demora mais, só bate de perto | Redemoinho (tornado que puxa os inimigos; recebe 40% menos dano) | Julgamento (espada de luz do céu: atordoa e dá escudo aos aliados) |
| 🔮 Mago | Cajado e magias diferentes a cada golpe | Dano em área, fogo, gelo e arcano | Pouca vida, ataque lento, depende de mana | Meteoro (gasta mana; deixa o chão em chamas) | Tempestade Arcana (nuvem com raios que deixam lento) |
| 🏹 Arqueiro | Tira cada flecha da aljava e atira de longe | Maior alcance, muito ágil, flechas fortes | Flechas perdem força em inimigos colados | Chuva de Flechas (salta para trás antes) | Saraivada (vendaval em volta; corre 30% mais rápido) |
| 🗡️ Assassino | Duas adagas, sangramento, golpes pelas costas | O mais rápido, críticos, faz sangrar | Defesa baixa (leva 15% a mais de dano), pouca vida | Passo Sombrio (aparece atrás do alvo com crítico garantido) | Lâminas da Noite (intocável, salta entre até 10 inimigos) |

**Escudo (Cavaleiro):** andando, o escudo vai solto ao lado do corpo; segurando a defesa, ele vem para o centro do peito (com o ombro esquerdo à frente), dá um estouro de energia e fica brilhando enquanto a defesa está ativa. Golpes vindos da frente perdem 75% do dano. Erguendo o escudo logo antes do golpe (até 0,3s), é uma **defesa perfeita**: não leva dano nenhum, dá um empurrão com o escudo e atordoa quem atacou. Com o escudo erguido o Cavaleiro anda devagar e não ataca.

**Golpes do Cavaleiro:** no combo, o quadril e o tronco torcem junto com a espada. O 1º golpe corta da direita para a esquerda, o 2º é um revés da esquerda para a direita e o 3º é um **giro de 360°** que acerta tudo em volta. Segurando o ataque, ele ergue a espada e gira ela acima da cabeça, com um círculo mágico no chão e vento em volta (fica dourado com a carga cheia). Ao soltar, ele bate a espada no chão e lança um **tornado** que anda para a frente puxando e ferindo os inimigos. Com a carga cheia, o tornado explode no fim e atordoa. A habilidade (E) é uma **tempestade de cortes** em volta dele. O supremo (R) faz cair um **raio** com uma explosão dourada e, por **10 segundos**, o Cavaleiro fica **brilhando** (azul e dourado) e recebe **10% menos dano**. Com uma carta de fogo (Fúria do Dragão ou Redemoinho Flamejante), **a lâmina pega fogo** e os cortes, o tornado e a habilidade ficam **de fogo** e queimam. A esquiva dele é um **rolamento** para a frente (um pouco mais lento que o das outras classes, mas cobre a mesma distância e fica invulnerável durante o rolamento inteiro).

**Mago levitando:** o Mago flutua o tempo todo (parado, atacando e conjurando), com as pernas soltas e um anel de energia roxo no chão; andando, ele desliza no ar inclinado para onde vai. A esquiva é um portal (some e aparece). Explosões, meteoro e tempestade causam **15% a mais de dano em área** (`danoEmArea` em Classes.luau). Todas as magias usam efeitos dos pacotes de VFX (veja a tabela em `vfx/LEIA-ME.md`).

**Arqueiro (verde):** anda com passos leves e rápidos de caçador, o arco baixo na mão esquerda. Cada tiro tira a flecha da aljava, encaixa, puxa até o rosto e solta com um anel de vento verde no arco; as flechas voam com um rastro de vento verde e estouram em verde no inimigo. O 3º tiro e o tiro carregado saem com uma rajada forte; carregando, a energia junta na ponta da flecha e brilha quando a carga enche. A **Chuva de Flechas** (E) abre um portal verde no céu e as flechas caem e ficam cravadas no chão. A **Saraivada** (R) solta um estouro verde e um redemoinho de vento acompanha o Arqueiro enquanto ele atira para todos os lados. A esquiva solta riscos de velocidade e vento. Com a carta **Flechas de Fogo**, a flecha no arco vira brasa e os disparos, as flechas e os impactos ficam **de fogo**.

**Mana (Mago):** toda magia gasta mana, que volta sozinha com o tempo e enche ao entrar numa sala nova. O combo é Dardo Arcano → Lança de Gelo (deixa lento) → Bola de Fogo (explode e queima), e o golpe carregado é o Orbe do Vazio, que puxa os inimigos enquanto voa. Cartas como Fonte Arcana, Reservatório Arcano, Sifão de Almas e Mente Serena ajudam na mana.

**Sangramento (Assassino):** cada golpe abre um corte e o inimigo sangra por 4 segundos, acumulando até 5 vezes.

**Assassino (carmesim e preto):** corre baixo como um ninja, com as adagas para trás. Os golpes soltam cortes vermelhos no ar (sem rastro branco nas lâminas), o 3º golpe crava um X de cortes no chão, e cada acerto espirra sangue escuro; críticos e golpes pelas costas estouram mais forte. Carregando, a escuridão se junta em volta dele e um selo vermelho acende no chão quando enche; a **Investida Letal** deixa riscos escuros no caminho e termina numa explosão vermelha e preta. O **Passo Sombrio** (E) some e aparece numa fumaça escura. Nas **Lâminas da Noite** (R) os **olhos dele acendem em vermelho** enquanto ele salta de inimigo em inimigo.

**Golpe carregado** (segure o ataque e solte): Cavaleiro lança um tornado, Mago lança o Orbe do Vazio, Arqueiro dispara uma flecha perfurante e Assassino avança cortando tudo numa linha (Investida Letal).

**Pelas costas:** o Assassino causa +50% de dano acertando o inimigo por trás. Funciona muito bem junto com o Cavaleiro, que atrai a atenção.

O Cavaleiro, o Arqueiro e o Assassino têm um **andar próprio** (o Cavaleiro com passada firme, escudo do lado esquerdo e espada na mão direita; o Arqueiro com passos curtos e ágeis; o Assassino numa corrida baixa de ninja), que substitui a animação de andar do avatar do jogador; o Mago desliza no ar. Cada classe também tem uma **pose própria** parada: o Cavaleiro em guarda, o Mago ereto conjurando luz, o Arqueiro relaxado olhando em volta e o Assassino agachado e inclinado.

Cada classe tem pelo menos **11 cartas próprias** (o Mago tem 15, com as de mana), e existem **11 cartas universais**.

## Mecânicas

- **Combo:** todo terceiro ataque é um golpe final mais forte.
- **Esquiva:** você fica invulnerável por um instante e atravessa projéteis. Cada classe tem a sua: o Cavaleiro e o Arqueiro dão um rolamento encolhido (agacha, rola rente ao chão e levanta em guarda), o Mago dispara deitado no ar com o cajado à frente e o Assassino arranca agachado e freia derrapando.
- **Golpes sincronizados:** cada golpe tem preparação, impacto e volta. No instante do impacto o corpo para um tiquinho (dá peso ao golpe), e a volta para a guarda dura exatamente até o próximo ataque ficar liberado (a cadência).
- **Avisos no chão:** áreas vermelhas mostram onde o golpe do inimigo vai cair. O círculo de dentro enche até a hora do golpe.
- **Caído e reviver:** quem perde toda a vida cai. Um aliado precisa ficar perto por 3 segundos para levantar quem caiu. Sem ajuda em 15 segundos, a pessoa só volta quando a sala for limpa.
- **Ameaça:** os inimigos atacam quem causa mais dano. O Cavaleiro chama o dobro de atenção, então ele funciona como o tanque do grupo.
- **Elites:** inimigos com ★ e um poder (Blindado, Veloz, Gélido, Explosivo, Gigante). Dão 3x mais ouro.
- **Cadência dos ataques:** depois de cada golpe é preciso esperar ele terminar para atacar de novo (clicar sem parar não adianta). Um clique feito pouco antes da hora fica guardado e sai no momento certo. A **barrinha embaixo do seu personagem** (e a sombra no quadradinho do Ataque) mostra quando o próximo ataque fica pronto; ela pisca quando libera. Mago e Arqueiro são os mais lentos. Os tempos ficam em `cadencia` dentro de `ataque` em Classes.luau.
- **Peso dos golpes:** os personagens se preparam antes de cada ataque (erguem a espada, puxam a flecha, juntam a magia) e andam mais devagar enquanto atacam. O golpe só acerta no fim da preparação. Para deixar tudo mais rápido ou mais lento, mude `Config.PREPARO_GOLPE` (1 = sem atraso extra; padrão 1,7). A velocidade ao atacar é `Config.VELOCIDADE_ATACANDO`. O ajuste de cada classe fica em `preparo` dentro de `ataque` em Classes.luau.
- **Salas maiores:** as salas de combate são bem mais largas (105 a 140 studs), com mais pilares, poças de lava e enfeites. A sala do chefe tem 150x150. As ondas têm mais inimigos e mais inimigos vivos ao mesmo tempo.
- **Salas com câmaras (roguelike frenético):** as salas de combate têm cerca de 175x240 studs e são divididas em **três câmaras seguidas**, ligadas por portões. Cada fileira é sorteada:
  - inteira (a largura toda);
  - estreita (rocha maciça dos lados);
  - com uma **câmara de desafio** ao lado.
  - **Câmaras trancadas:** ao entrar numa câmara, os portões descem (runas vermelhas) e quem ficou do lado de fora é puxado para dentro. Vêm 2 ou 3 **ondas**, e a próxima chega quando sobram 2 inimigos. Limpou, os portões sobem (runas verdes).
  - **Câmara de desafio** (opcional): uma onda com elites e ouro extra para todos no fim.
  - A porta da sala abre quando as três câmaras do caminho estão limpas. Os inimigos ficam presos na câmara trancada, e flechas e magias batem nas paredes internas.
  - Tochas e braseiros usam o fogo do pacote de VFX (`LaminaFogo`).
  - Os números ficam em `Config.CAMARAS`. Para voltar à sala única, tire `camaras = true` do tema em `Config.TEMAS`.
- **Inimigos de apoio** (a partir da 2ª sala de cada andar). Vale matar esses primeiro:
  - **Acólito** (manto verde): fica atrás do grupo e **cura** os aliados com um feixe verde.
  - **Guardião** (armadura de pedra e escudo de runas): dá **escudos azuis** aos aliados. O escudo absorve o dano antes da vida e aparece como uma bolha e uma barra azul.
  - **Porta-Estandarte** (estandarte e corneta): dá um **grito de guerra**. Os aliados ficam com uma aura vermelha e andam e atacam mais rápido por alguns segundos.
  - Eles aparecem **o dobro** do normal (cerca de 1 em cada 3 inimigos). Ajuste em `Config.PESO_INIMIGOS_DE_APOIO` (1 = normal).
- **Dificuldade do grupo:** cada jogador a mais na partida deixa a masmorra mais difícil. Com 2, 3 ou 4 jogadores:

  | Jogadores | Vida dos inimigos | Dano dos inimigos | Vida dos chefes | Dano dos chefes | Golpes do chefe | Postura do chefe | Inimigos por sala |
  |---|---|---|---|---|---|---|---|
  | 2 | +75% | +20% | +130% | +30% | 10% mais frequentes | +60% | +4 |
  | 3 | +150% | +40% | +260% | +60% | 20% mais frequentes | +120% | +8 |
  | 4 | +225% | +60% | +390% | +90% | 30% mais frequentes | +180% | +12 |

  A chance de elite também sobe 4% por jogador. Quando o tamanho do grupo muda, aparece um aviso na tela. Os valores ficam no `Config.luau` (procure por `POR_JOGADOR_EXTRA`).
- **Temas e chefes:** Calabouço (Skullbane), Caverna (Rainha Aranha), Cripta (Lich Gélido) e Fornalha (Senhor das Chamas). O Rei Esqueleto continua no jogo: para voltar a ele, troque `chefe = "skullbane"` por `chefe = "reiEsqueleto"` no Calabouço, em `src/shared/Config.luau`.
- **Skullbane, o Senhor da Guerra Caído** (1º chefe, modelo 3D próprio, inspirado nos chefes de Elden Ring). Todos os efeitos dele vêm do pacote de VFX (pasta `vfx/`); os que eram de outra cor são tingidos de verde pelo jogo.
  - **O braço mexe de verdade:** o braço com a lâmina gira pelo ombro e pelo cotovelo (o jogo deforma a malha do modelo com EditableMesh). Para isso, ligue **Game Settings > Security > Allow Mesh / Image APIs** (a mesma opção das texturas). Sem ela, o braço fica parado e ele luta só com o corpo, e aparece um aviso no Output.
  - **Maldição do Alto** (só nesta luta): a cada **5 segundos** uma alma cai do alto em um jogador sorteado do grupo. Um selo verde **segue a pessoa** e só **trava no lugar 0,35s antes** da alma cair (o selo pisca): sair andando não adianta. Escapa quem **dá a esquiva bem na hora** (fica intocável ou sai do selo travado) ou quem **defende com o escudo**. Quem é atingido leva dano e fica **1,2 segundo sem dash, corrida, habilidade (E) e supremo (R)**. A cada **10 segundos** a queda é a **maldição forte**: círculo maior, alma maior, mais dano e **2,5 segundos** amaldiçoado. A tela de quem foi amaldiçoado fica verde, aparece o aviso "☠ AMALDIÇOADO" e todos veem uma névoa verde no corpo dele e um selo acima da cabeça. Ajustes em `Config.MALDICAO_INTERVALO`, `MALDICAO_DURACAO`, `MALDICAO_FORTE_A_CADA`, `MALDICAO_FORTE_DURACAO`, `MALDICAO_AVISO` e os raios.
  - **Caveiras:** a cada **7 segundos** ele solta **caveiras em chamas verdes** (uma por jogador, no mínimo 2) que **perseguem** quem elas miram. Viram devagar: dá para fugir ou desviar de lado na hora certa, ou atravessar com a esquiva. Ajustes em `Config.CAVEIRAS_*`.
  - **Resistente:** 2600 de vida e 25% de armadura. A postura aguenta muito mais e se recupera rápido; o grogue dura 2s e o golpe fatal dá dano dobrado (não triplo). A lâmina presa no chão acontece menos e dura menos.
  - **Só esqueletos:** nesta luta só nascem os **Ceifadores Esmeralda** (as caveiras do modelo 3D); o Guardião da 2ª fase saiu.
  - **Mais agressivo:** o Skullbane chega perto o bastante para todos os golpes, anda mais rápido e rodeia você entre um golpe e outro; os Ceifadores também, andando sempre de frente para o alvo.
  - **Despertar:** a tumba racha e ele sobe curvado. Os olhos acendem (close da câmera), as chamas acendem uma a uma e ele ruge com a lâmina erguida. Fica imune até acabar (cerca de 3,6s) e logo depois já ataca. Todos os chefes começam a usar os golpes mais cedo: `Config.INICIO_ATAQUES_CHEFE` (1 = como antes; padrão 0,35).
  - **Aura:** discreta na 1ª fase (energia verde fraca em volta, anel no chão, névoa e chamas). Na 2ª fase fica evidente e **torcida**: um tornado verde gira em volta dele.
  - **Moveset sem padrão:** ele sorteia os golpes (quase nunca repete o mesmo) e às vezes **encadeia combos** de surpresa. Alguns golpes ele segura por um tempo diferente a cada vez, para você errar o tempo da esquiva.
  - **Ficar perto é perigoso:** quem fica colado nele leva Varridas, Giro e a **Explosão de Almas** (ele crava a lâmina e as almas explodem em volta).
  - **Ir para longe também:** ele usa o **Puxão das Almas** (aponta a lâmina, um redemoinho verde se forma e puxa todo mundo para perto dele, já emendando um golpe). Andar para trás resiste um pouco; a **esquiva escapa** do puxão. De longe ele também lança **Lâminas de Alma**, a Fissura, a investida e o salto.
  - **Golpes de espada:**
    - **Corte Descendente:** ergue a lâmina acima da cabeça e desce. Às vezes ela fica presa no chão e ele fica **VULNERÁVEL** (+35% de dano).
    - **Varrida:** varre na altura da cintura e pode voltar pelo outro lado.
    - **Estocada:** recua a lâmina e fura em linha, longe.
    - **Giro:** três voltas com a lâmina esticada.
  - **Salto Esmagador:** cai com a lâmina e **quebra o chão**: pedaços voam, o ar distorce, a câmera afunda e mais **dois anéis de tremor** se espalham do ponto da queda.
  - **Postura e parry (como em Lies of P):** embaixo da vida dele há uma barra de **Postura** que cresce do meio para os lados. Ela enche com **parry** (defesa perfeita do Cavaleiro: uns 3 derrubam), com **esquiva perfeita** (esquivar logo antes do golpe acertar, aparece "ESQUIVA PERFEITA!") e um pouco com cada golpe. Ela esvazia sozinha se você parar de pressionar. Cheia, ele fica **GROGUE**: cai de joelhos com a espada fincada, brilhando em branco, por 4s, levando +40% de dano. O primeiro golpe nesse tempo é um **GOLPE FATAL** (dano triplo) e ele se levanta logo depois.
  - **Ceifadores Esmeralda:** ele ergue a lâmina e chama: a tela treme cada vez mais, a terra racha e dois esqueletos com espada saem do chão (três na 2ª fase, num "exército"). Eles também mexem o braço da espada (corte de cima, varrida e investida).
  - **Avisos:** a área vermelha some na hora se o golpe dele for cancelado (parry, grogue ou morte). O aviso **verde** é o do Puxão: não dá dano, só puxa.
  - **2ª fase:** mais combos, fissuras em leque, anéis verdes, espiral e chuva de almas, um puxão mais forte e um Guardião Rúnico.
  - **Morte:** cai de joelhos com almas estourando pelo corpo e um raio verde desce do céu sobre ele.
- **Segunda fase dos chefes:** com metade da vida, o chefe para e se **transforma** (cerca de 3 segundos, sem levar dano). A sala muda de cor, sobem pilares de luz e a energia é sugada para ele. No fim, ele solta uma onda que empurra todo mundo para longe: saia de perto! Na 2ª fase, ele fica mais rápido e ganha ataques novos:
  - **Espiral:** ondas de projéteis girando em todas as direções.
  - **Anéis de perigo:** anéis no chão que explodem. Fique dentro ou fora da faixa marcada.
  - Ele também chama inimigos de apoio para ajudar.

## Chefes com modelo 3D (feito por IA, Blender etc.)

O Skullbane veio de um arquivo `.glb`. Para colocar outro modelo do mesmo jeito:

1. Exporte em **.glb**. Use a origem no fundo (pés no chão) e, se der, menos de 20 mil triângulos.
2. No Studio, use **File > Import 3D** e depois **Save to File...** no modelo importado. Salve o `.rbxmx` na pasta `chefes/` do projeto, com o nome do chefe.
3. Ele vai para **ReplicatedStorage > ModelosChefes**. Em `src/client/Modelos.luau`, use `malhas = { { nome = "NomeDoArquivo", osso = "corpo", altura = 17, giro = 180 } }` (veja `Modelos.skullbane`). Se ele aparecer de costas, troque `giro` para 0.

O `.glb` original fica guardado em `chefes/` (o jogo não usa esse arquivo, ele serve só de backup).

## Efeitos visuais

Os efeitos usam partículas com texturas: as que já vêm com o Roblox (fogo, fumaça, explosão, onda de choque, implosão, vórtice) e **texturas desenhadas pelo próprio jogo** quando ele abre (lua de corte, estrela de crítico, onda de choque, círculo mágico com runas, raio, chama, fumaça, faísca em rastro). Para as texturas próprias funcionarem no jogo publicado, ligue **Game Settings > Security > Allow Mesh / Image APIs**. Sem isso, o jogo usa só as texturas do Roblox (nada quebra; aparece um aviso no Output).

**Usar efeitos feitos no VFX Studio (ou da Creator Store):** crie a pasta `EfeitosCustom` dentro de **ReplicatedStorage** e coloque o efeito lá com um destes nomes: `Impacto`, `Critico`, `Corte`, `Explosao`, `Vazio`, `Esquiva`, `Defesa`, `CargaCheia`, `Morte`, `Sangue`, `Redemoinho`, `Julgamento`, `Meteoro`, `Raio`, `PassoSombrio`, `Supremo`. O efeito pode ser um Attachment, uma Part, um Model ou uma pasta com ParticleEmitters. Quando aquele momento acontece no jogo, o efeito é colocado no lugar e cada ParticleEmitter solta a quantidade do atributo **EmitCount** (padrão 20; o atributo **EmitDelay** atrasa); Beams e Trails ficam ligados pelo atributo **Duracao** (padrão 0,5s). Sem efeito com aquele nome, o jogo usa o efeito padrão.

**Animações dos personagens:** são feitas por código (não precisam de arquivos de animação). O arquivo do jogo já vem com **StarterPlayer > AvatarJointUpgrade = Disabled**; se você mudar isso, as animações continuam funcionando (o código aceita os dois tipos de junta). Se alguma vez o boneco não se mexer, veja a janela Output: o jogo avisa quando não encontra as juntas do personagem.

## Efeitos sonoros

O jogo tem 38 efeitos sonoros (cortes, flechas, magias, escudo, impactos, explosões, moedas, interface...). Eles foram **criados do zero por síntese** pelo script `ferramentas/gerar_sons.py` e ficam todos juntos em um arquivo só: `sons/MasmorraSons.ogg`. O Roblox não deixa colocar áudio dentro do arquivo `.rbxlx`, então é preciso enviar esse arquivo **uma vez**:

1. No Roblox Studio, abra **Window > Asset Manager** (ou **View > Asset Manager**) e clique em **Bulk Import**. Também dá pelo site: **create.roblox.com > Creations > Audio > Upload Asset**.
2. Escolha `sons/MasmorraSons.ogg` e confirme. Espere a moderação aprovar (costuma levar poucos minutos).
3. Copie o ID do áudio (no Asset Manager: botão direito > **Copy Asset ID**).
4. Em `src/shared/Config.luau`, cole o ID: `Config.SONS_ID = "rbxassetid://SEU_ID_AQUI"`.
5. Rode `py build.py` de novo e abra o `MasmorraDasCartas.rbxlx` (ou faça a mesma troca direto no Studio, em **ReplicatedStorage > Shared > Config**).

Envie o áudio pela **mesma conta (ou grupo) dona do jogo**; áudio de outra conta não toca. Enquanto o ID não for colocado, só as explosões têm som (um som que já vem com o Roblox) e aparece um aviso na janela Output.

Se preferir enviar os sons um por um, eles também estão separados em `sons/individuais/`; coloque cada ID em `Config.SONS_IDS` (por exemplo `espada = "rbxassetid://..."`). Para mudar um som, edite `ferramentas/gerar_sons.py` e rode `py ferramentas/gerar_sons.py` (precisa de `pip install numpy scipy` e do ffmpeg); depois envie o arquivo novo.

## Segurança: pacotes do Toolbox

Pacotes grátis de efeitos e armas às vezes trazem **scripts escondidos** (dentro de partículas, de bonecos de exibição...). Já apareceram dois tipos neste projeto:
- **Backdoor:** baixa código de outra pessoa com `require(número)` e dá a ela controle do jogo.
- **Golpe no Studio:** só roda no Studio, mostra uma janela falsa pedindo para você copiar um código e colar na Command Bar.

**Nunca cole na Command Bar um código que uma janela "pediu".** Efeitos não precisam de script: antes de usar um pacote, procure Script/LocalScript dentro dele e apague. O `build.py` remove scripts de tudo que está em `vfx/` e `modelos/`.

## Efeitos do plugin (VFX Studio ou outro)

Dá para trocar ou reforçar os efeitos do Cavaleiro por efeitos montados no Studio com um plugin como o **VFX Studio**. Eles usam texturas que já estão no Roblox, então não precisa enviar nada. O jogo toca cada efeito sozinho, pelo nome:

| Nome | Quando toca |
|---|---|
| `CorteCavaleiro` | golpes 1 e 2 do combo (na altura do peito, virado para o golpe) |
| `CorteGiratorio` | golpe 3, o giro de 360° |
| `Tornado` | o tornado do ataque carregado (no chão, acompanha o tornado) |
| `CargaCavaleiro` | enquanto segura o ataque (no chão, embaixo do Cavaleiro) |
| `EscudoErguido` | enquanto defende (na frente do escudo, acompanha o braço) |
| `DefesaPerfeita` | defesa perfeita (no escudo, virado para quem atacou) |
| `Julgamento` | supremo do Cavaleiro (no chão, no ponto do impacto) |
| `ImpactoCorte` | a espada do Cavaleiro acerta um inimigo |
| `Rolamento` | começo do rolamento (dash) do Cavaleiro |
| `Redemoinho` | habilidade (E) do Cavaleiro, enquanto ele gira |

1. No Studio, monte o efeito com o plugin (uma **Part**, um **Model** ou um **Attachment** com ParticleEmitters, Beams e Trails dentro) e dê a ele um dos nomes da tabela.
2. Para testar na hora: crie a pasta **ReplicatedStorage > EfeitosVFX** e coloque o efeito dentro. Dê Play.
3. Para guardar no projeto: botão direito no efeito > **Save to File...** e salve como `.rbxmx` na pasta `vfx/` do projeto. O `py build.py` (ou o Rojo) coloca tudo em EfeitosVFX.

Atributos opcionais (em **Properties > Attributes**):
- No efeito: `Duracao` (segundos) e `Substituir` (marcado = esconde o efeito feito por código e mostra só o seu).
- Em cada ParticleEmitter: `EmitCount` (solta essa quantidade de uma vez) e `EmitDelay` (espera antes de soltar). Sem `EmitCount`, o emissor fica ligado enquanto o efeito durar.

Sem efeitos na pasta, o jogo usa os efeitos feitos por código normalmente.

## Conferir as animações sem abrir o Studio

`ferramentas/ver_poses.py` desenha o personagem (R15, com espada e escudo) em várias vistas e o caminho da ponta da espada, usando as poses reais de `Poses.luau`. Precisa de `pip install numpy pillow` e do `luau.exe` (github.com/luau-lang/luau/releases):

```
py ferramentas/ver_poses.py --luau CAMINHO/luau.exe --acao ataque3 --tempos 0.09,0.2,0.3,0.42 --saida giro.png
```

## Editar o mapa no Studio (lobby)

O lobby está com **materiais realistas** (grama, terra, pedra, madeira, tecido e metal, com cores mais naturais). Isso foi feito por `py ferramentas/lobby_realista.py`, que troca só o material e a cor de cada peça e mantém as posições e as suas edições. Antes de mudar, ele guarda uma cópia em `.backups/`.

O cenário do lobby fica salvo dentro do jogo: abra o `MasmorraDasCartas.rbxlx` e ele aparece em **Workspace > Mapa > Lobby**, separado em pastas (Chao, Praca, Portal, Santuarios, Loja, Placa, Lago, Decoracao, Natureza, Limites).

- **Mexa à vontade**: mova, apague, copie árvores, mude cores. Tudo em peças lisas e coloridas (estilo fantasia, sem textura realista).
- **Mais árvores, pedras e cogumelos**: o pacote de natureza fica em **ServerStorage > PacoteCenario**. Copie o que quiser e cole no Workspace: aparece no meio da praça, é só arrastar para o lugar. Deixe dentro de `Mapa > Lobby` para ser guardado.
- **Marcadores (rosa)**: a pasta `Marcadores` mostra onde o jogo monta o que é vivo: o círculo e o redemoinho do portal, cada altar, o balcão da loja, o nascimento e os vagalumes. Mover um marcador muda onde aquilo aparece. No jogo eles ficam invisíveis.
- **Santuários das classes**: um por classe, em meia-lua à esquerda da praça, cada um virado para o centro. A arma que gira, o prompt e o nome da classe aparecem em cima do marcador `Altar_<classe>` (no pedestal). Se mover um santuário, leve o marcador junto.
- **Lago com água de verdade**: a peça azul meio transparente `Lago > Agua` só mostra no Studio onde a água fica. Ao dar Play, o jogo enche esse volume com água do Terrain (ondas, reflexo, dá para nadar) e some com a peça. Se mudar o lago, ajuste a `Agua` junto com a margem.
- **Portal**: o redemoinho roxo do arco é efeito do pacote (`PortalChuva`), ligado pelo código no marcador `Vortice` (só aparece ao dar Play). O círculo onde o grupo se junta (marcador `Portal`) é só a pedra e as runas do mapa, sem brilho.
- **Música do lobby**: o som "Ambient Trust" toca em loop no acampamento e some na masmorra. Troque ou desligue em `Config.MUSICA_LOBBY` (volume em `Config.VOLUME_MUSICA_LOBBY`).
- **Céu**: o Sky que estiver em Lighting também é guardado.
- **Para guardar**: salve no mesmo arquivo (**Arquivo > Salvar no arquivo**) e me avise. Quando o `build.py` roda, ele percebe que o arquivo foi salvo pelo Studio, faz uma cópia em `.backups/` e puxa o seu mapa (para `mapas/`) e o seu céu (para `ceu/`) antes de gerar o jogo de novo. O que você puser **fora** de `Workspace > Mapa` é avisado e fica só na cópia.
- `ferramentas/gerar_lobby.py` gera o lobby do zero (apaga as edições feitas à mão); `mapas/lobby_visto_de_cima.png` mostra o lobby visto de cima.

## Publicar no Roblox

O jogo que as pessoas jogam (fora do Studio) é a **última versão publicada**. Testar no Studio ou usar "Salvar no Roblox" não muda o jogo publicado.

**Conferir a versão:** no canto de baixo à direita da tela aparece algo como `v0.13 · 16/10/2026 00:55`: o número de `Config.VERSAO` mais a data e a hora em que o `build.py` gerou o arquivo. Se o jogo publicado mostrar a mesma data e hora do Studio, ele está atualizado. Suba `Config.VERSAO` quando publicar uma atualização grande.

1. **File > Publish to Roblox** (Alt+P). Depois, em create.roblox.com, abra o jogo e use **Desligar todos os servidores**: os servidores abertos continuam com a versão antiga.
2. Para o progresso salvar também no Studio: **Game Settings > Security > Enable Studio Access to API Services**.
3. O arquivo do jogo já vem com **R15** e com as juntas clássicas (StarterPlayer > AvatarJointUpgrade = Disabled). Se mudar em **Game Settings > Avatar**, mantenha **R15**: os golpes usam cotovelo, pulso e cintura, que o R6 não tem.

**As animações não aparecem?** Dê Play e abra a janela **Output** (View > Output). Deve aparecer a linha `[Animacoes] Personagem R15 com 15 juntas (...): animações ligadas.` Se aparecer outro aviso `[Animacoes]` (sem juntas, R6 ou um erro), copie essa linha: ela diz exatamente o que está errado.

## Onde mudar cada coisa

| Arquivo | Para quê |
|---|---|
| `src/shared/Config.luau` | Balanceamento geral, temas e inimigos de cada andar |
| `src/shared/Classes.luau` | Números das quatro classes |
| `src/shared/Cartas.luau` | Cartas e seus efeitos |
| `src/server/Inimigos.luau` | Vida, dano e ataques de inimigos e chefes |
| `src/server/Combate.luau` | Combos, habilidades, supremos, esquiva, escudo, mana, sangramento, dano |
| `src/shared/Teclas.luau` | Ações e teclas padrão (menu ⚙️ Teclas) |
| `src/client/Sons.luau` | Volume e variação de cada efeito sonoro |
| `ferramentas/gerar_sons.py` | Como cada som é criado (síntese) |
| `src/client/Poses.luau` | Poses e golpes de cada classe (quadros-chave das animações) |
| `src/client/Vfx.luau` | Efeitos visuais (cortes, tornado, círculo mágico, barreira do escudo...) |
| `vfx/` | Efeitos prontos do plugin (`.rbxmx`), veja "Efeitos do plugin" |
| `chefes/EmeraldBoneReaver.rbxmx` | Modelo 3D do Ceifador Esmeralda (lacaio do Skullbane) |
| `chefes/Skullbane.rbxmx` | Modelo 3D do Skullbane (vai para ReplicatedStorage > ModelosChefes); `Skullbane.glb` é o original |
| `modelos/EspadaCavaleiro.rbxmx` | Espada do Cavaleiro (vai para ServerStorage > ModelosArmas; o cabo fica no -Z) |
| `pacotes/` | Pacotes baixados guardados sem scripts (insira no Studio com Insert from File) |
| `src/server/Masmorra.luau` | Construção e decoração das salas |
| `src/server/Lobby.luau` | Acampamento, altares, portal, mercador |
| `src/client/Modelos.luau` | **Aparência dos inimigos** (peças, cores, armas) |
| `src/client/VisualInimigos.luau` | Animações dos inimigos |
| `src/client/Vfx.luau` | Efeitos visuais (cada golpe, magia e habilidade) |
| `src/client/VfxKit.luau` | Receitas de partículas e efeitos próprios (EfeitosCustom) |
| `src/client/TexturasGeradas.luau` | Desenho das texturas de efeito |
| `src/client/Hud.luau` e `Menus.luau` | Interface |
| `src/client/UI.luau` | Cores, fontes e estilo dos painéis e botões |

Depois de editar os arquivos em `src/`, rode `py build.py` para gerar o `.rbxlx` de novo e reabra no Studio. Se preferir, use o [Rojo](https://rojo.space/) (`rojo serve`) para sincronizar ao vivo.
