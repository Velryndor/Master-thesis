# Beam → Python → Godot

Démo Godot 4, en plein écran sur l'écran le plus haut dans la disposition du bureau.
Si plusieurs écrans sont à la même hauteur, elle choisit celui avec la plus petite
surface en pixels. Beam doit être calibré sur cet écran.
Le repère vert suit le regard ; neuf cibles permettent de contrôler le décalage.
Échap quitte. F11 permet de quitter temporairement le plein écran pour déplacer
la fenêtre sur l'écran calibré, puis de revenir en plein écran.
La conversion des coordonnées est prévue pour le plein écran, pas le mode fenêtré.

## Démarrage

Laisser Beam ouvert, calibré et avec le suivi actif.

Terminal 1 :

```bash
godot --path /home/velryndor/Documents/These_master_Python_scripts/beam-godot
```

Terminal 2 :

```bash
source /home/velryndor/Documents/These_master_Python_scripts/.venv/bin/activate
python /home/velryndor/Documents/These_master_Python_scripts/beam-godot/bridge.py
```

Le `.venv` partagé se trouve dans le dossier parent. Il contient `beam-eye-tracker==2.2.0`.

Pour lancer Godot et la passerelle ensemble :

```bash
./lancer.sh
```

La fermeture de Godot arrête également la passerelle lancée par ce script.

## Données

JSON UDP localhost:4243 : x/y en pixels du bureau, confidence (0–3), valid,
timestamp Beam en secondes. Confiance >= 2 admise. Le repère disparaît après
500 ms sans paquet ou quand le regard sort de l'écran de la démo.
Aucune donnée n'est enregistrée.

Pour une intégration dans un jeu fenêtré, il faudra transmettre à Beam la
géométrie réelle de la zone de rendu et utiliser viewport_gaze, ou convertir
les coordonnées du bureau vers cette zone. Cette démo ne fait pas cette étape.

Sources :
- https://docs.beam.eyeware.tech/2.2.0/api/python/index.html
- https://docs.beam.eyeware.tech/2.2.0/basics/reference_frames.html
- https://docs.godotengine.org/en/stable/classes/class_packetpeerudp.html
