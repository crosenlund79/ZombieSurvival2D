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
| `src/state/vehicle_state.gd` | — | Ét køretøj som rene data: type, område, position, retning, motor, sæder (indeks 0 = fører), bagagerum og reserverede nøgle/lås-felter. Gemmes (undtagen førerens rapporterede fart). |
| `src/state/animal_state.gd` | — | Ét vildt dyr som rene data (art, område, position, retning, aktivitet, hjemområde, timere). Midlertidigt: dyrelivet genopbygges fra indholdet når en verden starter. |
| `src/state/threat_state.gd` | — | Verdens støjkø og opmærksomhed pr. grov zone (midlertidig: gemmes aldrig, så en genindlæst verden starter rolig). |
| `src/state/world_state.gd` | Content, RegionState, PlayerState, Simulation | Hele den fælles verden som rene data: id, seed, urtik, områder, spillere. Giver også seedede tilfældighedsstrømme. |
| `src/state/region_state.gd` | Content | Spillerskabte ændringer i ét område, kun gemt hvor de afviger fra det forfattede indhold, med et revisionsnummer pr. genstand. |
| `src/state/bunker_state.gd` | — | Ét tilflugtsrum som rene data: indgangens identitet, niveauer efter dybde med fortegn (intet maksimum) og det fælles lager. Danner og fortolker niveauernes område-id'er. |
| `src/state/player_state.gd` | Content | Én spillers gemte data: identitet, navn, område, position, retning. |
| `src/sim/nav_grid.gd` | Content, Prop, FenceLine | Værtens gangbarhedsgitter bygget fra områdescenens forfattede kollisionsdata plus levende træer/låger; A*-ruter og sigtelinjer for zombier og angreb. |
| `src/sim/zombie_sim.gd` | NavGrid, ThreatState, WorldState | Kun værten: simulation af de Brændte (stadig kaldet zombier i koden) — hørelse, opmærksomhed, AI-tilstandsmaskinen, bevægelse, angreb og lig; udviklerstartede jagter (start_hunt, fært igen, opgivelse, diagnostik). Bestande og forstærkninger kører kun med den automatiske løkke slået til (ThreatState.ambient). |
| `src/sim/sleep_sim.gd` | WorldState, EnvSim, WorldActions | Fælles søvn (vært): tilflugtsgrupper (hytten + dens bunker), søvn kun om aftenen, indre monolog ud fra virkelige hændelser når nogen er udenfor, en enstemmig replikeret afstemning (aflyses ved nej / timeout / hvis nogen går), søvnresultatet som GameSession omsætter til et opdelt tidsspring, og at vågne udhvilet og varm. |
| `src/sim/vehicle_sim.gd` | WorldState, VehicleState, ZombieSim, Inv | Værtsstyrede køretøjer: faste placeringer (oprettes én gang), ind- og udstigning (ved siden af bilen, kun når den holder stille), motor (kun føreren, støj), validerede førerpositioner hvor passagererne følger med, vejudgange der flytter bilen med alle i den og bagagerummet til næste område, læg i / tag fra bagagerummet, nedslåede eller afbrudte passagerer sættes ud, motorstøj, varmeapparat, gem/indlæs og sædekontrol. |
| `src/sim/wildlife_sim.gd` | WorldState, AnimalState, NavGrid, EnvSim | Ikke-aggressive ulve og bjørne (vært): placering fra `content/tuning/wildlife.json`, hvile og vandring på farbar grund nær hjemmet, de opdager spillere (holder øje), trækker sig eller flygter, kald (oftere om natten) som lydhændelser, kompakte rækker til klienter. Angriber aldrig. |
| `src/sim/blood_sim.gd` | WorldState, EnvSim, VehicleSim | Optøet blod (vært): varmekilder (områdets `heat_sources`, kørende motorer, udviklervarme), de Brændtes optøning / genfrysning, af og til små dryp der fryser til mærker, vejrets udviskning (falmer, dækkes af sne, skylles væk af regn), synlighed til visningen, gem / indlæs. |
| `src/sim/side_section.gd` | Terrain, RegionState, Content | Iteration 012 (eksperiment): tværsnitslæsningen af et bunkerniveau, delt af vært og sidevisning — gulve, lofter og åbne rum fra udgravningsgitteret (eller rummet i et niveau uden gitter), hvile- og hængepositioner, gang i sidevisning (trin på én række, vægge, ingen hop), stiger og støtter man kan klatre i, rækkevidde i sidevisning og visningens projektion (rækker tegnes lavere). |
| `src/sim/scavenge_sim.gd` | WorldActions, SkillSim, Inv, ZombieSim | Iteration 013: fysiske beholdere (vært) — én der søger ad gangen, søgninger med tid fra det fælles ur, afbrydelse (gå væk, forlade området, køretøj, død, afbrudt forbindelse), færdig søgning afslører det forfattede indhold én gang (fyldes aldrig op igen), Plyndring-XP én gang, støj efter beholdertype, tage det der er tilbage, søgninger i gang gemmes ikke. |
| `src/sim/hideout_sim.gd` | ZombieSim, SideSection, WorldActions | Iteration 014: det forstyrrede skjulested — støj inde i et almindeligt hus hober sig op; over grænsen kommer en eller to skjulte Brændte frem én gang (gemmes); inde i bygninger følger de gulve og trapper; flygter byttet, går de mod døren og følger med ud; ryddet når de er døde. |
| `src/sim/loot_pools.gd` | WorldState, Inv, Items, content/loot_pools.json | Iteration 014: stedsafhængige, vægtede fundpuljer — en beholder med en pulje trækkes én gang, ved første gennemsøgning, ud fra verdens-seed + dens id (tom, kun skrammel eller vægtede fund; skydevåben er sjældne og har nogle gange et par patroner i). |
| `src/sim/skill_sim.gd` | PlayerState, content/tuning/skills.json | Iteration 013: færdigheder pr. spiller (kun Plyndring er aktiv) — XP-til-niveau-kurve, niveauloft, effekt på søgetid (aldrig øjeblikkelig), XP ganget med udviklerens XP-multiplikator, sæt / nulstil, rensning ved indlæsning. |
| `src/sim/omen_sim.gd` | WorldState, EnvSim | Red Thaws stemningsvarsler som rene funktioner af verdens-seed og ur: latter ved bebyggelsens steder om dagen og silhuetter langs faste ruter om natten. Intet gemmes eller sendes, så alle spillere oplever det samme. |
| `src/sim/survival_sim.gd` | WorldActions | Kun værten: spillerens livstegn — langsom genopretning af helbred og den milde genoplivningsregel (behold alt, vågn i stuehuset). |
| `src/content/items.gd` | SafeFile | Genstandskatalog (`content/items.json`, 175 genstande fra iteration 014): faste genstands-id'er, navnenøgler, kategori, vægt, ikon, stakgrænser (pladser pr. stak) og `move()`, der flytter mellem to beholdninger i ét trin, så intet dubleres. |
| `src/sim/infra_sim.gd` | Simulation, WorldActions, ZombieSim, Content | Kun værten: infrastruktur på det fælles ur: generatorens brændstofforbrug og automatiske stop, logisk strøm i bunkeren (`is_powered`), vandrenserens omdannelse over tid med strøm, væskebalancens fald og mild dehydrering. |
| `src/sim/inventory.gd` | Items, WorldState | Lagertransaktioner: bæreplads, hvilke beholdninger der betaler (din taske, så tilflugtsrummets lager under jorden), betaling, udstyrsposter, at give ting (overskud lægges i en bunke på jorden), overførsler til beholdere. |
| `src/sim/build.gd` | Content, Terrain, Inv, NavGrid, ZombieSim | Byggeregler: definitioner, fodaftryk, placeringskontrol (zoner, åbent bunkergulv, optaget plads, frihold, aldrig afskære et bunkerområde), opførelse, opgradering, reparation, nedtagning, bunker og kasser, skade på konstruktioner, hvad zombier bryder igennem. |
| `src/sim/firearms.gd` | Items, ZombieSim, Inv | Iteration 014: fælles skydevåbensystem (vært) — skud langs sigtelinjen (træffere, hagl, aftagende skade, sigtelinje, gulve i sidevisning), skud i våbnet, ladning fra løse patroner eller et ladt magasin, slid, klik når tomt, højt skudsignal. |
| `src/sim/farm_sim.gd` | Build, InfraSim, EnvSim, Inv | Produktion fra byggede ting på det fælles ur: regnvandsopsamleren (hurtigere i regn) og det hydroponiske plantebed (kræver rent vand og strøm). Handlinger til at tømme, vande og høste. |
| `src/sim/env_sim.gd` | WorldState | Døgn og vejr fra det fælles ur: tid på døgnet, dagslys, seedede perioder med regn/klart vejr og virkningen på zombiers syn og hørelse. |
| `src/sim/craft.gd` | Build, Inv, Items, WorldState | Regler for fremstilling ved arbejdsbænken: opskrifter (content/recipes.json), oplåsninger fælles for verdenen, ét tidsbestemt job pr. bænk betalt ved start, færdige ting ligger til afhentning, reparation af udstyr. Job overlever gemning og afsluttes én gang. |
| `src/sim/event_sim.gd` | ZombieSim, Build, EnvSim | Regional trusselsvarme (larm, drab, aftagning, ekstra omvandrere), larm fra bunker/bygning, der siver op til overfladen, og forsvarsbegivenheden ved gården (advarsel, horde, angreb på konstruktioner, udfald, nedkøling, genoptagelse efter indlæsning). |
| `src/sim/npc_sim.gd` | NpcState, Inv, FarmSim, InfraSim, Terrain | Simulering af overlevende: rekruttering, rejsen hjem, liv i bunkeren på cellegitteret, vand- og dyrkningsjob med det fælles lager og rigtige maskiner, daglig forsørgelse, søge ly under en horde, replikeringsrækker. |
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
| `src/presentation/ui/inventory_panel.gd` | Session, Items, Inv | Oppakningspanel (I/Tab): udstyr i hånd og på krop, udstyr med tilstand og værdier, stabler med beskrivelser; knapperne Brug, Tag på, Læg væk og Smid sender anmodninger til værten. |
| `src/presentation/ui/guide.gd` | Session, Settings, EventSim | Spillervejledning: kontekstuelle tips, der vises én gang pr. installation (kan slås fra), og overlevelsesguiden (H) med alle emner og en fremskridtsoversigt læst fra den fælles verden. |
| `src/presentation/ui/settlement_panel.gd` | Session, NpcSim, InfraSim | Bosættelsesoversigt (N): beboere, job og hvad der blokerer dem, forsyninger på det fælles lager, strøm og behov; knapper til at tildele job sender anmodninger. Laver også den overlevendes eget panel. |
| `src/presentation/ui/skills_panel.gd` | SkillSim, UITheme | Iteration 013: færdighedsskærmen (K) — niveau, XP, XP til næste niveau, en fremdriftsbjælke og Plyndringens effekt (hvor lang tid en almindelig søgning tager nu og på næste niveau). Kun visning. |
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
| `src/presentation/world/vehicle_view.gd` | Session, VehicleSim, Assets, LightFactory | Viser ét køretøj (tegning i 16 retninger, skrå kollisionsflade, forlygter, baglygte, udstødning, motorlyd hvis tonehøjde følger farten); når den lokale spiller kører, forudsiger den bilen med top-down-fysik og sender positioner til værten. Ind-/bagagerumsinteraktion og bagagerumspanelet. |
| `src/presentation/world/animal_view.gd` | Session, Assets | Viser ét vildt dyr ud fra verdensdata: interpolation, sidetegning med to gangbilleder (spejlet mod venstre), for- og bagtegning, et vagtsomt løft og et løbehop. |
| `src/presentation/world/blood_view.gd` | Session, BloodSim, Assets | Tegner et områdes optøede blodmærker: små dråber, hvidere under ny sne, blegere efter regn, svage eller skjulte i tåge, snestorm og på afstand (set fra den lokale spiller). Ingen markører eller HUD. |
| `src/presentation/world/side_art.gd` | SideSection, AssetCatalog | Iteration 012: hvilket sidevisningsbillede der afløser et ovenfra-billede, og hvor ting og genstande står i tværsnittet (gulv eller loft, strakt fra gulv til loft for stillads, op gennem loftet for stigen). |
| `src/presentation/world/side_bunker_view.gd` | RegionView, SideSection, SideTerrain | Iteration 012 (eksperiment): et bunkerniveau tegnet som 2D-sidevisning, bygget i kode ud fra de samme områdedata (ting, genstande, terræn, spillere, overlevende) med sidevisningsgrafik. Standard for bunkerniveauer; F7 skifter til de oprindelige ovenfra-scener. |
| `src/presentation/world/container_view.gd` | EntityView, ScavengeSim, MachinePanel | Iteration 013: en beholder man kan gennemsøge — grafik efter tilstand (forfattet / gennemsøgt), en fremdriftsbjælke mens nogen søger, E for at søge / stoppe, bagefter et lille panel til at tage det der er tilbage. |
| `src/presentation/world/ice_drift.gd` | Session, Assets | Iteration 014: isbjerge og isflager der driver langs en rende af åbent havnevand; hver position afhænger kun af verdens fælles ur (ingen tilstand, ens for alle spillere). |
| `src/presentation/world/side_terrain.gd` | SideSection, Terrain, Session | Iteration 012: tegner tværsnittet (jordlag, grundfjeld, udgravede rum, gulvbrædder, loftsbjælker, betondæk, skakten, gravning i gang, støtter som stillads) og tilbyder grave/støtte-prompten i sidevisning for den celle, du vender mod. |
| `src/presentation/world/weapon_rack_view.gd` | EntityView | Køllestativet i stuehuset; at tage en kølle udruster spilleren (én hver, løber aldrig tør). |
| `src/presentation/world/machine_view.gd` | EntityView, MachinePanel, InfraSim, Items, Audio | Lagerskab, generator, vandrenser og ransagningssteder på overfladen: grafik for tændt/slukket/tom, maskinpanelets indhold, direkte ransagning af fundsteder, generatorens brummen mens den kører. |
| `src/presentation/world/lamp_view.gd` | EntityView, InfraSim, LightSpot | Elektrisk bunkerlampe: tændt med lys, mens bunkeren har strøm, ellers mørk. Læser kun den logiske strømtilstand. |
| `src/presentation/world/structure_view.gd` | Session, Build, Assets, MachinePanel | Viser én bygget ting eller bunke på jorden: grafik efter tilstand, kollision mens den spærrer, tilstands-/fremskridtsbjælke, træffeffekt; panelet med reparation, opgradering, nedtagning og beholder-/produktionshandlinger. |
| `src/presentation/world/npc_view.gd` | Session, NpcSim, Assets, MachinePanel | Viser én overlevende ud fra replikerede data med en samtale. Før hun stoler på dig, sidder den bange overlevende sammenkrøben i et hjørne: ryster, mumler brudstykker, farer sammen og svarer, når man taler til hende (lokal præsentation). |
| `src/presentation/world/starter_bag_view.gd` | EntityView, Session, Audio | Tasken ved det nedbrændte skur: fuld eller tømt for den lokale spiller; værten giver hver spiller ét startsæt (WorldActions._starter_bag). |
| `src/presentation/world/bed_view.gd` | EntityView | En seng eller sovepose: søvn-interaktionen (og soveposetegning i bunkere). |
| `src/presentation/world/omen_view.gd` | OmenSim, Assets, Audio | Afspiller en regions varsler for den lokale spiller: positioneret latter tæt på stedet (aldrig vist) og en kort dybdesorteret silhuet om natten. Fører en kort diagnostikliste. |
| `src/presentation/world/terrain_view.gd` | Terrain, Session, Assets | Tegner udgravet gulv, fast jord, 3/4-vægflader og blækkanter ud fra gitteret; genopbygger kollision ved ændringer; placerer støttestolper; den kontekstuelle grav/støtte-prompt med farvet målramme. |
| `src/presentation/world/placeholder_block.gd` | — | Gråboks-hjælper (brugt i fase A, beholdt til skitsering af nye områder): et farvet rektangel med tilsvarende kollision. |
| `src/presentation/world/placeholder_ground.gd` | — | Gråboks-jord med et 100 px gitter (ikke brugt i den nuværende scene). |

