-- Kit de partículas com texturas que já vêm no Roblox (faíscas, fogo, fumaça, ondas de choque,
-- brilho, implosão...). Cada "receita" é um emissor pronto; os efeitos em Vfx.luau combinam
-- várias receitas num ponto (clarão + faíscas + fumaça + onda no chão...).
--
-- Efeitos próprios (VFX Studio, Creator Store...): crie a pasta ReplicatedStorage > EfeitosCustom
-- e coloque um modelo/peça/anexo com o NOME do efeito (veja VfxKit.NOMES). Ele é usado no lugar
-- do efeito padrão: os ParticleEmitter dentro dele soltam EmitCount partículas (atributo; padrão
-- 20) e Beams/Trails ficam ligados por "Duracao" segundos (atributo; padrão 0.5).

local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local TexturasGeradas = require(script.Parent.TexturasGeradas)

local VfxKit = {}

local terreno = workspace.Terrain

VfxKit.TEX = {
	faisca = "rbxasset://textures/particles/sparkles_main.dds",
	centelha = "rbxasset://textures/particles/fire_sparks_main.dds",
	fogo = "rbxasset://textures/particles/fire_main.dds",
	fumaca = "rbxasset://textures/particles/smoke_main.dds",
	fumacaExplosao = "rbxasset://textures/particles/explosion01_smoke_main.dds",
	nucleo = "rbxasset://textures/particles/explosion01_core_main.dds",
	onda = "rbxasset://textures/particles/explosion01_shockwave_main.dds",
	implosao = "rbxasset://textures/particles/explosion01_implosion_main.dds",
	brilho = "rbxasset://textures/particles/forcefield_glow_main.dds",
	vortice = "rbxasset://textures/particles/forcefield_vortex_main.dds",
	anel = "rbxasset://textures/ui/Input/Ring_padded.png",
	luz = "rbxasset://textures/glow.png",
}
local TEX = VfxKit.TEX

-- Nomes aceitos em ReplicatedStorage > EfeitosCustom
VfxKit.NOMES = {
	"Impacto",
	"Critico",
	"Corte",
	"Explosao",
	"Vazio",
	"Esquiva",
	"Defesa",
	"CargaCheia",
	"Morte",
	"Sangue",
	"Redemoinho",
	"Julgamento",
	"Meteoro",
	"Raio",
	"PassoSombrio",
	"Supremo",
}

local function seq(pontos): NumberSequence
	local chaves = {}
	for _, p in pontos do
		table.insert(chaves, NumberSequenceKeypoint.new(p[1], p[2]))
	end
	return NumberSequence.new(chaves)
end
VfxKit.seq = seq

local function cores(a: Color3, b: Color3?): ColorSequence
	return ColorSequence.new(a, b or a)
end

------------------------------------------------------------------------
-- Receitas: função (cor, escala) -> propriedades do ParticleEmitter
------------------------------------------------------------------------

local RECEITAS = {}

-- Faíscas em rastro (esticadas na direção em que voam), caem com a gravidade
RECEITAS.faiscas = function(cor: Color3, e: number)
	return {
		Gerada = "faisca",
		Texture = TEX.centelha,
		Color = cores(Color3.new(1, 1, 1), cor),
		LightEmission = 1,
		Brightness = 3,
		Orientation = Enum.ParticleOrientation.VelocityParallel,
		Size = seq({ { 0, 0.35 * e }, { 1, 0 } }),
		Squash = seq({ { 0, 2.5 }, { 1, 1 } }),
		Lifetime = NumberRange.new(0.18, 0.45),
		Speed = NumberRange.new(28 * e, 55 * e),
		SpreadAngle = Vector2.new(180, 180),
		Acceleration = Vector3.new(0, -45, 0),
		Drag = 5,
	}
end

-- Clarão: brilho forte que aparece e some num piscar
RECEITAS.clarao = function(cor: Color3, e: number)
	return {
		Gerada = "brilho",
		Texture = TEX.luz,
		Color = cores(cor:Lerp(Color3.new(1, 1, 1), 0.5)),
		LightEmission = 1,
		Brightness = 4,
		Size = seq({ { 0, 1 * e }, { 0.3, 5 * e }, { 1, 6 * e } }),
		Transparency = seq({ { 0, 0 }, { 0.5, 0.4 }, { 1, 1 } }),
		Lifetime = NumberRange.new(0.12, 0.16),
		Speed = NumberRange.new(0, 0),
		ZOffset = 2,
	}
