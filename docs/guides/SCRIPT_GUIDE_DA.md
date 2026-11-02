# Scriptguide (dansk)

Beskrivelse i almindeligt sprog af hver GDScript-fil. Identifikatorer og stier er uændrede. Hold denne fil og `SCRIPT_GUIDE_EN.md` i takt; `python3 tools/check_script_guides.py` melder huller.

## Kernetjenester (autoloads)

| Script | Afhænger af | Hvad det gør |
|---|---|---|
| `src/core/session_log.gd` | — | Autoload `SessionLog`. Den sorte boks: skriver korte strukturerede poster (kategori, hændelse, data) til hukommelsen og til en logfil i JSON-linjer, med størrelsesgrænser og begrænsning af gentagelser. Observerer kun. |
| `src/core/settings_service.gd` | SessionLog, Paths, Localization | Autoload `Settings`. Personlige præferencer på denne computer: lydstyrker, vindue/fuld skærm, UI-skalering, kamerazoom, sprog, tastetildeling og det private identitetstoken pr. spillernavn. Aldrig en del af den fælles verden. |
| `src/core/asset_resolver.gd` | AssetCatalog, SessionLog | Autoload `Assets`. Gør et asset-ID til en tekstur eller lyd: leder efter skaberens eksterne udskiftning, derefter den medfølgende, derefter skabelonen og til sidst en synlig nødløsning. Validerer filer, cacher resultater og tilpasser billeder til deres visningsboks. |
| `src/core/audio_service.gd` | Assets, Settings | Autoload `Audio`. Afspiller lyde efter ID gennem fem busser: genbrugte engangslyde (evt. placeret i verden) og navngivne løkker med fade, som ikke genstarter, hvis de allerede spiller. |
| `src/core/game_session.gd` | Net, Saves, Settings, WorldActions, Simulation, SaveCodec | Autoload `Session`. Hjertet i et kørende spil: starter enspiller / vært / deltagelse, holder verdenen, registrerer spillere, kører det fælles ur og indeholder alle netværksbeskeder. Værten validerer anmodninger; klienter spørger kun. |
| `src/net/net_service.gd` | SessionLog | Autoload `Net`. Åbner og lukker ENet-forbindelsen (vært eller klient) og rapporterer dens status. Ved intet om spilverdenen. |
| `src/persistence/save_service.gd` | SafeFile, SaveCodec, Paths | Autoload `Saves`. Gemmer og indlæser verdensfiler i én mappe pr. verden med den sikre skriverutine og falder tilbage på sikkerhedskopien, hvis hovedfilen er beskadiget. |

## Kernehjælpere

| Script | Afhænger af | Hvad det gør |
|---|---|---|
| `src/core/build_info.gd` | SaveCodec | Spiltitel, version, iteration, fase og protokolnummer; læser commit-id fra `.git`, hvis den findes. Bruges af etiketten nederst til højre, logs og gemte spil. |
| `src/core/paths.gd` | — | Læser kommandolinjeargumenter `--key=value` og giver hver `--instance` sin egen brugermappe til indstillinger, logs og gemte spil. |
| `src/core/safe_file.gd` | — | Beskyttet JSON-skrivning: midlertidig fil, kontrol ved genlæsning, sikkerhedskopi af den forrige fil, derefter udskiftning. Også sikker JSON-læsning. |
| `src/core/localization.gd` | SafeFile | Indlæser `locale/strings.json` (engelsk/dansk) i Godots oversættelsessystem. |
| `src/core/asset_catalog.gd` | SafeFile | Læser asset-manifesterne og udregner hver assets stier til skabelon, medfølgende og ekstern udskiftning. Rene data, kan bruges af editorværktøjer. |

## Verdensdata og regler

| Script | Afhænger af | Hvad det gør |
|---|---|---|
| `src/content/content.gd` | SafeFile | Læser forfattede områdefiler (`content/regions/*.json`): entiteter, positioner, rækkevidde, starttilstand, startpunkter; beregner et indholdsfingeraftryk, så vært og klient kan bekræfte, at de matcher. |
| `src/state/world_state.gd` | Content, RegionState, PlayerState, Simulation | Hele den fælles verden som rene data: id, seed, urtik, områder, spillere. Giver også seedede tilfældighedsstrømme. |
| `src/state/region_state.gd` | Content | Spillerskabte ændringer i ét område, kun gemt hvor de afviger fra det forfattede indhold, med et revisionsnummer pr. genstand. |
| `src/state/player_state.gd` | Content | Én spillers gemte data: identitet, navn, område, position, retning. |
| `src/sim/simulation.gd` | WorldState | Det ene fælles ur (10 tik pr. sekund). Fremtidige tidsstyrede systemer kobles på her. |
| `src/sim/world_actions.gd` | WorldState, Content | Værtens regler: kontrollerer en interaktionsanmodning (hvem, hvor, hvor langt, hvilken revision) og udfører den; kontrollerer at rapporteret bevægelse er fysisk mulig. |
| `src/persistence/save_codec.gd` | WorldState, Content, BuildInfo | Konverterer verdenen til/fra gemmeformatet, validerer, udfylder sikre standardværdier, fjerner slettet indhold med advarsler og kører migreringer for gamle skemaversioner. |

