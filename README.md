# Alchemio

## O projekte

Alchemio je vzdelávacia 2D hra v slovenčine pre žiakov 7. až 9. ročníka základnej školy. Hodí sa na samostatné objavovanie aj na precvičovanie učiva na hodine chémie. Na mape zbieraš atómy, na pracovnej ploche ich spájaš do molekúl a v laboratóriu skúmaš vlastnosti objavených látok.

Pri skladaní vody napríklad zistíš, čo vyjadruje vzorec H₂O a ako sú jej tri atómy navzájom spojené. Pri zahrievaní potom vidíš, že voda aj počas varu zostáva tou istou látkou. Pri modelovej reakcii metánu s kyslíkom sa tie isté atómy usporiadajú do molekúl nových látok.

## Inštalácia a spustenie

### Zo zdrojových súborov

1. Stiahni si **Godot Engine 4.5.1** vo vydaní **Standard** pre svoj operačný systém a spusti editor. [Stiahnuť Godot 4.5.1](https://godotengine.org/download/archive/4.5.1-stable/)
2. Ak máš projekt v archíve ZIP, rozbaľ ho. V správcovi projektov Godot klikni na **Import** a vyber súbor `project.godot` v priečinku s týmto README.
3. Otvor importovaný projekt, počkaj na dokončenie importu a stlač **F5**. Pri prvom spustení sa otvorí mapa s atómami vodíka a kyslíka.

### Z hotovej webovej verzie

Ak máš webový balík `Alchemio-alpha-A8-web.zip`, rozbaľ ho a otvor terminál v priečinku, ktorý obsahuje `index.html`. Na spustenie potrebuješ Python 3 a prehliadač s podporou WebGL 2.0. Editor Godot môžeš pri tejto možnosti vynechať.

1. Vo Windows spusti `py -m http.server 8060 --bind 127.0.0.1`. V Linuxe alebo macOS použi `python3 -m http.server 8060 --bind 127.0.0.1`.
2. V prehliadači otvor [lokálnu hru](http://127.0.0.1:8060/). Terminál nechaj počas hrania otvorený. Po skončení zastavíš server klávesmi **Ctrl+C**.

Webový balík sa distribuuje samostatne. Ak máš iba zdrojové súbory z repozitára, hru spustíš prvým postupom.

## Ovládanie a prvý pokus

Skús si ako prvú molekulu poskladať **vodu (H₂O)** a priviesť ju v laboratóriu do varu.

1. **Zozbieraj atómy.** Po mape sa pohybuj klávesmi **WASD** alebo **šípkami**. Dotkni sa dvoch atómov vodíka (**H**) a jedného atómu kyslíka (**O**). Unesieš najviac 12 atómov. Tyčky, ktoré na mape držia skupinu pokope, slúžia len na prenášanie. Keď máš potrebné atómy, klikni na **K skladaniu**.
2. **Vytvor dve väzby.** V režime **Presun** si môžeš atómy rozmiestniť myšou. Vyber **Jednoduchá**, klikni na prvý H a potom na O. Rovnako spoj druhý H s tým istým O. Hra rozpozná model H–O–H, zvýrazní ho zelenou farbou a vodu hneď pridá do zbierky **Kolekcia**.
3. **Získaj porciu vody.** Klikni na **Dokončiť skladanie**. Za každú dokončenú molekulu dostaneš do zásoby jednu hernú porciu látky. Ak ti zostali nevyužité atómy, hra si pred ich zahodením vypýta potvrdenie. Ak niečo chýba, cez **Späť na mapu** môžeš pokračovať v zbere.
4. **Pozoruj var.** V laboratóriu vyber **Kvapaliny → Kadička** a pridaj porciu vody do prístroja. Zvoľ **Nahriať**. Pri tlaku 1 atm začne čistá voda v modeli vrieť približne pri 100 °C. Stlač **Ochladiť** a sleduj, kedy var prestane. Cez **Vrátiť obsah** vrátiš vzorku do zásoby.

Pri ďalšom zbere skús spojiť dva atómy O väzbou **Dvojitá**. Po prvom úspešnom **spaľovaní vodíka** a prvej **elektrolýze vody** sa pri ďalšom zbere objaví aj uhlík (C).

| Čo chceš urobiť | Ako na to |
| --- | --- |
| Zmeniť násobnosť väzby | Vyber **Jednoduchá**, **Dvojitá** alebo **Trojitá** a postupne klikni na oba spojené atómy. |
| Odstrániť väzbu | V režime **Presun** klikni na čiaru medzi atómami a stlač **Delete** alebo **Odstrániť väzbu**. |
| Prečítať si o látke | Otvor **Kolekcia** a vyber objavenú látku. |
| Vrátiť sa z laboratória na mapu | Zvoľ **Nový zber**. Obsah prístroja sa vráti do zásoby. |
| Zobraziť návod | V ktorejkoľvek fáze klikni na **? Pomoc**. |

### Čo sa uloží po skončení hry?

Hra automaticky ukladá objavy, zásobu látok a dokončené pokusy. Po opätovnom spustení s uloženým postupom sa otvorí laboratórium. Porcie z prístroja aj neodobraté plyny z výstupov nájdeš späť v zásobe. Rozpracovaný zber a rozostavané molekuly sa po ukončení hry stratia. Ak chceš začať úplne odznova, vyber **Nová hra** a potvrď vymazanie postupu.

Vo webovej verzii sa postup ukladá v prehliadači. Ak chceš pokračovať, použi rovnaký profil aj adresu vrátane portu. V súkromnom okne môže postup po zatvorení okna zaniknúť.

## Stav vývoja

**Posledné vydanie je alfa A8.** Pracovná verzia má dva režimy laboratória, **Kvapaliny** a **Spaľovanie**, so spoločným stojanom. Vyberáš prístroj a postup. Hra určí reakciu podľa vloženej vzorky. Plynový horák spracuje vodík aj metán. V trubicovej peci môžeš porovnať produkty pri rôznych množstvách kyslíka.

- **Etapa 1 · H a O.** Zostav H₂, O₂ a H₂O. Po spaľovaní vodíka odober vodu a použi ju pri elektrolýze. Oba dokončené pokusy odomknú uhlík. Var vody slúži na porovnanie a rozklad H₂O₂ je doplnkový pokus.
- **Etapa 2 · C.** Porovnaj úplné a neúplné spaľovanie uhlíka. Priveď získaný CO₂ do vody a sleduj indikátor. Spaľovanie metánu je doplnkový pokus.
- Staršie uloženia zachovávajú odomknutý uhlík, objavy a zásobu dostupných látok. Nový formát 3 ukladá aj dokončené pokusy.

**Čo je v pláne**

- Pred vydaním Beta 0.1 overiť celý postup vo webovej verzii s novou aj uloženou hrou a pripraviť balík pre hráčov.
- Overiť so žiakmi, či dokážu samostatne prejsť od zberu po pokus v laboratóriu, a podľa ich spätnej väzby upraviť ovládanie a nápovedu.
- S učiteľom chémie skontrolovať správnosť a zrozumiteľnosť vysvetlení.
- Ak zvýši čas, pridať krátke zvuky pri zbere atómu a objavení látky.

Laboratórium používa zjednodušené školské modely. Nastavenia prístrojov a animácie slúžia na porovnanie výsledkov v hre.

## Zdroje a licencie

- **Chemické údaje.** Atómové hmotnosti vychádzajú z tabuliek CIAAW. Vzorce a štruktúry molekúl boli overené podľa NIST Chemistry WebBook a PubChem. Vysvetlenia väzieb, varu a chemických rovníc vychádzajú z Chemistry LibreTexts a OpenStax Chemistry 2e. [Tabuľky CIAAW](https://ciaaw.org/abridged-atomic-weights.htm) · [Zdroje pri jednotlivých látkach v katalógu hry](data/catalog.json) · [OpenStax o skupenských premenách](https://openstax.org/books/chemistry-2e/pages/10-3-phase-transitions)
- **Godot Engine** je vydaný pod licenciou MIT. [Licencia Godot Engine](https://godotengine.org/license/)
- **Ikona projektu** používa logo Godot (© 2017 Andrea Calabró) pod licenciou CC BY 4.0. [Logo Godot](https://godotengine.org/press/) · [Licencia CC BY 4.0](https://creativecommons.org/licenses/by/4.0/)
- **Písmo Noto Sans** od The Noto Project Authors sa používa podľa licencie SIL Open Font License 1.1. [Priložený text licencie](assets/fonts/OFL.txt)
- **Kód a pôvodný obsah hry Alchemio.** Pre túto časť projektu zatiaľ v repozitári nie je uvedená samostatná licencia.

skuska
