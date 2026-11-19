# Aube des civilisations

Jeu de gestion en 2D pixel art pour Godot 4. Dans la vallée de l’Aube, partez d’un campement et développez une civilisation jusqu’à son premier vol orbital. Sept âges et dix-neuf constructions à débloquer.

## Lancer le jeu

Importez `project.godot` dans Godot 4, puis appuyez sur **F5**. Le jeu démarre en plein écran, avec une définition de référence de **1920 × 1080**. **F11** bascule en mode fenêtré. Si l’éditeur affiche le jeu dans son propre panneau, désactivez l’intégration de la fenêtre de jeu ou lancez `/snap/bin/godot-4 --path .` dans ce dossier après le premier import des ressources.

## Jouer

- **Clic gauche** · Envoyer le villageois récolter, examiner un bâtiment ou utiliser l’outil sélectionné.
- **WASD ou ZQSD** · Déplacer la caméra. Maintenez le bouton central et glissez pour la déplacer à la souris.
- **Molette** · Zoomer sur le pointeur. **C** ou **Centrer le camp** dans le menu recentre la caméra.
- **Clic droit ou Échap** · Annuler l’outil sélectionné. **Espace** ou le bouton de la barre supérieure met les déplacements et la production en pause.
- Le sac ouvre tous les stocks. Le livre ouvre les détails de l’objectif. L’engrenage donne accès à la vitesse, à la chronologie et à la sauvegarde.

Cliquez sur les arbres, les rochers et les buissons pour donner des ordres de récolte. Vous pouvez cliquer sur plusieurs ressources distinctes pendant un trajet. Le villageois prend aussi des chemins en diagonale. Une fois sur place, il travaille quelques secondes, puis la ressource disparaît. Le chargement rejoint les stocks au retour au camp. Les quantités récoltées s’affichent avec le nombre et l’icône de la ressource.

Le **bâton de fouille** coûte **2 bois**. Il permet au villageois de déterrer des racines comestibles, de récolter les buissons plus vite et de rapporter **4 vivres au lieu de 2**. Vous pouvez construire et passer au prochain âge avant de l’avoir fabriqué.

La barre de construction affiche les bâtiments de l’âge actuel. **Âges précédents** ouvre les constructions déjà débloquées. Les bâtiments d’extraction se placent sur les sites marqués en ocre, y compris après la récolte de la ressource de surface. Les cartes indiquent la production par cycle. Cliquez sur un bâtiment placé pour consulter sa recette, suivre ses gains ou le démolir.

Le journal montre le prochain objectif. Son bouton de changement d’âge apparaît dès que les conditions sont réunies. Les stocks requis sont dépensés au passage d’âge. Les actions importantes déclenchent une sauvegarde automatique locale, rechargée au lancement. Après le vol orbital, la vallée reste jouable.

La carte et les sprites sont inclus. Le fichier `assets/ui/NOTO-LICENSE.txt` contient la licence de la police des titres.
