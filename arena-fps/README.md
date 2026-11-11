# SECTEUR 09 — Survie

Prototype FPS Godot 4, sans dépendance ni ressource externe. Ouvrir project.godot dans Godot et appuyer sur F6 dans main.tscn ou F5.

## Lancer directement

```bash
godot --path /home/velryndor/Documents/Master-thesis/arena-fps
```

Une fenêtre présente les commandes au démarrage. Cliquer sur **OK** pour commencer : les vagues restent suspendues jusque-là. La santé est affichée dans une barre centrée en bas de l’écran, et le compteur d’éliminations en haut à gauche.

Le jeu s'ouvre en plein écran sur l'écran placé le plus haut, comme la démo précédente.

- Souris : viser ; clic gauche : tirer (un clic par balle).
- ZQSD ou WASD : marcher ; Maj : courir ; Espace : sauter.
- R : recharger (12 balles, réserve illimitée, 1,25 seconde).
- Échap : pause, reprise, nouvelle partie ou quitter.
- F11 : basculer plein écran / fenêtre.

Les ennemis demandent trois impacts, poursuivent le joueur et attaquent au contact. La première vague compte cinq ennemis, puis deux supplémentaires par vague. Leur vitesse augmente progressivement. Cinq secondes séparent les vagues ; le joueur récupère 20 points de santé et un chargeur à chaque nouvelle vague. La mort affiche un écran permettant de recommencer.

Ce prototype utilise une visée classique à la souris. Beam n'est pas requis. L'adaptation future de l'interface à partir du regard pourra être ajoutée à cette base.

Les modèles et l'arène sont construits dans arena.gd et enemy.gd à partir de formes simples. Aucun son n’est inclus. La police Black Ops One est fournie avec sa licence dans fonts/.

## Décor et interface

Place urbaine en ruines : façades ouvertes, étages endommagés, silhouettes de bâtiments lointains, voitures abandonnées, lampadaires, débris, herbes et chaussée marquée. Ambiance nocturne : lumière lunaire froide, lampadaires chauds, brume et lampe automatique devant le joueur. Le décor est généré de manière déterministe avec des matériaux procéduraux, sans téléchargement d’assets. Le centre reste dégagé pour les déplacements et la poursuite des ennemis.

Le HUD est sans panneaux de fond, avec un contour discret autour des textes pour conserver leur contraste, avec les vagues en haut, les éliminations à gauche, les munitions à droite et la barre de santé centrée en bas. Les commandes restent dans une fenêtre initiale et les touches gardent leurs contours blancs.

Police de titres et compteurs : Black Ops One (Google Fonts), style pochoir militaire. Fichier et licence SIL OFL inclus dans `fonts/`. Les flaques ovales ont été supprimées du sol.

Les zombies sont des modèles procéduraux articulés : visage, mains et doigts, vêtements abîmés, variations de couleurs, démarche boiteuse et bras tendus à proximité. Le nombre de points de vie est inscrit au centre de la barre avec la police du HUD.

Les surfaces utilisent un filtrage avec mipmaps et anisotropie ; l’anticrénelage MSAA 2× est activé. Le béton et l’asphalte ont un relief léger, et la brique une texture générée pour ce projet. Les détails fins et le modèle de pistolet sont exclus des ombres instables ; les grandes surfaces du décor gardent leurs ombres. Les trottoirs ne se recouvrent plus aux angles et les enseignes sont décalées devant les façades.

Correction du rendu nocturne : les ombres projetées de la lune et de la lampe du joueur sont désactivées pour éviter les bandes observées sur les murs et les voitures. Leurs lumières restent actives, ainsi que les textures et leur relief. Cette solution retire également les ombres projetées des objets au sol.

## Retours de tir

Le pistolet détaillé porte une lampe sous le canon. Les impacts confirmés affichent un hit marker et des dégâts flottants pendant 0,85 seconde. Le corps reçoit 34 points de dégâts ; la tête, détectée par une zone suivant son animation, reçoit 68 points. Les dégâts et le marqueur sont orange pour les tirs à la tête. Les tirs ratés ne produisent pas de marqueur.
