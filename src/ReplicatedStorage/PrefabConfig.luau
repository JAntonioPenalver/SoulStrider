local PrefabConfig = {}

-- Puedes configurar cada prefabricado con:
-- Name: El nombre del modelo en ReplicatedStorage.Prefabs
-- DisplayName: El nombre que aparece en la UI
-- YOffset: (Opcional) Ajuste de altura extra
-- RotationOffset: (Opcional) Rotación extra en grados (Vector3)

PrefabConfig.Structures = {
	{
		Name = "TorreVigilancia", 
		DisplayName = "Torre de Vigilancia",
		YOffset = 0,
		RotationOffset = Vector3.new(0, 0, 0),
		RequiredClicks = 18
	},
	{
		Name = "ParedMadera", 
		DisplayName = "Pared de Madera",
		YOffset = 0,
		RotationOffset = Vector3.new(0, 0, 0),
		RequiredClicks = 15
	},
	{
		Name = "Fogata", 
		DisplayName = "Fogata",
		YOffset = -3,
		RotationOffset = Vector3.new(0, 0, 0),
		RequiredClicks = 5
	},
	{
		Name = "ParedPiedra", 
		DisplayName = "Pared de Piedra",
		YOffset = 0,
		RotationOffset = Vector3.new(0, 0, 0),
		RequiredClicks = 30
	},
	{
		Name = "TiendaCampaña", 
		DisplayName = "Campamento",
		YOffset = -0.5,
		RotationOffset = Vector3.new(0, 0, 0),
		RequiredClicks = 10
	},
	{
		Name = "Pinchos",
		DisplayName = "Pinchos",
		YOffset = -0.5,
		RotationOffset = Vector3.new(0, 0, 0),
		RequiredClicks = 20
	},
	{
		Name = "Caseta",
		DisplayName = "Caseta",
		YOffset = 0,
		RotationOffset = Vector3.new(0, 0, 0),
		RequiredClicks = 50
	},
	{
		Name = "Cofre",
		DisplayName = "Cofre",
		YOffset = 0,
		RotationOffset = Vector3.new(0, 0, 0),
		RequiredClicks = 10
	}
}

return PrefabConfig
