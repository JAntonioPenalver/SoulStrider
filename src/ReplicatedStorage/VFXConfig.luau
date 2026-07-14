local VFXConfig = {
	Effects = {
		Explosion = {
			Name = "Explosion",
			SoundId = "rbxassetid://139651066813230",
			Damage = 80,
			Duration = 1.5,
			CleanUpDebris = 3,
			ShakeRadius = 80,
			ShakeIntensity = 0.8,
			ShakeDuration = 0.5,
			HitboxSize = Vector3.new(20, 20, 20), -- Expanded fallback size (Radius = 10 studs)
			Volume = 3,
		},
		Fuego = {
			Name = "Fuego",
			SoundId = "rbxassetid://112352139435056",
			Damage = 10,
			TickInterval = 3,
			BurnChance = 0.50, -- Increased chance to 50% as requested!
			BurnDamage = 3,
			BurnDuration = 6,
			HitboxSize = Vector3.new(12, 12, 12), -- Expanded fallback size (Radius = 6 studs)
			Volume = 2.5,
		}
	}
}
return VFXConfig