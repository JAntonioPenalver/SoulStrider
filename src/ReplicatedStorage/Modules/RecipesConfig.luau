local RecipesConfig = {}

RecipesConfig.Crafting = {
	{
		Name = "Pico de Piedra",
		Result = "Pickaxe",
		Amount = 1,
		Time = 3,
		Pattern = {
			[1] = "Piedra", [2] = "Piedra", [3] = "Piedra",
			[5] = "Tronco",
			[8] = "Tronco"
		}
	},
	{
		Name = "Hacha de Piedra",
		Result = "Axe",
		Amount = 1,
		Time = 3,
		Pattern = {
			[1] = "Piedra", [2] = "Piedra",
			[4] = "Piedra", [5] = "Tronco",
			[8] = "Tronco"
		}
	},
	{
		Name = "Espada de Hierro",
		Result = "Espada",
		Amount = 1,
		Time = 3,
		Pattern = {
			[2] = "Pepita de Hierro",
			[5] = "Pepita de Hierro",
			[8] = "Tronco"
		}
	},
	{
		Name = "Antorcha",
		Result = "Antorcha",
		Amount = 4,
		Time = 3,
		Pattern = {
			[5] = "Piedra",
			[8] = "Tronco"
		}
	},
	{
		Name = "Venda",
		Result = "Venda",
		Amount = 2,
		Time = 3,
		Pattern = {
			[4] = "Wheat", [5] = "Wheat",
		}
	}
}

RecipesConfig.Cooking = {
	{
		Name = "Carne Asada",
		Result = "SteakOnBone",
		Ingredients = {"Carne"},
		Time = 5
	},
	{
		Name = "Pan Horneado",
		Result = "Pan",
		Ingredients = {"Wheat", "Agua"},
		Time = 8
	},
	{
		Name = "Café Caliente",
		Result = "Cafe",
		Ingredients = {"Agua"},
		Time = 4
	}
}

return RecipesConfig