end

-- Núcleo de explosão (bola de fogo que se expande)
RECEITAS.nucleo = function(cor: Color3, e: number)
	return {
		Texture = TEX.nucleo,
		Color = cores(Color3.new(1, 0.95, 0.8), cor),
		LightEmission = 1,
		Brightness = 2,
		Size = seq({ { 0, 2 * e }, { 1, 9 * e } }),
		Transparency = seq({ { 0, 0 }, { 0.6, 0.3 }, { 1, 1 } }),
		Lifetime = NumberRange.new(0.3, 0.45),
		Speed = NumberRange.new(2, 6),
		SpreadAngle = Vector2.new(180, 180),
		Rotation = NumberRange.new(0, 360),
		RotSpeed = NumberRange.new(-90, 90),
	}
end

-- Fogo subindo
RECEITAS.fogo = function(cor: Color3, e: number)
	return {
		Gerada = "chama",
		OrientacaoGerada = Enum.ParticleOrientation.FacingCameraWorldUp,
		Texture = TEX.fogo,
		Color = cores(Color3.fromRGB(255, 230, 140), cor),
		LightEmission = 1,
		Size = seq({ { 0, 2.2 * e }, { 1, 0.4 * e } }),
		Transparency = seq({ { 0, 0.1 }, { 1, 1 } }),
		Lifetime = NumberRange.new(0.35, 0.7),
		Speed = NumberRange.new(6 * e, 16 * e),
		SpreadAngle = Vector2.new(180, 180),
		Acceleration = Vector3.new(0, 18, 0),
		Drag = 4,
		Rotation = NumberRange.new(0, 360),
		RotSpeed = NumberRange.new(-120, 120),
	}
end

-- Fumaça que se espalha devagar
RECEITAS.fumaca = function(cor: Color3, e: number)
	return {
		Gerada = "fumaca",
		Texture = TEX.fumacaExplosao,
		Color = cores(cor),
		LightEmission = 0,
		LightInfluence = 1,
		Size = seq({ { 0, 1.8 * e }, { 1, 5.5 * e } }),
		Transparency = seq({ { 0, 0.35 }, { 0.6, 0.6 }, { 1, 1 } }),
		Lifetime = NumberRange.new(0.8, 1.5),
		Speed = NumberRange.new(4 * e, 10 * e),
		SpreadAngle = Vector2.new(180, 180),
		Acceleration = Vector3.new(0, 3, 0),
		Drag = 3,
		Rotation = NumberRange.new(0, 360),
		RotSpeed = NumberRange.new(-40, 40),
	}
end

-- Poeira no chão (fumaça baixa, se espalha para os lados)
RECEITAS.poeira = function(cor: Color3, e: number)
	return {
		Gerada = "fumaca",
		Texture = TEX.fumaca,
		Color = cores(cor),
		LightEmission = 0,
		LightInfluence = 1,
		Size = seq({ { 0, 1.2 * e }, { 1, 3.5 * e } }),
		Transparency = seq({ { 0, 0.4 }, { 1, 1 } }),
		Lifetime = NumberRange.new(0.5, 0.9),
		Speed = NumberRange.new(8 * e, 16 * e),
		SpreadAngle = Vector2.new(90, 5),
		EmissionDirection = Enum.NormalId.Right,
		Acceleration = Vector3.new(0, 2, 0),
		Drag = 5,
		Rotation = NumberRange.new(0, 360),
	}
end

-- Brasas/centelhas que ficam flutuando
RECEITAS.brasas = function(cor: Color3, e: number)
	return {
		Texture = TEX.faisca,
		Color = cores(Color3.new(1, 1, 1), cor),
		LightEmission = 1,
		Size = seq({ { 0, 0.4 * e }, { 1, 0 } }),
		Lifetime = NumberRange.new(0.6, 1.3),
		Speed = NumberRange.new(4 * e, 12 * e),
		SpreadAngle = Vector2.new(180, 180),
		Acceleration = Vector3.new(0, 6, 0),
		Drag = 2,
	}
end