## Præsentation — app og brugerflade

| Script | Afhænger af | Hvad det gør |
|---|---|---|
| `src/presentation/app/main.gd` | Session, all UI panels, RegionView | App-skal: skifter mellem menu og områdevisning, fordeler taster (menu, gem, F3, F12), kan genopbygge visningen fra verdensdata, tager skærmbilleder. Har ingen spiltilstand. |
| `src/presentation/ui/ui_theme.gd` | — | Det ene fælles brugerflade-tema (palet fra den visuelle retning) og små teksthjælpere. |
| `src/presentation/ui/ui_root.gd` | Settings, UITheme | Rod for alle paneler: anvender temaet og UI-skaleringen og fylder altid vinduet uanset billedformat. |
| `src/presentation/ui/main_menu.gd` | Session, Saves, Settings | Startmenu: Enspiller, Vært, Deltag, Indstillinger, Afslut; fortsæt/ny verden; adresse og port; viser fejl i klart sprog. |
| `src/presentation/ui/settings_panel.gd` | Settings, Assets | Indstillingsvindue: lydstyrker, skærm, UI-skalering, sprog, omdefinering af taster, udskiftningsmappe og genindlæsning. Gemmer straks; sætter aldrig verden på pause. |
| `src/presentation/ui/hud.gd` | Session, InteractionSensor | Overlay i spillet: statuslinje, interaktionsprompt, korte beskeder. |
| `src/presentation/ui/pause_menu.gd` | Session | Esc-menu: fortsæt, gem (vært), indstillinger, forlad. Den fælles verden kører videre. |
| `src/presentation/ui/dev_overlay.gd` | Session, Net, Assets, Audio, SessionLog | F3-udviklerpanel: build, netværks- og verdenstilstand, spillere, entitetstilstande, gemmestatus, udskiftninger, logsti og nogle få værtskontrollerede kommandoer. |

## Præsentation — verden

| Script | Afhænger af | Hvad det gør |
|---|---|---|
| `src/presentation/world/region_view.gd` | Session, Content, PlayerAvatar, Audio | Viser ét område for den lokale spiller: opretter/fjerner avatarer for spillere i området, starter områdets baggrundslyd. Kan frit fjernes og genopbygges. |
| `src/presentation/world/player_avatar.gd` | Session, Assets, Settings, InteractionSensor | En spillers figur. Lokal: læser input, bevæger sig med kollision, sender positioner, ejer kamera og zoom. Fjern: glider mod værtens positioner. Gangbevægelse og spejling er kun visuelle. |
| `src/presentation/world/door_view.gd` | Session, Content, Assets, Audio, Interactable | Viser en dør/låge-entitet fra verdensdata: billede for åben/lukket, blokering når lukket, prompttekst og lyd, når værten melder en ændring. |
| `src/presentation/world/interactable.gd` | Content, Session, Settings | Et fokuserbart interaktionspunkt med rækkevidde og prioritet fra indholdet; aktivering sender kun en anmodning til værten. |
| `src/presentation/world/interaction_sensor.gd` | Interactable, PlayerAvatar | På den lokale avatar: vælger det ene bedste mål (prioritet, derefter nærmeste) og aktiverer det på interaktionstasten. |
| `src/presentation/world/placeholder_block.gd` | — | Fase A-geometrisk pladsholder: et farvet rektangel med tilsvarende kollision (synlig i editoren). |
| `src/presentation/world/placeholder_ground.gd` | — | Fase A-pladsholderjord med et 100 px gitter. |

## Udvikling og test

| Script | Afhænger af | Hvad det gør |
|---|---|---|
| `src/dev/content_check.gd` | Content, AssetCatalog, Localization | Kontrol af indholdets integritet (PASS/WARN/FAIL): områder, områdescener, manifester, asset-ID'er brugt i koden, oversættelser. Ændrer aldrig noget. |
| `src/dev/autotest_driver.gd` | Session, Saves, Assets, Audio | Fjernbetjening kun til test (kun med `--autotest`): læser kommandoer fra en fil og skriver tilstandsrapporter, så `tools/mp_test.py` kan styre rigtige, separate spilprocesser. |
| `tests/test_case.gd` | — | Lille basisklasse til enhedstests (`check`, `eq`). |
| `tests/test_runner.gd` | TestCase, ContentCheck | Kører alle testfiler i tests/unit og indholdskontrollen, skriver resultater og afslutter med fejlkode ved fejl. |
| `tests/unit/test_world.gd` | WorldState, WorldActions, Simulation | Tester oprettelse af verden, lagring af ændringer, seedet tilfældighed, uret, validering af interaktioner, samtidige anmodninger, bevægelsesplausibilitet. |
| `tests/unit/test_save.gd` | SaveCodec, SafeFile, Saves | Tester gem/indlæs-rundtur, validering, standardværdier, slettet indhold, den historiske v1-fixture, migreringer, sikre skrivninger og fallback til sikkerhedskopi. |
| `tests/unit/test_assets.gd` | AssetCatalog, AssetResolver | Tester navngivning af udskiftninger, prioritet, afvisning af beskadigede/for store filer, nødløsning, lydudskiftning og tilpasning til visningsboksen. |
