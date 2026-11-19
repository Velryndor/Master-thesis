extends RefCounted

const TOOL_NAME := "Bâton de fouille"
const TOOL_COST := {"wood": 2}
const FOOD_HAND_YIELD := 2
const FOOD_TOOL_YIELD := 4
const STOCK_LIMIT := 9999

const RESOURCES := {
	"wood": {"name": "Bois", "color": Color("ce9a66"), "age": 0},
	"stone": {"name": "Pierre", "color": Color("b9c9d2"), "age": 0},
	"food": {"name": "Vivres", "color": Color("e3ae64"), "age": 0},
	"ceramic": {"name": "Céramique", "color": Color("e6876a"), "age": 1},
	"copper": {"name": "Cuivre", "color": Color("ee9367"), "age": 2},
	"tin": {"name": "Étain", "color": Color("a5bbcb"), "age": 2},
	"bronze": {"name": "Bronze", "color": Color("edba6e"), "age": 2},
	"iron": {"name": "Minerai de fer", "color": Color("d88d85"), "age": 3},
	"coal": {"name": "Charbon", "color": Color("8c97a7"), "age": 3},
	"steel": {"name": "Acier", "color": Color("c8d9df"), "age": 3},
	"oil": {"name": "Pétrole", "color": Color("af91c1"), "age": 4},
	"power": {"name": "Énergie", "color": Color("f3d57f"), "age": 4},
	"mechanism": {"name": "Mécanismes", "color": Color("e2a588"), "age": 4},
	"silica": {"name": "Silice", "color": Color("9cddd2"), "age": 5},
	"circuits": {"name": "Circuits", "color": Color("83dbac"), "age": 5},
	"titanium": {"name": "Titane", "color": Color("afb3ee"), "age": 6},
	"modules": {"name": "Modules", "color": Color("94d7f0"), "age": 6},
}

# Place the suppliers before the buildings that use their output. This is also
# the default order shown in the construction menu.
const BUILDINGS := {
	"camp": {
		"name": "Campement", "description": "Le foyer autour duquel s'installe le premier groupe.",
		"category": "Habitat", "age": 0, "cost": {}, "input": {}, "output": {}, "deposit": "",
	},
	"shelter": {
		"name": "Abri de branchages", "description": "Un premier abri permanent pour le groupe.",
		"category": "Habitat", "age": 0, "cost": {"wood": 6, "stone": 3},
		"input": {}, "output": {}, "deposit": "",
	},
	"lumber_camp": {
		"name": "Camp de bûcherons", "description": "Produit du bois sur un site forestier, même après une récolte manuelle.",
		"category": "Collecte", "age": 0, "cost": {"wood": 5, "stone": 3},
		"input": {}, "output": {"wood": 3}, "deposit": "wood",
	},
	"quarry": {
		"name": "Carrière", "description": "Extrait de la pierre d'un affleurement.",
		"category": "Collecte", "age": 0, "cost": {"wood": 5, "stone": 2},
		"input": {}, "output": {"stone": 3}, "deposit": "stone",
	},
	"farm": {
		"name": "Ferme", "description": "Cultive des vivres sur une parcelle libre.",
		"category": "Collecte", "age": 1, "cost": {"wood": 8, "stone": 4},
		"input": {}, "output": {"food": 4}, "deposit": "",
	},
	"clay_kiln": {
		"name": "Four de potier", "description": "Cuit la matière minérale avec du bois pour produire de la céramique.",
		"category": "Raffinage", "age": 1, "cost": {"wood": 6, "stone": 8},
		"input": {"wood": 1, "stone": 1}, "output": {"ceramic": 2}, "deposit": "",
	},
	"copper_mine": {
		"name": "Mine de cuivre", "description": "Exploite un filon de cuivre.",
		"category": "Collecte", "age": 2, "cost": {"wood": 8, "stone": 6, "ceramic": 2},
		"input": {}, "output": {"copper": 3}, "deposit": "copper",
	},
	"tin_mine": {
		"name": "Mine d'étain", "description": "Exploite un filon d'étain.",
		"category": "Collecte", "age": 2, "cost": {"wood": 8, "stone": 6, "ceramic": 2},
		"input": {}, "output": {"tin": 3}, "deposit": "tin",
	},
	"bronze_foundry": {
		"name": "Fonderie de bronze", "description": "Allie cuivre et étain dans un four à bois.",
		"category": "Raffinage", "age": 2, "cost": {"wood": 10, "stone": 10, "ceramic": 4},
		"input": {"copper": 2, "tin": 1, "wood": 1}, "output": {"bronze": 2}, "deposit": "",
	},
	"iron_mine": {
		"name": "Mine de fer", "description": "Extrait le minerai d'un filon de fer.",
		"category": "Collecte", "age": 3, "cost": {"wood": 10, "stone": 8, "bronze": 2},
		"input": {}, "output": {"iron": 3}, "deposit": "iron",
	},
	"coal_mine": {
		"name": "Mine de charbon", "description": "Exploite une veine de charbon pour alimenter les fours.",
		"category": "Collecte", "age": 3, "cost": {"wood": 10, "stone": 8, "bronze": 2},
		"input": {}, "output": {"coal": 3}, "deposit": "coal",
	},
	"forge": {
		"name": "Forge", "description": "Transforme le minerai de fer en acier grâce au charbon.",
		"category": "Raffinage", "age": 3, "cost": {"stone": 12, "ceramic": 4, "bronze": 4},
		"input": {"iron": 2, "coal": 1}, "output": {"steel": 2}, "deposit": "",
	},
	"oil_well": {
		"name": "Puits de pétrole", "description": "Pompe le pétrole d'un gisement.",
		"category": "Collecte", "age": 4, "cost": {"wood": 10, "stone": 10, "steel": 4},
		"input": {}, "output": {"oil": 3}, "deposit": "oil",
	},
	"power_plant": {
		"name": "Centrale thermique", "description": "Produit de l'énergie avec du charbon et du pétrole.",
		"category": "Énergie", "age": 4, "cost": {"stone": 14, "steel": 6, "ceramic": 4},
		"input": {"oil": 1, "coal": 1}, "output": {"power": 6}, "deposit": "",
	},
	"factory": {
		"name": "Usine mécanique", "description": "Façonne l'acier en mécanismes à l'aide d'énergie.",
		"category": "Raffinage", "age": 4, "cost": {"stone": 12, "steel": 8},
		"input": {"steel": 1, "power": 1}, "output": {"mechanism": 2}, "deposit": "",
	},
	"silica_mine": {
		"name": "Carrière de silice", "description": "Récolte de la silice sur un gisement de quartz.",
		"category": "Collecte", "age": 5, "cost": {"steel": 6, "mechanism": 4},
		"input": {}, "output": {"silica": 3}, "deposit": "silica",
	},
	"electronics_lab": {
		"name": "Atelier électronique", "description": "Transforme la silice en circuits grâce à l'énergie.",
		"category": "Raffinage", "age": 5, "cost": {"steel": 8, "mechanism": 6, "power": 8},
		"input": {"silica": 2, "power": 2}, "output": {"circuits": 2}, "deposit": "",
	},
	"titanium_mine": {
		"name": "Mine de titane", "description": "Exploite un filon de titane destiné aux constructions spatiales.",
		"category": "Collecte", "age": 6, "cost": {"steel": 8, "mechanism": 6},
		"input": {}, "output": {"titanium": 3}, "deposit": "titanium",
	},
	"space_center": {
		"name": "Atelier orbital", "description": "Assemble les modules de la fusée avec du titane, des mécanismes et des circuits.",
		"category": "Raffinage", "age": 6, "cost": {"steel": 10, "mechanism": 8, "circuits": 8},
		"input": {"titanium": 2, "mechanism": 1, "circuits": 1, "power": 2},
		"output": {"modules": 2}, "deposit": "",
	},
	"launchpad": {
		"name": "Pas de tir", "description": "Accueille la fusée de la première mission orbitale.",
		"category": "Exploration", "age": 6, "cost": {"steel": 18, "titanium": 10, "mechanism": 8},
		"input": {}, "output": {}, "deposit": "",
	},
}

