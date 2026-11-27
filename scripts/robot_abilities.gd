extends RefCounted

const COOLDOWN := 5.0
const MODULES := {
	"hydrogen": {"name": "Hák", "mode": "hook", "reach": 340.0, "count": 1, "width": 17.0, "description": "Vystrelí hák a pritiahne jeden atóm."},
	"oxygen": {"name": "Odrazový impulz", "mode": "pulse", "radius": 210.0, "turn": PI, "speed": 1.0, "description": "Obráti smer atómov a čiernych gúľ v okruhu."},
	"water": {"name": "Blink", "mode": "blink", "reach": 205.0, "description": "Okamžite presunie robota smerom ku kurzoru."},
	"hydrogen_peroxide": {"name": "Dvojhák", "mode": "hook", "reach": 300.0, "count": 2, "width": 21.0, "description": "V jednej dráhe môže pritiahnuť dva atómy."},
	"carbon_dioxide": {"name": "Široký impulz", "mode": "pulse", "radius": 300.0, "turn": PI, "speed": 1.0, "description": "Obráti smer atómov a čiernych gúľ vo väčšom okruhu."},
	"carbon_monoxide": {"name": "Ďaleký hák", "mode": "hook", "reach": 475.0, "count": 1, "width": 13.0, "description": "Užší hák s dlhším dosahom."},
	"methane": {"name": "Zrýchlenie", "mode": "boost", "duration": 1.5, "suction": 1.0, "description": "Na 1,5 sekundy zdvojnásobí rýchlosť robota."},
	"methanol": {"name": "Nasávacie zrýchlenie", "mode": "boost", "duration": 1.0, "suction": 1.65, "description": "Na sekundu zdvojnásobí rýchlosť a posilní nasávanie."},
	"ethanol": {"name": "Ochranný blink", "mode": "blink", "reach": 155.0, "shield": 0.85, "description": "Presunie robota a na chvíľu ochráni vrecko pred zásahom."},
	"formic_acid": {"name": "Vírový impulz", "mode": "pulse", "radius": 230.0, "turn": PI / 2.0, "speed": 1.0, "description": "Odkloní dráhu blízkych atómov a gúľ o 90 stupňov."},
	"acetic_acid": {"name": "Brzdiaci impulz", "mode": "pulse", "radius": 245.0, "turn": PI, "speed": 0.55, "description": "Obráti smer atómov a gúľ a spomalí ich."},
}