## Udvikling og test

| Script | Afhænger af | Hvad det gør |
|---|---|---|
| `src/dev/dev_preset.gd` | Build, Inv, NpcSim, SessionLog | Forudindstilling til udviklerens testverden (klargjort tilflugtsrum, maskiner, arbejdsbænk, plantebed, lager, værktøj, overlevende hjemme; markeret i world.meta) og F3-fejlrapporten (build, verden, sted, systemer, seneste log). |
| `src/dev/content_check.gd` | Content, AssetCatalog, Localization | Kontrol af indholdets integritet (PASS/WARN/FAIL): områder, områdescener, manifester, asset-ID'er brugt i koden, oversættelser. Ændrer aldrig noget. |
| `src/dev/autotest_driver.gd` | Session, Saves, Assets, Audio | Fjernbetjening kun til test (kun med `--autotest`): læser kommandoer fra en fil og skriver tilstandsrapporter, så `tools/mp_test.py` kan styre rigtige, separate spilprocesser. |
| `tests/test_case.gd` | — | Lille basisklasse til enhedstests (`check`, `eq`). |
| `tests/test_runner.gd` | TestCase, ContentCheck | Kører alle testfiler i tests/unit og indholdskontrollen, skriver resultater og afslutter med fejlkode ved fejl. |
| `tests/unit/test_threat.gd` | ZombieSim, WorldActions, NavGrid | Tester navigation, syn, hørelse, opmærksomhed op/ned, eskaleringslofter, nærkampsautoritet, vægge, skade efter optakt, genoplivning, stuehusets grænse og gemmepolitikken. |
| `tests/unit/test_infra.gd` | Items, InfraSim, WorldActions, SaveCodec | Tester genstandsflytning, kapløb om fælles lager, ransagning og genopfyldning, generatorens brændstof/strøm, at vandrenseren kræver strøm og tid, væske/drikke og gem-indlæs. |
| `tests/unit/test_build.gd` | Build, Inv, ZombieSim, SaveCodec | Tester placering og dens regler, betal-én-gang, samtidig placering, opgradering/skade/reparation/ødelæggelse, refusion og indhold ved nedtagning, zombiers gennembrud, pigfælder, bunkerregler, opgraderingen af lemmen, gemning og migreringen 3→4. |
| `tests/unit/test_survival_cycle.gd` | Inv, Craft, Build, FarmSim, InfraSim, SaveCodec | Tester tag på/smid/saml op/brug, bæregrænse med udstyr, betal-én-gang og tidsbestemt fremstilling, oplåsninger, fremstilling hen over gem/indlæs, udstyrets virkning (fældning, panser, slid), reparation, sult, plantebedets fødevareproduktion og nye fund. |
| `tests/unit/test_world_events.gd` | EventSim, EnvSim, ZombieSim, WorldActions, SaveCodec | Tester regional varme og aftagning, bunkerlarm gennem lemmen, forsvarsbegivenhedens forløb (inkl. gem/indlæs uden dubletter), horder der angriber konstruktioner, fælles seedet vejr og nat, regnvandsopsamlere, tankstationens unikke fund og karburatoren. |
| `tests/unit/test_red_thaw.gd` | WorldActions, Inv, ZombieSim, EventSim, OmenSim, SaveCodec | Tester åbningen (start ved tasken, ét sæt pr. spiller også efter genindlæsning), sættets ting, ingen automatiske trusler som standard, udviklerjagter (forfølgelse, angreb, beskyttet hytte, opgivelse, gemmes ikke) og deterministiske dag/nat-varsler. |
| `tests/unit/test_world_awakens.gd` | ZombieSim, ExposureSim, SleepSim, VehicleSim, WildlifeSim, SaveCodec | Iteration 011-tests: de Brændtes lytten, skrig, svargrænser og nedkøling, kropsholdninger og kravlespurter, eftersøgning efter et tabt mål; samt de senere milepæles systemer. |
| `tests/unit/test_shadows_depth.gd` | TestCase | Iteration 012: optøet blod (intet blod uden varme, varme optør og giver få små dryp, genfrysning stopper det, motorer som varme, vejrets udviskning og synlighed, gemning) og bunkeren set fra siden. |
| `tests/unit/test_scavengers_circuit.gd` | TestCase | Iteration 013: Ashgroves bygninger indefra (ind og ud af alle bygninger, læ, lyd der når gaden), fund efter sted, søgninger med tid, afbrydelse, én søgende pr. beholder, ingen fordoblet udbytte eller XP, søgetidskurven, XP-multiplikatoren, gemning. |
| `tests/unit/test_five_settlements.gd` | TestCase | Iteration 014: bygninger set fra siden (hvilke områder er sidevisninger, ind og ud med fødderne på gulvet, hyttens lem og bunker, trapper, reposer og klatring, gamle positioner flyttes på plads, beholdere i sidevisning) og de senere milepæle i De Fem Bosættelser. |
| `tests/unit/test_settlement.gd` | NpcSim, NpcState, Build, InfraSim, SaveCodec | Tester den overlevende: møde, betingelser for rekruttering og rejsen, vand- og dyrkningsjob med kun lagrede ressourcer og rigtige maskiner, status når noget blokerer, daglig forsørgelse, søge ly under en horde, gemning uden dubletter. |
| `tests/unit/test_terrain.gd` | Terrain, WorldActions, SaveCodec | Tester gitteret, gravevalidering og -tid, samtidige gravninger, støtters forbrug/radius/afstand, gemning og afbrudte gravninger. |
| `tests/unit/test_world.gd` | WorldState, WorldActions, Simulation | Tester oprettelse af verden, lagring af ændringer, seedet tilfældighed, uret, validering af interaktioner, samtidige anmodninger, bevægelsesplausibilitet. |
| `tests/unit/test_bunker.gd` | WorldActions, Simulation, SaveCodec | Tester tilflugtsrummets byggetid, ingen dobbelt lem, portaler, træ kun givet én gang, nedkøling, forstærkning der kun bruger træ én gang, ubegrænsede udviklerniveauer, gemte spil, migrering. |
| `tests/unit/test_save.gd` | SaveCodec, SafeFile, Saves | Tester gem/indlæs-rundtur, validering, standardværdier, slettet indhold, den historiske v1-fixture, migreringer, sikre skrivninger og fallback til sikkerhedskopi. |
| `tests/unit/test_assets.gd` | AssetCatalog, AssetResolver | Tester navngivning af udskiftninger, prioritet, afvisning af beskadigede/for store filer, nødløsning, lydudskiftning og tilpasning til visningsboksen. |
