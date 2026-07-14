local TalentModule = {}

TalentModule.Talents = {
	-- [ RAMA: FÍSICO ] --
	{
		Name = "Resistencia Local",
		Description = "Aumenta tu salud máxima en un 5%.",
		Icon = "rbxassetid://87380845673789",
		Branch = "Fisico"
	},
	{
		Name = "Fibra Reforzada",
		Description = "Reduce el daño físico recibido en un 4%.",
		Icon = "rbxassetid://87380845673789",
		Branch = "Fisico"
	},
	{
		Name = "Empuje",
		Description = "Tus ataques cargados desplazan al enemigo un 10% más lejos.",
		Icon = "rbxassetid://87380845673789",
		Branch = "Fisico"
	},
	{
		Name = "Recuperación Muscular",
		Description = "La energía (estamina) se regenera un 5% más rápido.",
		Icon = "rbxassetid://87380845673789",
		Branch = "Fisico"
	},
	{
		Name = "Fuerza Bruta I",
		Description = "Aumenta el daño de ataques básicos en un 3%.",
		Icon = "rbxassetid://87380845673789",
		Branch = "Fisico"
	},

	-- [ RAMA: VELOCIDAD ] --
	{
		Name = "Pies Ligeros",
		Description = "Aumenta la velocidad de caminata en un 5%.",
		Icon = "rbxassetid://136934933747607",
		Branch = "Velocidad"
	},
	{
		Name = "Reacción Rápida",
		Description = "Reduce el tiempo de recuperación tras un esquive en un 5%.",
		Icon = "rbxassetid://136934933747607",
		Branch = "Velocidad"
	},
	{
		Name = "Zancada",
		Description = "Correr consume un 5% menos de estamina por segundo.",
		Icon = "rbxassetid://136934933747607",
		Branch = "Velocidad"
	},
	{
		Name = "Agilidad de Manos",
		Description = "Aumenta la velocidad de ataque con armas ligeras en un 4%.",
		Icon = "rbxassetid://136934933747607",
		Branch = "Velocidad"
	},
	{
		Name = "Reflejos",
		Description = "Tienes un 3% de probabilidad de esquivar automáticamente un ataque débil.",
		Icon = "rbxassetid://136934933747607",
		Branch = "Velocidad"
	},

	-- [ RAMA: AFINIDAD MÁGICA ] --
	{
		Name = "Sensibilidad al Maná",
		Description = "Aumenta tu reserva total de maná en un 5%.",
		Icon = "rbxassetid://124173718825243",
		Branch = "Magia"
	},
	{
		Name = "Flujo Constante",
		Description = "La regeneración de maná aumenta un 5%.",
		Icon = "rbxassetid://124173718825243",
		Branch = "Magia"
	},
	{
		Name = "Canalización",
		Description = "Reduce el tiempo de lanzamiento de hechizos básicos en un 4%.",
		Icon = "rbxassetid://124173718825243",
		Branch = "Magia"
	},
	{
		Name = "Eficiencia Arcana",
		Description = "Tus hechizos consumen un 3% menos de maná.",
		Icon = "rbxassetid://124173718825243",
		Branch = "Magia"
	},
	{
		Name = "Resonancia",
		Description = "Aumenta el daño mágico elemental en un 4%.",
		Icon = "rbxassetid://124173718825243",
		Branch = "Magia"
	},

	-- [ RAMA: MÉDICO ] --
	{
		Name = "Vendaje Rápido",
		Description = "Reduce el tiempo de uso de objetos curativos en un 10%.",
		Icon = "rbxassetid://114450740578318",
		Branch = "Medico"
	},
	{
		Name = "Conocimiento Médico",
		Description = "La eficacia de la curación aplicada aumenta en un 5%.",
		Icon = "rbxassetid://114450740578318",
		Branch = "Medico"
	},
	{
		Name = "Primeros Auxilios",
		Description = "Al curar a un aliado, recuperas un 2% de tu propia vida.",
		Icon = "rbxassetid://114450740578318",
		Branch = "Medico"
	},
	{
		Name = "Estabilización",
		Description = "Los aliados que revives vuelven con un 5% extra de energía.",
		Icon = "rbxassetid://114450740578318",
		Branch = "Medico"
	},
	{
		Name = "Resistencia Tóxica",
		Description = "Reduce la duración de efectos de veneno o quemadura en un 10%.",
		Icon = "rbxassetid://114450740578318",
		Branch = "Medico"
	}
}

return TalentModule