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
| `src/state/npc_state.gd` | — | Én overlevende som rene data: identitet, navn, sted, rekrutteringstilstand, helbred, job, aktivitet, status og bosættelse. Alt gemmes. |
| `src/state/zombie_state.gd` | — | Én zombie som rene data: identitet, område, position, helbred, AI-tilstand og korttidshukommelse. Kun grundbestandens identitet/position/helbred gemmes. |
| `src/state/threat_state.gd` | — | Verdens støjkø og opmærksomhed pr. grov zone (midlertidig: gemmes aldrig, så en genindlæst verden starter rolig). |
| `src/state/world_state.gd` | Content, RegionState, PlayerState, Simulation | Hele den fælles verden som rene data: id, seed, urtik, områder, spillere. Giver også seedede tilfældighedsstrømme. |
| `src/state/region_state.gd` | Content | Spillerskabte ændringer i ét område, kun gemt hvor de afviger fra det forfattede indhold, med et revisionsnummer pr. genstand. |
| `src/state/bunker_state.gd` | — | Ét tilflugtsrum som rene data: indgangens identitet, niveauer efter dybde med fortegn (intet maksimum) og det fælles lager. Danner og fortolker niveauernes område-id'er. |
| `src/state/player_state.gd` | Content | Én spillers gemte data: identitet, navn, område, position, retning. |
| `src/sim/nav_grid.gd` | Content, Prop, FenceLine | Værtens gangbarhedsgitter bygget fra områdescenens forfattede kollisionsdata plus levende træer/låger; A*-ruter og sigtelinjer for zombier og angreb. |
| `src/sim/zombie_sim.gd` | NavGrid, ThreatState, WorldState | Kun værten: zombiesimulation — hørelse, opmærksomhed der stiger/aftager, forstærkninger fra kortkanter inden for lofter, AI-tilstandsmaskinen, bevægelse, angreb, lig og opfyldning af bestanden. |
| `src/sim/survival_sim.gd` | WorldActions | Kun værten: spillerens livstegn — langsom genopretning af helbred og den milde genoplivningsregel (behold alt, vågn i stuehuset). |
| `src/content/items.gd` | SafeFile | Genstandskatalog (`content/items.json`): faste genstands-id'er, navnenøgler, bæreplads og `move()`, der flytter mellem to beholdninger i ét trin, så intet dubleres. |
| `src/sim/infra_sim.gd` | Simulation, WorldActions, ZombieSim, Content | Kun værten: infrastruktur på det fælles ur: generatorens brændstofforbrug og automatiske stop, logisk strøm i bunkeren (`is_powered`), vandrenserens omdannelse over tid med strøm, væskebalancens fald og mild dehydrering. |
| `src/sim/inventory.gd` | Items, WorldState | Lagertransaktioner: bæreplads, hvilke beholdninger der betaler (din taske, så tilflugtsrummets lager under jorden), betaling, udstyrsposter, at give ting (overskud lægges i en bunke på jorden), overførsler til beholdere. |
| `src/sim/build.gd` | Content, Terrain, Inv, NavGrid, ZombieSim | Byggeregler: definitioner, fodaftryk, placeringskontrol (zoner, åbent bunkergulv, optaget plads, frihold, aldrig afskære et bunkerområde), opførelse, opgradering, reparation, nedtagning, bunker og kasser, skade på konstruktioner, hvad zombier bryder igennem. |
| `src/sim/farm_sim.gd` | Build, InfraSim, EnvSim, Inv | Produktion fra byggede ting på det fælles ur: regnvandsopsamleren (hurtigere i regn) og det hydroponiske plantebed (kræver rent vand og strøm). Handlinger til at tømme, vande og høste. |
| `src/sim/env_sim.gd` | WorldState | Døgn og vejr fra det fælles ur: tid på døgnet, dagslys, seedede perioder med regn/klart vejr og virkningen på zombiers syn og hørelse. |
| `src/sim/terrain.gd` | Content, RegionState | Udgravningsregler for et områdes gitter af jordceller: åbne/faste celler, permanente celler, støtteregel (sikker margen + forstærkede støtters radius), begrundelser ved afvisning. |
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
| `src/presentation/ui/map_panel.gd` | Session, Assets, Hud | Verdenskort (M): veje, områder og kendemærker fra indholdet; træer, tilflugtsrum og spillere fra den aktuelle tilstand; dybde under jorden. |
| `src/presentation/ui/hud.gd` | Session, InteractionSensor | Overlay i spillet: statuslinje, interaktionsprompt, korte beskeder. |
| `src/presentation/ui/machine_panel.gd` | UITheme, Session | Lille panel i verden for én maskine (lager, generator, vandrenser): titel, statuslinjer og knapper bygget af maskinvisningen; opdateres fra verdensdata og lukker uden for rækkevidde eller med Esc. Knapper sender kun anmodninger til værten. |
| `src/presentation/ui/build_mode.gd` | Build, Inv, Session | Byggemenuen (B) og placeringsvisningen: grønt/rødt spøgelse, der følger musen efter samme regler som værten, begrundelse ved afvisning, og placering. |
| `src/presentation/ui/craft_panel.gd` | Craft, Session, MachinePanel | Arbejdsbænkspanelet: opskrifter med materialer og tid, fremstillingsjob, afhentning og reparation af slidt udstyr. |
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
| `src/presentation/world/prop.gd` | Assets, AssetCatalog | En stående genstand i verden: viser grafik efter asset-ID, tilføjer et kollisionsfodaftryk uafhængigt af grafikken, toner ud når den lokale spiller står bag den, valgfri svajen i vinden. Viser skabelongrafik i editoren. |
| `src/presentation/world/fence_line.gd` | Prop, AssetCatalog | Et lige hegn mellem to punkter: passer et helt antal segmenter ind og tilføjer én kollisionsstrimmel. |
| `src/presentation/world/ground_patch.gd` | Assets, AssetCatalog | En jordflade-polygon (græs, jord, vej) fyldt med en gentagende tekstur; formen redigeres i editoren. |
| `src/presentation/world/scatter.gd` | Prop | Seedet dekorativ beplantning (græs, blomster) i et område uden for angivne rektangler — ens for alle spillere. |
| `src/presentation/world/atmosphere.gd` | Assets | Stemningslag: varm farvetone, drivende frøfnug, papirstruktur og vignet. Kun præsentation. |
| `src/presentation/world/entity_view.gd` | Session, Content, Assets, Interactable | Basis for visninger af genstande: position og rækkevidde fra indholdet, tilstand fra verden, grafik fra asset-id'er, én Interactable; underklasser opdaterer ved ændringer. |
| `src/presentation/world/portal_view.gd` | EntityView | Døråbninger og stiger mellem områder; skjult/ubrugelig når deaktiveret eller når den krævede lem/dør er lukket. |
| `src/presentation/world/shelter_site_view.gd` | EntityView, ProgressMarker, Audio | Stedet til et tilflugtsrum i en bygning: markeret → graves (statuslinje) → trælem der kan åbnes og lukkes. |
| `src/presentation/world/stockpile_view.gd` | EntityView | Den fælles tømmerbunke; grafikken vokser med lageret; prompten viser hvad du bærer. |
| `src/presentation/world/tree_view.gd` | EntityView, Prop | Træ der kan fældes: hug-feedback (rysten, spåner, lyd), faldanimation, stub; stammekollision kun mens træet står. |
| `src/presentation/world/support_view.gd` | EntityView, ProgressMarker | Forstærkningssted: uforstærket jord → bygges → tømmerramme; prompten viser pris og lager. |
| `src/presentation/world/progress_marker.gd` | — | Lille blæktegnet statuslinje over noget der bygges. |
| `src/presentation/world/light_factory.gd` | — | Danner den bløde radiale tekstur til 2D-lys og bygger lanternelys. |
| `src/presentation/world/light_spot.gd` | LightFactory | Et scenelys (lanterne, vindue, lysskakt) med den fælles radiale tekstur. |
| `src/presentation/world/zombie_view.gd` | Session, Assets, Audio | Viser én zombie ud fra verdensdata: interpolation, slæben, ?/!-tegn, rød optaktsstilling, slagblink, helbredsbjælke, fald ved død, lokale støn. |
| `src/presentation/world/weapon_rack_view.gd` | EntityView | Køllestativet i stuehuset; at tage en kølle udruster spilleren (én hver, løber aldrig tør). |
| `src/presentation/world/machine_view.gd` | EntityView, MachinePanel, InfraSim, Items, Audio | Lagerskab, generator, vandrenser og ransagningssteder på overfladen: grafik for tændt/slukket/tom, maskinpanelets indhold, direkte ransagning af fundsteder, generatorens brummen mens den kører. |
| `src/presentation/world/lamp_view.gd` | EntityView, InfraSim, LightSpot | Elektrisk bunkerlampe: tændt med lys, mens bunkeren har strøm, ellers mørk. Læser kun den logiske strømtilstand. |
| `src/presentation/world/structure_view.gd` | Session, Build, Assets, MachinePanel | Viser én bygget ting eller bunke på jorden: grafik efter tilstand, kollision mens den spærrer, tilstands-/fremskridtsbjælke, træffeffekt; panelet med reparation, opgradering, nedtagning og beholder-/produktionshandlinger. |
| `src/presentation/world/terrain_view.gd` | Terrain, Session, Assets | Tegner udgravet gulv, fast jord, 3/4-vægflader og blækkanter ud fra gitteret; genopbygger kollision ved ændringer; placerer støttestolper; den kontekstuelle grav/støtte-prompt med farvet målramme. |
| `src/presentation/world/placeholder_block.gd` | — | Gråboks-hjælper (brugt i fase A, beholdt til skitsering af nye områder): et farvet rektangel med tilsvarende kollision. |
| `src/presentation/world/placeholder_ground.gd` | — | Gråboks-jord med et 100 px gitter (ikke brugt i den nuværende scene). |

