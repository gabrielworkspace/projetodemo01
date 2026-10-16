# Efeitos prontos (plugin VFX Studio ou outro)

Os arquivos `.rbxmx` desta pasta vão para **ReplicatedStorage > EfeitosVFX** quando você roda
`py build.py` (ou usa o Rojo). O jogo toca cada efeito sozinho, na hora certa, pelo nome:

| Nome do efeito       | Quando toca                                                     |
|----------------------|-----------------------------------------------------------------|
| `CorteCavaleiro`     | golpes 1 e 2 do combo (`CorteCavaleiroFogo` com poder de fogo)  |
| `CorteGiratorio`     | golpe 3, giro de 360° (`CorteGiratorioFogo` com poder de fogo)  |
| `ImpactoCorte`       | a espada acerta um inimigo (`ImpactoCorteFogo` com fogo)        |
| `CargaCavaleiro`     | enquanto segura o ataque: anel de energia na altura da espada   |
| `CargaAura`          | enquanto segura o ataque: energia azul subindo em volta do corpo |
| `CargaCheia`         | estouro dourado quando a carga enche (com o som do pacote)      |
| `CargaBrilhoCheia`   | brilho dourado na espada enquanto a carga está cheia            |
| `LancamentoTornado`  | a espada bate no chão e lança o tornado (ataque carregado)      |
| `Tornado`            | o tornado do ataque carregado, andando (`TornadoChamas` com fogo) |
| `TornadoFogo`        | chamas extras que acompanham o tornado, com poder de fogo       |
| `LaminaFogo`         | chamas na lâmina da espada enquanto tiver uma carta de fogo     |
| `Redemoinho`         | habilidade E: tempestade de cortes (`RedemoinhoFogo` com fogo)  |
| `EscudoErguido`      | brilho contínuo enquanto segura o escudo                        |
| `EscudoAtivado`      | estouro quando o escudo chega na frente                         |
| `BloqueioEscudo`     | cada golpe bloqueado pelo escudo                                |
| `DefesaPerfeita`     | defesa perfeita                                                 |
| `Rolamento`          | começo do rolamento (dash)                                      |
| `Julgamento`         | supremo: impacto dourado no chão                                |
| `JulgamentoRaio`     | supremo: raio azul caindo do céu                                |

**Mago** (roxo arcano, azul-gelo e fogo):

| Nome do efeito       | Quando toca                                                     |
|----------------------|-----------------------------------------------------------------|
| `ProjetilArcano`     | segue o Dardo Arcano (golpe 1)                                  |
| `ProjetilGelo`       | segue a Lança de Gelo (golpe 2)                                 |
| `ProjetilFogo`       | segue a Bola de Fogo (golpe 3)                                  |
| `ProjetilVazio`      | segue o Orbe do Vazio (ataque carregado)                        |
| `ExplosaoArcana`     | explosão do Dardo Arcano                                        |
| `ExplosaoFogo`       | explosão da Bola de Fogo                                        |
| `ExplosaoVazio`      | explosão do Orbe do Vazio                                       |
| `MeteoroImpacto`     | meteoro chegando no chão (habilidade E)                         |
| `MeteoroExplosao`    | estouro no ar junto com o impacto do meteoro                    |
| `RaioTempestade`     | cada raio da Tempestade Arcana (supremo)                        |
| `PortalMago`         | esquiva: portal onde ele some e onde aparece                    |
| `LevitacaoMago`      | anel de energia no chão, debaixo do Mago levitando              |
| `BarreiraArcana`     | bolha roxa em volta do Mago enquanto a Barreira Arcana está ativa |
| `BarreiraArcanaQuebra` | a barreira estoura ao bloquear um golpe                       |

**Arqueiro** (verde; com a carta Flechas de Fogo, as versões `...Fogo` laranja):

| Nome do efeito       | Quando toca                                                     |
|----------------------|-----------------------------------------------------------------|
| `FlechaVento` / `FlechaFogo` | rastro que segue cada flecha (a flecha de madeira continua) |
| `FlechaCarregada` (+`Fogo`) | segue a flecha do ataque carregado e a do Tiro Fantasma  |
| `DisparoArco` (+`Fogo`) | anel de vento no arco quando a corda solta (golpes 1 e 2)    |
| `DisparoForte` (+`Fogo`) | rajada para a frente: golpe 3, tiro carregado e Chuva       |
| `ImpactoFlecha` (+`Fogo`) | flecha acertando um inimigo (e algumas flechas da Chuva)   |
| `CargaArqueiro` (+`Fogo`) | energia na ponta da flecha enquanto puxa a corda           |
| `CargaCheiaArqueiro` | brilho de estrelas quando a carga enche                         |
| `PortalChuva`        | portal no céu durante a Chuva de Flechas (habilidade E)         |
| `SaltoArqueiro`      | lufada de vento no salto para trás da Chuva                     |
| `PassoArqueiro`      | esquiva: riscos de velocidade e vento                           |
| `SaraivadaInicio`    | supremo: estouro verde em volta                                 |
| `VendavalArqueiro`   | supremo: redemoinho de vento em volta por 4s                    |