-- Onda de choque deitada no chão (textura de anel que cresce)
RECEITAS.onda = function(cor: Color3, e: number)
	return {
		Gerada = "onda",
		Texture = TEX.onda,
		Color = cores(cor:Lerp(Color3.new(1, 1, 1), 0.4), cor),
		LightEmission = 1,
		Orientation = Enum.ParticleOrientation.VelocityPerpendicular,
		EmissionDirection = Enum.NormalId.Top,
		Size = seq({ { 0, 1 * e }, { 1, 14 * e } }),
		Transparency = seq({ { 0, 0 }, { 1, 1 } }),
		Lifetime = NumberRange.new(0.35, 0.35),
		Speed = NumberRange.new(0.01, 0.01),
		SpreadAngle = Vector2.new(0, 0),
	}
end

-- Anel fino de energia deitado no chão
RECEITAS.anel = function(cor: Color3, e: number)
	return {
		Gerada = "onda",
		Texture = TEX.anel,
		Color = cores(cor),
		LightEmission = 1,
		Brightness = 2,
		Orientation = Enum.ParticleOrientation.VelocityPerpendicular,
		EmissionDirection = Enum.NormalId.Top,
		Size = seq({ { 0, 0.5 * e }, { 1, 10 * e } }),
		Transparency = seq({ { 0, 0 }, { 1, 1 } }),
		Lifetime = NumberRange.new(0.4, 0.4),
		Speed = NumberRange.new(0.01, 0.01),
		SpreadAngle = Vector2.new(0, 0),
	}
end

-- Implosão: energia sendo sugada para o centro
RECEITAS.implosao = function(cor: Color3, e: number)
	return {
		Texture = TEX.implosao,
		Color = cores(cor:Lerp(Color3.new(1, 1, 1), 0.3), cor),
		LightEmission = 1,
		Size = seq({ { 0, 10 * e }, { 1, 0.5 * e } }),
		Transparency = seq({ { 0, 1 }, { 0.3, 0.2 }, { 1, 0 } }),
		Lifetime = NumberRange.new(0.25, 0.3),
		Speed = NumberRange.new(0, 0),
		Rotation = NumberRange.new(0, 360),
		RotSpeed = NumberRange.new(200, 400),
	}
end

-- Vórtice girando (carga de poder)
RECEITAS.vortice = function(cor: Color3, e: number)
	return {
		Texture = TEX.vortice,
		Color = cores(cor:Lerp(Color3.new(1, 1, 1), 0.3), cor),
		LightEmission = 1,
		Size = seq({ { 0, 3 * e }, { 1, 0.5 * e } }),
		Transparency = seq({ { 0, 0.6 }, { 0.5, 0.2 }, { 1, 1 } }),
		Lifetime = NumberRange.new(0.4, 0.6),
		Speed = NumberRange.new(0, 0),
		Rotation = NumberRange.new(0, 360),
		RotSpeed = NumberRange.new(-300, 300),
	}
end

-- Gotas (sangue, água): caem rápido
RECEITAS.gotas = function(cor: Color3, e: number)
	return {
		Texture = TEX.faisca,
		Color = cores(cor),
		LightEmission = 0,
		LightInfluence = 1,
		Orientation = Enum.ParticleOrientation.VelocityParallel,
		Size = seq({ { 0, 0.35 * e }, { 1, 0.15 * e } }),
		Squash = seq({ { 0, 1.5 }, { 1, 0.5 } }),
		Lifetime = NumberRange.new(0.35, 0.6),
		Speed = NumberRange.new(10 * e, 22 * e),
		SpreadAngle = Vector2.new(70, 70),
		Acceleration = Vector3.new(0, -70, 0),
	}
end

-- Estrela de 4 pontas (crítico)
RECEITAS.estrela = function(cor: Color3, e: number)
	return {
		Gerada = "estrela",
		Texture = TEX.faisca,
		Color = cores(Color3.new(1, 1, 1), cor),
		LightEmission = 1,
		Brightness = 3,
		Size = seq({ { 0, 1 * e }, { 0.25, 6 * e }, { 1, 3 * e } }),
		Transparency = seq({ { 0, 0 }, { 0.6, 0.2 }, { 1, 1 } }),
		Lifetime = NumberRange.new(0.22, 0.28),
		Speed = NumberRange.new(0, 0),
		Rotation = NumberRange.new(-15, 15),
		RotSpeed = NumberRange.new(-60, 60),
		ZOffset = 3,
	}
end