## Udvikling og test

| Script | Afhænger af | Hvad det gør |
|---|---|---|
| `src/dev/content_check.gd` | Content, AssetCatalog, Localization | Kontrol af indholdets integritet (PASS/WARN/FAIL): områder, områdescener, manifester, asset-ID'er brugt i koden, oversættelser. Ændrer aldrig noget. |
| `src/dev/autotest_driver.gd` | Session, Saves, Assets, Audio | Fjernbetjening kun til test (kun med `--autotest`): læser kommandoer fra en fil og skriver tilstandsrapporter, så `tools/mp_test.py` kan styre rigtige, separate spilprocesser. |
| `tests/test_case.gd` | — | Lille basisklasse til enhedstests (`check`, `eq`). |
| `tests/test_runner.gd` | TestCase, ContentCheck | Kører alle testfiler i tests/unit og indholdskontrollen, skriver resultater og afslutter med fejlkode ved fejl. |
| `tests/unit/test_threat.gd` | ZombieSim, WorldActions, NavGrid | Tester navigation, syn, hørelse, opmærksomhed op/ned, eskaleringslofter, nærkampsautoritet, vægge, skade efter optakt, genoplivning, stuehusets grænse og gemmepolitikken. |
| `tests/unit/test_infra.gd` | Items, InfraSim, WorldActions, SaveCodec | Tester genstandsflytning, kapløb om fælles lager, ransagning og genopfyldning, generatorens brændstof/strøm, at vandrenseren kræver strøm og tid, væske/drikke og gem-indlæs. |
| `tests/unit/test_build.gd` | Build, Inv, ZombieSim, SaveCodec | Tester placering og dens regler, betal-én-gang, samtidig placering, opgradering/skade/reparation/ødelæggelse, refusion og indhold ved nedtagning, zombiers gennembrud, pigfælder, bunkerregler, opgraderingen af lemmen, gemning og migreringen 3→4. |
| `tests/unit/test_terrain.gd` | Terrain, WorldActions, SaveCodec | Tester gitteret, gravevalidering og -tid, samtidige gravninger, støtters forbrug/radius/afstand, gemning og afbrudte gravninger. |
| `tests/unit/test_world.gd` | WorldState, WorldActions, Simulation | Tester oprettelse af verden, lagring af ændringer, seedet tilfældighed, uret, validering af interaktioner, samtidige anmodninger, bevægelsesplausibilitet. |
| `tests/unit/test_bunker.gd` | WorldActions, Simulation, SaveCodec | Tester tilflugtsrummets byggetid, ingen dobbelt lem, portaler, træ kun givet én gang, nedkøling, forstærkning der kun bruger træ én gang, ubegrænsede udviklerniveauer, gemte spil, migrering. |
| `tests/unit/test_save.gd` | SaveCodec, SafeFile, Saves | Tester gem/indlæs-rundtur, validering, standardværdier, slettet indhold, den historiske v1-fixture, migreringer, sikre skrivninger og fallback til sikkerhedskopi. |
| `tests/unit/test_assets.gd` | AssetCatalog, AssetResolver | Tester navngivning af udskiftninger, prioritet, afvisning af beskadigede/for store filer, nødløsning, lydudskiftning og tilpasning til visningsboksen. |