const AGES := [
	{
		"name": "Paléolithique", "description": "Les premiers habitants vivent des ressources qu'ils rapportent au campement.",
		"goal": "Rapportez des ressources au campement et installez un abri permanent.",
		"cost": {"wood": 8, "stone": 6, "food": 6}, "buildings": {"shelter": 1},
	},
	{
		"name": "Néolithique", "description": "Les cultures et la poterie transforment le campement en village.",
		"goal": "Fondez une ferme et cuisez vos premières poteries.",
		"cost": {"wood": 8, "food": 12, "ceramic": 4}, "buildings": {"farm": 1, "clay_kiln": 1},
	},
	{
		"name": "Âge du bronze", "description": "La maîtrise des alliages ouvre la voie aux outils de métal.",
		"goal": "Exploitez le cuivre et l'étain pour couler du bronze.",
		"cost": {"bronze": 8, "food": 12, "ceramic": 3}, "buildings": {"bronze_foundry": 1},
	},
	{
		"name": "Âge du fer", "description": "Des fours plus chauds permettent de produire un métal plus résistant.",
		"goal": "Approvisionnez la forge en minerai de fer et en charbon.",
		"cost": {"steel": 10, "bronze": 4, "food": 16}, "buildings": {"forge": 1},
	},
	{
		"name": "Ère industrielle", "description": "Les machines et l'énergie accélèrent la production du village.",
		"goal": "Alimentez une usine mécanique avec votre propre centrale.",
		"cost": {"steel": 12, "power": 16, "mechanism": 8, "food": 18},
		"buildings": {"power_plant": 1, "factory": 1},
	},
	{
		"name": "Ère numérique", "description": "De la silice aux premiers circuits, l'électronique change l'échelle des possibles.",
		"goal": "Faites fonctionner un atelier électronique pour produire des circuits.",
		"cost": {"circuits": 12, "power": 18, "mechanism": 10}, "buildings": {"electronics_lab": 1},
	},
	{
		"name": "Ère spatiale", "description": "Des modules en titane emporteront la civilisation au-delà de son premier horizon.",
		"goal": "Assemblez les modules de la fusée et lancez la première mission orbitale.",
		"cost": {"modules": 12, "power": 20, "circuits": 8, "food": 8},
		"buildings": {"space_center": 1, "launchpad": 1},
	},
]