**Assassino** (carmesim e preto):

| Nome do efeito       | Quando toca                                                     |
|----------------------|-----------------------------------------------------------------|
| `CorteAdaga`         | golpes 1 e 2: cortes no ar onde a adaga passa (e na Investida)  |
| `CorteFinalAdaga`    | golpe 3: X de cortes e faíscas no chão                          |
| `ImpactoAdaga`       | cada golpe acertado (sangue escuro e corte vermelho)            |
| `ImpactoCostas`      | golpe crítico (pelas costas, Passo Sombrio, supremo)            |
| `SangueGota`         | cada tique do sangramento                                       |
| `FumacaSombria`      | Passo Sombrio (E): fumaça onde some e onde aparece              |
| `RastroSombra`       | esquiva e Investida: riscos escuros e linhas vermelhas          |
| `CargaAssassino`     | escuridão juntando em volta enquanto carrega                    |
| `CargaCheiaAssassino`| selo vermelho no chão quando a carga enche                      |
| `InvestidaFim`       | explosão no fim da Investida Letal e no começo do supremo       |
| `OlhosVermelhos`     | supremo: olhos vermelhos brilhando                              |

**Cartas** (o que cada carta faz em combate aparece com efeito do pacote):

| Nome do efeito       | Carta / quando toca                                             |
|----------------------|-----------------------------------------------------------------|
| `OndaCorte` (+`Fogo`) | Onda de Corte: a meia-lua que voa                              |
| `RastroChoque` (+`Fogo`) | Onda de Corte e Investida Brutal: rastro de choque no chão  |
| `RajadaDragao`       | Fúria do Dragão: sopro de fogo à frente em cada golpe           |
| `EscudoAbencoado`    | Escudo Abençoado e escudo do supremo do Cavaleiro: bolha dourada |
| `EscudoAbencoadoQuebra` | a bolha dourada estoura ao bloquear                          |
| `AuraProtetor`       | Aura do Protetor: círculo dourado no chão (área protegida)      |
| `RaioCorrente`       | Corrente Elétrica: raio roxo em quem leva o choque              |
| `Espinhos`           | Espinhos: cortes verdes em quem bateu                           |
| `AdagaRastro`        | Leque de Adagas: riscos atrás de cada adaga                     |
| `SegundaChance`      | Segunda Chance (e ao ganhar um escudo): luz sagrada             |
| `CuraJogador`        | qualquer cura que aparece (+vida)                               |
| `LentoGelo`          | inimigo lento (Toque Gélido, Chuva de Flechas...)               |
| `SangrandoInimigo`   | inimigo sangrando (Assassino)                                   |
| `Atordoado`          | inimigo tonto: estrelas acima da cabeça                         |

**Skullbane (1º chefe) e fogo dos inimigos:**

| Nome do efeito       | Quando toca                                                     |
|----------------------|-----------------------------------------------------------------|
| `MaldicaoMarca`      | selo verde da Maldição do Alto (segue a pessoa e pisca ao travar) e selo acima da cabeça de quem está amaldiçoado |
| `MaldicaoNevoa`      | névoa verde no corpo de quem está amaldiçoado                   |
| `CaveiraAlma`        | caveiras que perseguem: orbe de alma, olhos em chamas e chamas verdes |
| `BolaDeFogo`         | bolas de fogo dos inimigos e meteoro do chefe de fogo           |
| `ExplosaoChamas`     | explosões de fogo (e as outras explosões, tingidas na cor do ataque) |
| `ChaoArcano`         | chão em chamas roxas do Meteoro do Mago                         |

A Combustão usa `ExplosaoFogo`, o Ricochete usa `ImpactoFlecha` e o inimigo queimando usa `LaminaFogo`.

Os efeitos que estão aqui hoje vieram dos pacotes de VFX que você salvou no jogo, com as cores
puxadas para a cor de cada classe: **azul e dourado** no Cavaleiro, **roxo** no Mago, **verde** no
Arqueiro e **carmesim e preto** no Assassino (e fogo com as cartas de fogo). Os pacotes inteiros estão guardados, **sem scripts**, em
`pacotes/`. Se um efeito vier com script escondido, o `build.py` remove e avisa. Sons que vêm
dentro de um efeito tocam junto com ele.

Passo a passo completo em **COMO_USAR.md**, seção "Efeitos do plugin".