-- Lua de corte solta no ar (marca do golpe)
RECEITAS.corte = function(cor: Color3, e: number)
	return {
		Gerada = "corte",
		Texture = TEX.luz,
		Color = cores(Color3.new(1, 1, 1), cor),
		LightEmission = 1,
		Brightness = 2,
		Size = seq({ { 0, 3 * e }, { 1, 5 * e } }),
		Transparency = seq({ { 0, 0 }, { 0.5, 0.2 }, { 1, 1 } }),
		Lifetime = NumberRange.new(0.18, 0.22),
		Speed = NumberRange.new(0, 0),
		Rotation = NumberRange.new(0, 360),
		ZOffset = 2,
	}
end

-- Círculo mágico: deitado no chão (ou de pé diante do conjurador, com "direcao")
RECEITAS.circulo = function(cor: Color3, e: number)
	return {
		Gerada = "circulo",
		Texture = TEX.anel,
		Color = cores(cor:Lerp(Color3.new(1, 1, 1), 0.3), cor),
		LightEmission = 1,
		Brightness = 2,
		Orientation = Enum.ParticleOrientation.VelocityPerpendicular,
		EmissionDirection = Enum.NormalId.Top,
		Size = seq({ { 0, 0 }, { 0.12, 8 * e }, { 0.85, 8 * e }, { 1, 9 * e } }),
		Transparency = seq({ { 0, 1 }, { 0.12, 0.05 }, { 0.8, 0.2 }, { 1, 1 } }),
		Lifetime = NumberRange.new(1, 1),
		Speed = NumberRange.new(0.01, 0.01),
		SpreadAngle = Vector2.new(0, 0),
		Rotation = NumberRange.new(0, 360),
		RotSpeed = NumberRange.new(40, 40),
	}
end

VfxKit.RECEITAS = RECEITAS

-- Aplica as propriedades de uma receita (com a textura gerada, se já existir)
local function aplicar(emissor: ParticleEmitter, props)
	local gerada = props.Gerada and TexturasGeradas.obter(props.Gerada)
	for chave, valor in props do
		if chave ~= "Gerada" and chave ~= "OrientacaoGerada" then
			(emissor :: any)[chave] = valor
		end
	end
	if gerada then
		(emissor :: any).TextureContent = gerada
		if props.OrientacaoGerada then
			emissor.Orientation = props.OrientacaoGerada
		end
	end
end

------------------------------------------------------------------------
-- Soltar partículas
------------------------------------------------------------------------

--[[ Solta partículas de uma receita num ponto.
	opcoes: cor, escala, quantidade, direcao (Vector3: "para onde" vira o emissor),
	extra (propriedades que substituem as da receita) ]]
function VfxKit.soltar(pos: Vector3, receita: string, opcoes)
	opcoes = opcoes or {}
	local construtor = RECEITAS[receita]
	if not construtor then
		return
	end
	local anexo = Instance.new("Attachment")
	if opcoes.direcao and opcoes.direcao.Magnitude > 0.01 then
		-- o "Top" do emissor aponta para a direção pedida
		anexo.WorldCFrame = CFrame.lookAt(pos, pos + opcoes.direcao) * CFrame.Angles(-math.pi / 2, 0, 0)
	else
		anexo.WorldPosition = pos
	end
	anexo.Parent = terreno
	local emissor = Instance.new("ParticleEmitter")
	emissor.Enabled = false
	emissor.LightInfluence = 0
	aplicar(emissor, construtor(opcoes.cor or Color3.new(1, 1, 1), opcoes.escala or 1))
	for chave, valor in opcoes.extra or {} do
		(emissor :: any)[chave] = valor
	end
	emissor.Parent = anexo
	emissor:Emit(opcoes.quantidade or 10)
	Debris:AddItem(anexo, emissor.Lifetime.Max + 0.2)
end

-- Emissor contínuo preso numa peça/anexo (rastro de projétil, aura...). Devolve o emissor.
function VfxKit.continuo(pai: Instance, receita: string, taxa: number, opcoes)
	opcoes = opcoes or {}
	local emissor = Instance.new("ParticleEmitter")
	emissor.LightInfluence = 0
	aplicar(emissor, RECEITAS[receita](opcoes.cor or Color3.new(1, 1, 1), opcoes.escala or 1))
	for chave, valor in opcoes.extra or {} do
		(emissor :: any)[chave] = valor
	end
	emissor.Rate = taxa
	emissor.Parent = pai
	return emissor
end

-- Textura gerada num Beam (rastro de lâmina, raio...); sem ela, usa a de reserva
function VfxKit.texturaFeixe(feixe: Beam, nome: string, reserva: string?)
	local gerada = TexturasGeradas.obter(nome)
	if gerada then
		(feixe :: any).TextureContent = gerada
	elseif reserva then
		feixe.Texture = reserva
	end
