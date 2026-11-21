# Locky

Locky verrouille votre Mac quand vous vous éloignez avec votre iPhone et le déverrouille quand vous revenez.

Réécriture 2026 en Swift 6 / SwiftUI de l'app historique (Objective‑C, Parse, extension Today, WatchKit 1).
L'ancien code est conservé dans [`Legacy/`](Legacy) pour référence ; il n'est plus compilé.

| Plateforme | Minimum | Cible |
| --- | --- | --- |
| iPhone, iPhone Duo (pas d'iPad) | iOS 27 | `Locky` + extension `LockyWidgets` |
| Apple Watch | watchOS 27 | `LockyWatch` + extension `LockyWatchWidgets` |
| Mac | macOS 27 | `LockyMac` (menu natif dans la barre d'état, Developer ID) + extension `LockyMacWidgets` (widget de bureau, contrôles « Locky activé » et « Verrouiller le Mac » pour le Centre de contrôle et la barre des menus) |

## Démarrer

```bash
open Locky.xcodeproj
```

Un projet Xcode classique, à modifier dans Xcode. Ses dossiers `Apps/` sont des dossiers synchronisés : tout
fichier ajouté dans le dossier d'une cible en fait partie, sans toucher au projet. Les réglages de chaque cible
(identifiants, droits, `Info.plist`) se changent dans Xcode, onglets Signing & Capabilities et Info.

Tests du cœur partagé (protocole, crypto, proximité) :

```bash
swift test --package-path Packages/LockyKit
```

### Mode démo (DEBUG)

Le simulateur n'a pas de Bluetooth. Pour voir l'app appairée : argument de lancement `-LockyDemo YES` (le
bouton rond « Verrouiller / Déverrouiller » simule alors un Mac qui répond). Options : `-LockyDemoTab settings|intrusions`,
`-LockyDemoLocked YES`, `-LockyDemoAutoUnlock YES` (déverrouille puis reverrouille tout seul, pour voir les
transitions), `-LockyDemoPairing code|calibrating|done`, `-LockyDemoOnboardingPage 0…5` (avec
`-locky.onboardingCompleted NO`), `-LockyDemoSetup waiting|walkAway|comeBack|magic|tour` (premier essai guidé ;
`tour` le joue en entier : l'iPhone s'éloigne, le Mac se verrouille, l'iPhone revient, il se déverrouille),
`-LockyDemoMacName "…"` (nom du Mac, pour vérifier les noms longs dans les widgets et la Live Activity),
`-LockyDemoOutOfReach YES` (Mac hors de portée : widgets estompés, île grise),
`-LockyDemoCamera denied|notDetermined|unavailable` (caméra du Mac non autorisée, avec
`-locky.intrusionDetection YES` : avertissement dans les réglages et les rapports d'intrusion). Pour que
les widgets et la Live Activity voient les images du groupe d'apps au simulateur, compiler signé localement
(`CODE_SIGN_IDENTITY=- CODE_SIGN_STYLE=Manual DEVELOPMENT_TEAM=`) plutôt qu'avec `CODE_SIGNING_ALLOWED=NO`.

Côté Mac (DEBUG) : `-LockyDemo YES` (iPhone appairé fictif, pour le menu et le widget), `-LockyDemoPairingTour YES`
(toutes les étapes de la fenêtre d'appairage en boucle, premier essai compris), `-LockyDemoSetup
permissions|firstTry|magic`, `-LockyDemoLockAnimation YES` (joue l'animation de verrouillage sans verrouiller), `-LockyDemoLockScreenPrompt YES` (ailes et bouton « Déverrouiller » sur le bureau), `-LockyDemoLockScreenProbe YES` (verrouille le Mac puis écrit dans `/tmp/locky-lockscreen.txt` ce que l'accessibilité voit de l'écran de verrouillage, pour caler les ailes sur une nouvelle version de macOS), `-LockyDemoRecordLockScreen YES` (filme l'écran
principal : animation de verrouillage, ailes sur le vrai écran de verrouillage, puis, après un clic sur leur bouton
« Déverrouiller », le cache affiché pendant que Locky tape le mot de passe ; déverrouiller alors avec Touch ID ou
l'Apple Watch. macOS coupe tout enregistrement vidéo de l'écran au verrouillage mais laisse prendre des captures :
le film est fait image par image (ScreenCaptureKit, environ 13 images/s, `screencapture` en secours), s'arrête 3 s
après le déverrouillage (120 s au plus), est rangé dans Films et montré dans le Finder. Cette démo ne démarre pas le
Bluetooth : signée avec l'équipe, elle partage l'appairage et ne doit pas disputer l'iPhone au Locky habituel.
Autorisations nécessaires : Enregistrement de l'écran et Accessibilité, demandées avant de verrouiller).

Côté Watch (DEBUG) : `-LockyDemo YES` (Mac appairé fictif, sans iPhone ni iCloud ; le bouton simule la
réponse du Mac), avec `-LockyDemoLocked YES`, `-LockyDemoOutOfReach YES` et `-LockyDemoMacName "…"`. Le Mac
(MacBook Pro 14", 2021, gris sidéral) vient du catalogue de l'app ; son fond d'écran est lu dans
`demo-wallpaper.jpg`, à déposer dans le dossier Documents de l'app Watch au simulateur.

### Premier essai guidé
Après l'appairage, le Mac affiche les autorisations puis « Essayer maintenant » ; l'iPhone suit les mêmes étapes
(message `setupProgress`) : éloignez-vous (jauge de distance en direct), le Mac se verrouille, revenez, Locky le
déverrouille, « La magie a opéré ! ». **Cet essai est obligatoire** : aucun bouton pour le passer ou le reporter,
la fenêtre du Mac ne se ferme pas avant sa réussite, et si l'une des apps est relancée entre‑temps, le Mac reprend
l'étape en cours (`isSetupCompleted` dans ses préférences ; les appairages antérieurs sont considérés comme faits).
Le menu du Mac n'a plus d'élément « Essayer Locky ». Les images de démo sont lues dans le dossier Documents de l'app
(`demo-wallpaper.jpg`, `demo-user.jpg`, `demo-phone.png`) ; le Mac vient du catalogue embarqué.

### iPhone Duo
- **Fermé** (écran externe, 466 × 678 pt) : l'interface iPhone telle quelle.
- **Tenu comme un livre** (écran interne en paysage, 951 × 669 pt, à plat ou à moitié ouvert) : deux pages de
  part et d'autre du pli, rien à cheval dessus. Accueil à gauche (le même écran que sur iPhone), tableau de bord
  du Mac à droite, un seul fond d'écran pour les deux et un trait fin sur le pli, au bord du tableau de bord.
  Réglages et rapports d'intrusion s'ouvrent sur la page de droite (boutons de la barre). Onboarding, appairage et
  premier essai : l'illustration sur la première page, le texte et les boutons sur la seconde.
- **Debout, à plat** (669 × 951 pt) : l'interface iPhone, le Mac en grand.
- **Debout, à moitié ouvert comme un portable** (pli horizontal) : accueil en haut, tableau de bord en bas, titre
  en ligne. La posture vient de la charnière (`onHingeChange`, iOS 27.1) ; sans elle, l'écran est traité à plat.
- **Tableau de bord** : cartes en verre façon widgets. Lecture en cours sur le Mac (pochette, progression,
  précédent / lecture / suivant, volume du Mac), processeur, mémoire (avec la pression), stockage, batterie du
  MacBook (ou état thermique sur un Mac de bureau), modèle, macOS et durée depuis le démarrage, puis Locky
  (verrouillage automatique, déverrouillages, rapports d'intrusion). Le Mac n'envoie ces données que pendant que
  la page est à l'écran (message `dashboard(isVisible:)`) : mesures toutes les 2 s, lecture en cours dès
  qu'elle change, pochette une seule fois par pochette. Barre de lecture et volume façon Now Playing d'iOS
  (sans curseur, la barre s'épaissit sous le doigt, blanc ou noir franc : sur le verre, les couleurs sémantiques
  prennent la teinte du fond) ; la barre de lecture déplace la lecture sur le Mac. Carte estompée quand rien ne
  joue. Mac hors de portée : un seul message centré qui explique pourquoi
  (Mac introuvable, Bluetooth éteint ou refusé, connexion en cours) et le bouton des rapports d'intrusion, qui
  passent par iCloud.
- **Hors de portée** (iPhone comme Duo) : le fond d'écran se désature, l'état du Mac, son image et son nom
  s'estompent ; la pastille de connexion et l'explication restent nettes.
- **Côté Mac** : API publiques sans autorisation (Mach, IOKit, CoreAudio) pour les mesures. Lecture en cours :
  MediaRemote (privé, via `dlsym`) d'abord, que les macOS récents ne donnent plus aux apps tierces ; sinon les
  notifications distribuées de Musique (`com.apple.Music.playerInfo`) et de Spotify
  (`com.spotify.client.PlaybackStateChanged`), écoutées dès le lancement de Locky : titre, artiste, album, durée,
  état, sans autorisation ni interrogation périodique (position estimée d'après les lectures et pauses pour
  Musique, fournie par Spotify). AppleScript sert aux pochettes (relues tant que le lecteur répond encore avec
  le morceau précédent ; Musique n'en a aucune pour un morceau en streaming absent de la bibliothèque, le Mac la
  cherche alors dans le catalogue Apple Music avec l'API publique de recherche iTunes, qui reçoit titre, artiste
  et album), à déplacer la lecture, à relire la position
  (après chaque commande et toutes les 10 s : Musique n'annonce ni un déplacement ni un retour au début du
  morceau) et à lire un lecteur qui jouait avant le lancement de Locky (macOS demande une fois l'autorisation de
  piloter le lecteur, jamais plus une fois refusée). Le Mac renvoie la lecture en cours dès qu'un lecteur annonce
  un changement ou qu'une pochette est prête. Les
  notifications Darwin ne servent à rien ici : sans contenu, et MediaRemote passe par XPC. Commandes : touches
  multimédia (tous les lecteurs, via l'autorisation Accessibilité déjà accordée). En DEBUG, `-LockyDemoDashboardLog YES` affiche dans la console ce que l'iPhone
  recevrait.
- iOS donne l'état de la charnière (`UIHingeInteraction`) mais pas la position du pli : elle est déduite de la
  fenêtre (milieu du grand côté de l'écran interne, dès que les deux côtés font au moins 600 pt), voir
  `Apps/iOS/Design/Fold`. La mise en page ne dépend donc pas de l'angle de la charnière.

## Organisation

```
Packages/LockyKit      Code partagé iOS / macOS / watchOS (testé)
  Bluetooth/           UUID et constantes BLE
  Protocol/            Messages, encodage, découpage en trames
  Crypto/              Appairage ECDH + code à 6 chiffres, canal chiffré anti-rejeu
  Proximity/           Filtre de Kalman RSSI, modèle de distance, décisions lock/unlock
  Motion/              Détection de mouvement de l'iPhone
  Sync/                CloudKit (remplace Parse)
  Shared/              App Group, widgets, commandes inter-processus, clés WatchConnectivity
Apps/iOS               App iPhone (transport BLE périphérique, session, écrans)
Apps/iOSWidgets        Widgets écran d'accueil / écran verrouillé + contrôles du Centre de contrôle
Apps/Shared            Intents (Siri, widgets, contrôles) et vues partagées
Apps/Watch             App Apple Watch
Apps/WatchWidgets      Complications
Apps/Mac               App Mac (transport BLE central, feintes bas niveau, overlay écran verrouillé)
Legacy/                Ancienne app, pour référence
```

## Comment ça marche

### Bluetooth
- L'iPhone est **périphérique** GATT, le Mac **central** (le Mac lit le RSSI de la connexion).
- En attente d'appairage, l'iPhone annonce un service générique ; une fois appairé, il annonce un service dont
  l'UUID est l'identifiant de l'appairage : le Mac ne se connecte qu'à *son* iPhone (l'ancienne app se connectait à
  tous les appareils Bluetooth du voisinage pour inspecter leurs services).
- Trames préfixées par leur longueur et découpées selon le MTU négocié (plus de marqueur texte `EOD`),
  contrôle de flux respecté des deux côtés, battement de cœur toutes les 2 s, chiens de garde à 8 s
  (désactivés pendant l'appairage), restauration d'état iOS, reconnexion en attente côté Mac + scan de secours
  (l'adresse Bluetooth de l'iPhone tourne régulièrement).
- **Compatibilité entre versions** : chaque côté annonce ce qu'il sait faire (`LockyFeature`, dans
  `DeviceStatus.features` et `MacStatus.features`, Bluetooth seulement) et n'envoie un message ajouté depuis
  qu'à un pair qui l'a annoncé. Un message authentique mais inconnu (pair plus récent) est ignoré sans relancer
  la session (`LockyProtocolError.unknownMessage`) ; avant Locky 1.0.2, il relançait la session à chaque fois.
  Depuis 1.0.2 : verrouillage automatique réglé depuis l'iPhone (`autoLock` dans les deux sens), animation de
  verrouillage (`lockAnimation`, `previewLockAnimation`) et mise à jour du Mac (`checkForUpdates`, version de
  Locky dans `MacStatus`).

### Sécurité
- Appairage : clés éphémères P‑256 avec **engagement** (le Mac s'engage sur sa clé avant de voir celle de
  l'iPhone, ce qui empêche un attaquant de forger un code identique) puis code à 6 chiffres à comparer.
- Chaque connexion dérive une clé de session (HKDF sur deux nonces frais) ; messages en ChaCha20‑Poly1305 avec
  compteur strictement croissant : un message enregistré ne peut pas être rejoué. Seuls les messages de
  poignée de main circulent en clair, tout le reste est refusé s'il n'est pas chiffré.
- Le mot de passe de session Mac est vérifié sur le Mac (OpenDirectory, plus de `sudo`), stocké **dans le
  trousseau de l'iPhone** (accessible après le premier déverrouillage, pour fonctionner iPhone en poche) et ne
  voyage que dans le canal chiffré.

### Distance
Filtre de Kalman 1D sur le RSSI (bruit de processus plus fort quand l'iPhone bouge, chutes de signal
fortement atténuées quand il est immobile), conversion en mètres par modèle de propagation calibré en **deux
points** : l'iPhone posé à plat à environ 1 m du Mac, puis à 2 m ; à chaque fois l'utilisateur valide sur l'iPhone
et le Mac mesure le signal pendant 6 s (médiane, messages `calibrationRequest` / `calibration`), pendant
l'appairage comme depuis les réglages de l'iPhone (« Calibrer la distance »). Le point à 1 m donne la référence, les
deux points la pente réelle de la pièce (exposant de propagation) ; une pente aberrante (mesure perturbée) est
remplacée par la valeur moyenne 2,2. La distance de verrouillage par défaut (1,5 m) tombe ainsi entre deux mesures
réelles. Pas de mesure collée au Mac : dans le champ proche, le signal varie de 10 dB d'une position à l'autre. Les
calibrages des premières versions, faits contre le Mac en un seul point, restent lus à 10 cm. Verrouillage au‑delà de la distance
choisie (curseur « cadenas », 1,5 m par défaut = ancien seuil ; les réglages enregistrés avant ce changement sont
divisés par deux une fois pour verrouiller au même endroit), déverrouillage avec hystérésis (70 % de la distance),
temps de maintien de 1,5 s. On ne verrouille que si l'iPhone bouge (accéléromètre + podomètre interrogé à chaque
réveil BLE) et que le Mac n'est pas utilisé ; distance doublée pendant un appel.
Perdre le lien Bluetooth ne verrouille jamais le Mac (app fermée, Bluetooth coupé…) : seule la distance mesurée
le fait.

### Widgets et Live Activity (iPhone)
- **Widgets** : petit (nom et état centrés au-dessus du bouton rond de l'app), moyen (le Mac et depuis quand il
  est dans son état, son nom complet, la connexion, la distance de verrouillage, le bouton avec son titre) et grand
  (tout centré : nom et connexion, le Mac et la distance de verrouillage, le bouton avec son titre ; l'état
  verrouillé/déverrouillé se lit sur l'écran du Mac et le bouton). Hors de portée, ils sont estompés et désaturés.
  La galerie de widgets montre le vrai Mac appairé (données d'exemple avant l'appairage). La distance en direct n'y
  figure pas : iOS limite les rafraîchissements des widgets à quelques dizaines par jour, elle est dans la Live
  Activity.
- **Live Activity** (réglage « Activité en direct », activée par défaut) : Dynamic Island compacte avec le logo de
  Locky à gauche ; à droite le cadenas (fermé rouge si le Mac est verrouillé, ouvert bleu sinon) et la distance dans
  la couleur de la jauge à cette distance (bleu près du Mac, rouge à la distance de verrouillage, estompée si le
  verrouillage auto est en pause) ; tout gris avec une antenne barrée hors de portée. Île déployée avec le Mac, son
  nom (sur deux lignes si besoin) et son état alignés en haut à gauche, le bouton titré, puis la jauge ; écran
  verrouillé avec le Mac (et son écran verrouillé imité), la jauge jusqu'au cadenas et le bouton titré. L'île
  déployée et l'écran verrouillé sont estompés hors de portée. La version des images du Mac fait partie de l'état : un nouveau fond d'écran redessine l'activité.
  iOS n'autorise le démarrage qu'au premier plan et l'arrête au bout de 8 h : elle repart à chaque ouverture de
  Locky ; en arrière‑plan (réveil Bluetooth), l'app reprend celle qui tourne et la met à jour (distance arrondie au
  décimètre, au plus toutes les 2 s).

### Mac : feintes bas niveau
| Besoin | Avant | Maintenant |
| --- | --- | --- |
| Verrouiller | `SACLockScreenImmediate` | idem, chargé par `dlsym` (repli ⌃⌘Q) |
| Taper le mot de passe | `osascript keystroke` (cassait selon le clavier) | `CGEvent` Unicode par paquets de 20, indépendant de la disposition |
| Accessibilité | écriture SQL dans TCC.db via sudo | autorisation système (`AXIsProcessTrustedWithOptions`) |
| Vérifier le mot de passe | `echo pwd \| sudo -S ls` | OpenDirectory `verifyPassword` |
| Fenêtre par‑dessus l'écran verrouillé | `CGShieldingWindowLevel()+1` (ne marche plus) | espace SkyLight au niveau absolu des notifications d'écran verrouillé : ailes Locky autour de la photo de l'utilisateur (repérée par l'API d'accessibilité sur `loginwindow`, sinon Locky affiche la sienne) et bouton « Déverrouiller » dessous, qui fait exactement ce que fait le bouton de l'iPhone |
| Réveil au retour (sans déverrouillage automatique) | `IOPMAssertionDeclareUserActivity` + quitter l'économiseur par AppleScript | même assertion + déplacement de souris sur place (sort de l'économiseur, sans autorisation supplémentaire) |
| Activer le Bluetooth | `IOBluetoothPreferenceSetControllerPowerState` | idem, via `dlsym` |
| Lancement à l'ouverture de session | app helper | `SMAppService.mainApp` |
| Animation de verrouillage | capture de l'écran (`CGDisplayCreateImage`, abandonnée) puis cadenas | cinq choix (menu Options > Personnaliser l'animation…, ou réglages de l'iPhone) : **Iris** (le bureau se fond dans le fond d'écran, sans autorisation « Enregistrement de l'écran », un iris se referme sur l'anneau du logo, les ailes se déplient, le cadenas avale la dernière bulle), **Halo** (le fond d'écran se fond dans l'arrière-plan, le logo naît d'une lueur), **Envol** (le logo arrive en volant comme un oiseau et se pose, redécolle au déverrouillage), **Rideau** (deux panneaux se rejoignent derrière le logo), **Aucune** (verrouillage immédiat, les ailes restent sur l'écran de verrouillage). Texte (« Locky » par défaut) révélé, tapé, rapproché ou en reflet ; arrière-plan couleur, fond d'écran flouté ou image choisie sur le Mac. Les animations et leur aperçu en boucle (`LockAnimationPreview`) sont dans LockyKit : l'iPhone montre le même sur le fond d'écran du Mac |
| Activité de l'utilisateur | moniteurs d'événements globaux | `CGEventSource.secondsSinceLastEventType` (sans autorisation) |
| Image du Mac | illustrations maison, pas à jour | icône exacte du modèle fournie par macOS + fond d'écran incrusté dans l'écran (vérifié sur 26 modèles : tous les MacBook jusqu'à 2026, iMac 24" et Intel, iMac Pro ; mini/Studio/Pro n'ont pas d'écran) |

Les symboles privés sont tous chargés dynamiquement : s'ils disparaissent un jour, la fonction concernée se
désactive au lieu d'empêcher l'app de démarrer.

### iCloud (remplace Parse)
Base privée CloudKit, zone `Locky` : enregistrements `MacStatus` (nom, modèle, utilisateur, état de verrouillage,
autorisation de la caméra `cameraAccess` et images avec leur version `imagesVersion`), `NowPlaying` (pochette du morceau en cours, 216 px, une seule par
Mac, remplacée quand elle change, effacée quand Locky quitte et à son lancement s'il a été tué ; Locky 1.0.0 pour
Mac y mettait aussi le morceau) et `Intrusion` (photos
d'intrus). L'iPhone s'abonne : notification visible pour une intrusion,
silencieuse pour l'état du Mac. Tout se lit par identifiant ou par changements de zone : aucun index à configurer.

**Fond d'écran rangé dans un dossier protégé.** macOS fait pointer le fond d'écran vers le fichier choisi, sans copie
lisible. S'il est dans Documents, Bureau, Téléchargements, iCloud Drive ou sur un autre disque, le lire déclenche la
demande d'accès de macOS à ce dossier. Locky ne le lit donc pas (ni même ses attributs) avant de l'avoir expliqué :
ligne « Fond d'écran » (facultative) de l'étape Autorisations, et entrée « Afficher mon fond d'écran sur mon iPhone… »
du menu tant que l'accès manque. Après un refus, le bouton ouvre Réglages Système › Fichiers et dossiers ; l'accès est
suivi toutes les 2 s. Sans accès, l'iPhone et les animations prennent le fond bleu Locky.

**Détection des intrus et caméra du Mac.** Le réglage se règle sur l'iPhone et part vers le Mac (tout de suite, ou à
la prochaine connexion). À l'activation, le Mac vérifie la caméra : autorisée, il confirme par une notification ;
jamais demandée, macOS pose la question, mais seulement sur un Mac déverrouillé (verrouillé, elle attend le
prochain déverrouillage) ; refusée, une notification l'explique et ouvre Réglages Système › Confidentialité ›
Caméra au clic, seul endroit où un refus se défait ; pas de caméra, les tentatives sont signalées sans photo. Le Mac
publie l'autorisation dans son statut (Bluetooth et iCloud) : tant qu'elle manque, l'iPhone affiche un avertissement
sous « Détection des intrus » et dans les rapports d'intrusion, avec « Autoriser sur mon Mac » (message
`cameraAccessRequest` : le Mac redemande ou ouvre le bon réglage, puis suit le changement quelques minutes, macOS
n'envoyant aucun événement). Le menu du Mac propose aussi « Autoriser la caméra pour photographier les intrus… ».
Les images ne sont téléchargées que si leur version a changé, et le Mac ne les renvoie que dans ce cas. Sans
entitlement iCloud (build non signé), l'app fonctionne sans synchronisation.

Les images du Mac (fond d'écran, photo de l'utilisateur, image de l'iPhone) ne passent que par iCloud, comme avec Parse : le Mac les envoie, puis prévient l'iPhone en Bluetooth (message
`macImagesUpdated`, quelques octets) pour qu'il les télécharge aussitôt, même en arrière‑plan ; la notification
silencieuse prend le relais quand l'iPhone n'est pas à portée. Le Bluetooth ne transporte jamais d'images : un
transfert l'occuperait plusieurs secondes et ferait tomber le lien. Elles sont en JPEG (fond d'écran 1 024 px,
photo 256 px) et en PNG (iPhone, 200 px, transparent), à la taille utile. L'image du Mac, elle, ne voyage pas : comme
dans l'ancienne version, l'iPhone et la Watch embarquent tous les Mac Apple silicon (voir « Catalogue des Mac ») et
posent eux‑mêmes le fond d'écran dans l'écran. Le Mac publie seulement son type exact (`deviceType`, modèle et
couleur, déduit de l'icône que macOS lui donne) ; à défaut, le modèle (`hw.model`) donne la couleur par défaut.
L'iPhone prépare ensuite pour les widgets et la Live Activity de petites copies en PNG/JPEG dans l'App Group (Mac
avec son fond à 690 et 280 px, fonds réduits, photo) : les extensions n'embarquent pas le catalogue, et iOS refuse
d'afficher une Live Activity dont les images dépassent leur place. Puis il recharge ses widgets. Le morceau en cours (tableau de bord de l'iPhone Duo) passe en Bluetooth (message
`nowPlaying`, quelques centaines d'octets : titre, artiste, lecture, position), comme les mesures du Mac ; seule
sa pochette suit le chemin des images : le Mac la dépose dans iCloud, puis la nomme dans le message, et l'iPhone
ne la télécharge que si elle a changé (l'iPhone comprend encore `nowPlayingChanged` de Locky 1.0.0 pour Mac).

L'**Apple Watch est autonome** : elle lit elle‑même le Mac dans iCloud (à l'ouverture, sur la notification
silencieuse, en actualisation d'arrière‑plan toutes les 30 min environ, et dès que l'iPhone lui signale une nouvelle
version d'images). Seuls l'état en direct de la connexion et les commandes de verrouillage passent par l'iPhone.

Le Mac voit un
changement de fond d'écran dans la seconde en surveillant
`~/Library/Application Support/com.apple.wallpaper/Store/Index.plist`, comme l'ancienne version (vérification toutes
les 30 s si ce fichier n'existe pas).

### Catalogue des Mac
`Tools/MacCatalog/generate.sh` regénère, depuis les types de CoreTypes du macOS qui l'exécute, les images des Mac
Apple silicon (écran rendu transparent, 1 024 px pour l'iPhone dans `Apps/iOS/Resources/MacCatalog.xcassets`,
384 px pour la Watch dans `Apps/Watch/Resources/MacCatalog.xcassets`) et la table type/modèle → image de LockyKit
(`MacCatalog+Data.swift`, à ne pas modifier à la main). Les couleurs identiques partagent une image : 131 types,
43 images. À relancer sur le dernier macOS quand Apple sort de nouveaux Mac ; un Mac inconnu s'affiche avec le
symbole de sa famille.

## À configurer avant une release

- **Portail développeur** : conteneur `iCloud.studio.lunabee.locky`, App Group `group.studio.lunabee.locky`,
  notifications « Time Sensitive », sur les App IDs `studio.lunabee.locky`, `.widgets`, `.watchkitapp`,
  `.watchkitapp.widgets` et `studio.lunabee.locky.mac` (Xcode le fait en signature automatique) ; côté Mac, App Group
  `VH79XGK7M2.studio.lunabee.locky.mac` pour `studio.lunabee.locky.mac` et `studio.lunabee.locky.mac.widgets`.
- **Apple Watch** : capacités iCloud (CloudKit, conteneur `iCloud.studio.lunabee.locky`) et Push Notifications sur
  l'App ID `.watchkitapp` (déclarées dans `LockyWatch.entitlements`, à vérifier dans Signing & Capabilities).
- **CloudKit** : déployer le schéma de développement en production depuis la console CloudKit (types `MacStatus`,
  `NowPlaying`, `Intrusion` ; le champ `cameraAccess` de `MacStatus` apparaît quand un Mac l'a publié une fois).
- **Mac** : distribué hors Mac App Store (pas de sandbox : impossible avec la saisie du mot de passe et les API
  privées), signé Developer ID et notarisé ; voir « Publier une version Mac ». Tant que `SUPublicEDKey` est vide,
  l'élément « Rechercher les mises à jour » est masqué.
- **Liens** : l'iPhone envoie `https://locky.lunabee.studio/locky-mac-install.dmg` ; `https://locky.lunabee.studio/ios`
  (QR code sur le Mac) est encore un placeholder.

## Publier une version Mac

Le site `https://locky.lunabee.studio` sert :
- `locky-mac-install.dmg` : le téléchargement pour les nouveaux utilisateurs, toujours la dernière version ;
- `mac/appcast.xml` : le flux Sparkle (`SUFeedURL`), que l'app consulte une fois par jour ;
- `mac/Locky-<version>.dmg` : les mises à jour que Sparkle télécharge, et leurs deltas.

**Une fois pour toutes**, sur le Mac qui publie :
1. Certificat **Developer ID Application** de LUNABEE STUDIO (`VH79XGK7M2`) dans le trousseau. Seul le titulaire du
   compte peut le créer (ou donner l'accès aux certificats gérés dans le cloud). C'est l'équipe de l'iPhone :
   iCloud et l'App Group ne se partagent pas entre équipes. Le certificat Developer ID Installer ne sert pas
   (il signe les `.pkg`).
2. Profil de provisionnement **Developer ID** nommé exactement `Locky Mac Developer ID` (iCloud l'exige), créé sur
   developer.apple.com (Profiles › + › Developer ID, App ID `studio.lunabee.locky.mac`, certificat Developer ID
   de LUNABEE STUDIO) puis installé d'un double‑clic. Il est référencé par `Tools/Release/ExportOptions.plist`.
3. Profil de notarisation : `xcrun notarytool store-credentials Locky --apple-id <Apple ID> --team-id VH79XGK7M2`
   (mot de passe d'app créé sur appleid.apple.com, ou clé d'API App Store Connect).
4. Clé Sparkle : `build/packages/artifacts/sparkle/Sparkle/bin/generate_keys` (après une première publication, ou
   le même outil sous `DerivedData/…/SourcePackages`). La clé privée reste dans le trousseau ; **la sauvegarder**
   (`generate_keys -x fichier`) : sans elle, plus aucune mise à jour ne pourra être signée pour les Mac déjà
   installés. La clé publique affichée va dans `SUPublicEDKey` (`Apps/Mac/Info.plist`).

**À chaque version** :
1. Monter `MARKETING_VERSION` et `CURRENT_PROJECT_VERSION` de la cible LockyMac (Sparkle compare le second).
2. Notes de version (facultatives), **en français** et en Markdown, dans `Tools/Release/ReleaseNotes/<version>.md` :
   Sparkle les affiche dans sa fenêtre de mise à jour, quelle que soit la langue du Mac. Elles alimentent aussi
   l'historique des notes de version (menu « Notes de version… » du Mac, réglages et À propos de l'iPhone), lu
   dans le flux par `MacReleaseFeed` : un titre `#`, puis une ligne `- ` par nouveauté. L'iPhone compare la
   dernière version du flux à celle du Mac pour proposer la mise à jour, qu'il ouvre sur le Mac.
3. `Tools/Release/release_mac.sh` : archive, signature Developer ID, notarisation de l'app puis du DMG, flux
   Sparkle signé. Le résultat est dans `build/site/`.
4. Envoyer `build/site/locky-mac-install.dmg` et `build/site/mac/` (sans `old_updates`) à la racine du site.

`build/site/mac` est le miroir du dossier `mac` du site : le garder entre deux versions (les deltas se calculent à
partir des versions qu'il contient ; sans lui, le script reprend l'`appcast.xml` en ligne). Le DMG est fabriqué
par `Tools/Release/make_dmg.sh` (fond et icône de volume dans `Tools/Release/DMG`, redessinés par
`make_assets.sh`) ; Finder met la fenêtre en page, d'où une demande d'autorisation d'automatisation au premier
lancement. Un build Developer ID utilise l'environnement **Production** de CloudKit : déployer le schéma avant, et
le tester avec un iPhone en TestFlight (une app iPhone lancée depuis Xcode est en Development et ne voit pas ses
données).

## À valider sur du vrai matériel

Le simulateur ne fait pas de Bluetooth et le verrouillage de session ne peut pas être automatisé :

1. Appairage complet (code, mot de passe, calibrage), puis reconnexion après redémarrage de l'iPhone et du Mac.
2. Verrouillage en s'éloignant iPhone en poche, app iPhone en arrière-plan et iPhone verrouillé.
3. Déverrouillage automatique au retour, puis manuel via « Déverrouiller avec Locky » **affiché par-dessus l'écran
   de verrouillage** (niveau d'espace SkyLight `400`, à ajuster si besoin dans `LockScreenSpace.swift`).
4. Saisie du mot de passe avec une disposition AZERTY et des caractères spéciaux.
5. Widgets, Live Activity, contrôle du Centre de contrôle, Siri (« Verrouille mon Mac avec Locky ») et Apple Watch
   (images et état reçus d'iCloud sans l'iPhone).
6. Photo d'intrus et notification sur l'iPhone (iCloud identique sur les deux appareils).
7. iPhone Duo plié / déplié.

## Ancien code et secrets

`Legacy/` (et l'historique git) contiennent des clés de services de l'époque : Parse, Mandrill (`cloudClode.js`),
HockeyApp. Ces services sont fermés ou à révoquer : vérifiez qu'aucune de ces clés n'est encore valide.