end

-- Feixe de raio entre dois pontos, que pisca e some
function VfxKit.feixeRaio(de: Vector3, ate: Vector3, cor: Color3, largura: number, duracao: number)
	local a0, a1 = Instance.new("Attachment"), Instance.new("Attachment")
	a0.WorldPosition = de
	a1.WorldPosition = ate
	a0.Parent = terreno
	a1.Parent = terreno
	local feixe = Instance.new("Beam")
	feixe.Attachment0 = a0
	feixe.Attachment1 = a1
	feixe.Width0 = largura
	feixe.Width1 = largura
	feixe.Color = cores(Color3.new(1, 1, 1), cor)
	feixe.LightEmission = 1
	feixe.LightInfluence = 0
	feixe.Brightness = 4
	feixe.FaceCamera = true
	feixe.TextureMode = Enum.TextureMode.Stretch
	VfxKit.texturaFeixe(feixe, "raio", TEX.luz)
	feixe.Parent = a0
	-- troca o desenho do raio algumas vezes (parece que ele treme)
	task.spawn(function()
		local fim = os.clock() + duracao
		while os.clock() < fim do
			feixe.TextureSpeed = 0
			(feixe :: any).TextureLength = 1
			feixe.Transparency = NumberSequence.new(math.random() * 0.3)
			task.wait(0.03)
		end
		feixe.Transparency = NumberSequence.new(1)
	end)
	Debris:AddItem(a0, duracao + 0.1)
	Debris:AddItem(a1, duracao + 0.1)
end

------------------------------------------------------------------------
-- Efeitos próprios (ReplicatedStorage > EfeitosCustom)
------------------------------------------------------------------------

--[[ Se existir um efeito com este nome em EfeitosCustom, coloca uma cópia no lugar, solta
	as partículas e devolve true. Sem efeito próprio, devolve false (usa o padrão). ]]
function VfxKit.custom(nome: string, cframe: CFrame, escala: number?): boolean
	local pasta = ReplicatedStorage:FindFirstChild("EfeitosCustom")
	local modelo = pasta and pasta:FindFirstChild(nome)
	if not modelo then
		return false
	end
	local copia = modelo:Clone()
	local suporte: Instance = copia
	if copia:IsA("Attachment") then
		copia.WorldCFrame = cframe
		copia.Parent = terreno
	elseif copia:IsA("BasePart") then
		copia.Anchored = true
		copia.CanCollide = false
		copia.CanQuery = false
		copia.Transparency = 1
		copia.CFrame = cframe
		copia.Parent = workspace
	elseif copia:IsA("Model") then
		copia:PivotTo(cframe)
		for _, peca in copia:GetDescendants() do
			if peca:IsA("BasePart") then
				peca.Anchored = true
				peca.CanCollide = false
				peca.CanQuery = false
			end
		end
		copia.Parent = workspace
	else
		-- pasta com emissores soltos: põe num anexo
		local anexo = Instance.new("Attachment")
		anexo.WorldCFrame = cframe
		anexo.Parent = terreno
		copia.Parent = anexo
		suporte = anexo
	end
	local vida = 0.5
	for _, objeto in copia:GetDescendants() do
		if objeto:IsA("ParticleEmitter") then
			if escala and escala ~= 1 then
				local chaves = {}
				for _, k in objeto.Size.Keypoints do
					table.insert(chaves, NumberSequenceKeypoint.new(k.Time, k.Value * escala, k.Envelope * escala))
				end
				objeto.Size = NumberSequence.new(chaves)
			end
			local atraso = objeto:GetAttribute("EmitDelay") or 0
			local quantidade = objeto:GetAttribute("EmitCount") or 20
			task.delay(atraso, function()
				objeto:Emit(quantidade)
			end)
			objeto.Enabled = false
			vida = math.max(vida, atraso + objeto.Lifetime.Max)
		elseif objeto:IsA("Beam") or objeto:IsA("Trail") then
			local duracao = objeto:GetAttribute("Duracao") or 0.5
			objeto.Enabled = true
			task.delay(duracao, function()
				objeto.Enabled = false
			end)
			vida = math.max(vida, duracao + 0.5)
		end
	end
	Debris:AddItem(suporte, vida + 0.3)
	return true
end

return VfxKit
