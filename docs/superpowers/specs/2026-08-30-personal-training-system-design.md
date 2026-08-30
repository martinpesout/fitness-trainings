# Návrh osobního systému pro tvorbu tréninkových plánů

Datum: 2026-08-30  
Stav: schválený návrh k závěrečné kontrole

## 1. Účel systému

Systém funguje jako průběžný osobní trenér pro domácí posilovnu. Připravuje čtyřtýdenní tréninkové bloky, nechává uživatele návrh připomínkovat a po schválení vyhodnocuje skutečně odcvičené jednotky. Hlavním cílem je dlouhodobě udržitelný rozvoj síly a obecné kondice.

Výchozí týden počítá se třemi silovými jednotkami a možností doplnit běh, outdoor cyklistiku nebo indoor cycling. Kardio není automaticky povinné. V konkrétním bloku může být volitelné nebo může tvořit integrovanou část tréninku.

Systém musí zachovat prostor pro lidské rozhodnutí. AI navrhuje, vysvětluje a upozorňuje, ale neschvaluje plán ani jeho pozdější změny za uživatele.

## 2. Rozsah první verze

První verze používá lokální YAML a Markdown soubory v Git repozitáři. Uživatel může data číst a upravovat ručně. AI slouží jako rozhraní pro generování, převod nadiktovaných výsledků a vyhodnocení.

První verze neobsahuje:

- vlastní webovou nebo mobilní aplikaci,
- databázi,
- automatický import ze sportovních zařízení,
- automatické změny schváleného plánu,
- přesné předepisování pracovních vah,
- lékařskou diagnostiku ani rehabilitační doporučení.

## 3. Základní principy

### 3.1 Strukturované jádro a čitelné dokumenty

YAML ukládá fakta, která musí mít jednoznačný význam, například dostupné vybavení, stav aktivního bloku nebo pořadí jednotek. Markdown ukládá přání, vysvětlení, plán, výsledky a hodnocení.

### 3.2 Návrh, schválený plán a skutečnost jsou odlišná data

Návrh plánu není aktivní plán. Schválený plán není záznam toho, co uživatel skutečně odcvičil. Skutečnost se zapisuje do samostatných souborů v adresáři `sessions/`.

### 3.3 Preference nejsou příkaz

Oblíbené cviky, kalistenika nebo kruhy vstupují do rozhodování, ale nepřebíjejí cíle, bezpečnost, potřebné pohybové vzory ani progres. AI může navrhnout méně oblíbený cvik, pokud vysvětlí jeho účel.

### 3.4 Knihovna cviků není whitelist

Knihovna je paměť známých cviků, zkušeností a technických odkazů. AI může navrhnout nový cvik, pokud odpovídá cíli, vybavení a omezením. Nový cvik v návrhu označí a zdůvodní.

### 3.5 Jednoduchost má přednost

Nový soubor, stav nebo pravidlo vznikne jen tehdy, pokud řeší konkrétní problém. Základní blok potřebuje pouze plán, adresář se záznamy a závěrečné hodnocení.

## 4. Doporučená struktura repozitáře

```text
fitness-trainings/
├── data/
│   ├── profile.yaml
│   ├── equipment.yaml
│   ├── preferences.md
│   ├── exercise_library.yaml
│   ├── coaching_rules.md
│   └── history_summary.md
│
├── calendar/
│   └── exceptions.yaml
│
├── state/
│   └── current.yaml
│
├── blocks/
│   └── 2026-09-block-001/
│       ├── plan.md
│       ├── sessions/
│       │   ├── 01-A.md
│       │   ├── 02-B.md
│       │   └── 03-C.md
│       └── review.md
│
├── archive/
│   └── former-coach/
│       ├── raw/
│       └── summary.md
│
└── templates/
    ├── session-log.md
    └── block-review.md
```

Pokud během aktivního bloku vznikne schválená změna, přidá se jako dodatek na konec `plan.md`. Samostatný soubor se změnami není v první verzi potřeba.

## 5. Zdrojová data

### 5.1 `data/profile.yaml`

Obsahuje dlouhodobá fakta o uživateli:

- hlavní cíl a vedlejší cíle,
- výchozí počet silových jednotek,
- běžný časový rozpočet 60 minut,
- zdravotní omezení a historii zranění,
- výchozí vztah síly a kardia,
- preferovaný způsob evidence výsledků.

Dočasné přání pro jeden blok do profilu nepatří.

### 5.2 `data/equipment.yaml`

Obsahuje skutečně dostupné vybavení a jeho parametry. Generátor nesmí předepsat cvik vyžadující nedostupné vybavení, pokud současně nenabídne proveditelnou alternativu.

### 5.3 `data/preferences.md`

Obsahuje:

- cviky a styly, které uživatele baví,
- cviky, které mu nevyhovují,
- věci, které chce vyzkoušet,
- požadovanou míru obměny,
- osobní poznámky, které se špatně vyjadřují pevnými poli.

Odvozený poznatek ze starých plánů musí být označený jako nepotvrzený, dokud ho uživatel neověří.

### 5.4 `data/exercise_library.yaml`

Knihovna uchovává známé názvy, pohybové vzory, potřebné vybavení, zdroj cviku, zkušenost uživatele a technický odkaz. Může začínat téměř prázdná a postupně růst.

Příklad:

```yaml
- id: ring-row
  name: Přítahy na kruzích
  movement_patterns: [horizontal_pull]
  equipment: [rings]
  source: former_coach
  experience: unknown
  user_rating: null
  notes: ""
  video_url: https://www.youtube.com/results?search_query=ring+row+form
```

Pokud cvik v knihovně není, návrh použije vyhledávací odkaz ve tvaru `https://www.youtube.com/results?search_query=NÁZEV+CVIKU+form`. AI nesmí vymýšlet konkrétní odkaz na video z paměti.

Schválení plánu dovoluje přidat nový cvik do knihovny se zkušeností `planned`. Po prvním provedení se zkušenost změní podle záznamu. Samotné zařazení do návrhu z cviku nedělá oblíbenou nebo ověřenou variantu.

### 5.5 `data/coaching_rules.md`

Obsahuje dohodnuté zásady generování, nikoli konkrétní plán. Patří sem například průběžná sekvence jednotek, práce s RPE, pravidla rotace, chování při vynechání termínu a schvalování změn.

### 5.6 `data/history_summary.md`

Obsahuje potvrzené dlouhodobé poznatky z nového systému. Nemá nahrazovat jednotlivé záznamy ani uchovávat každou drobnost.

### 5.7 Staré plány trenéra

Původní soubory zůstávají beze změny v `archive/former-coach/raw/`. Systém z nich může získat seznam dříve předepisovaných cviků, obvyklé pohybové vzory a styl programování.

Protože nejsou dostupné skutečně odcvičené jednotky a váhy, staré plány se nesmí použít jako důkaz výkonnosti, progrese, oblíbenosti ani adherence. `archive/former-coach/summary.md` obsahuje pouze uživatelem ověřené závěry a označené hypotézy.

## 6. Model tréninkového bloku

### 6.1 Časový horizont

Blok má výchozí hodnoticí horizont čtyři týdny. Čtyři týdny nejsou povinnost dokončit přesně dvanáct silových jednotek. Po skončení období AI vyhodnotí skutečný počet jednotek a doporučí pokračování, částečné prodloužení nebo nový blok.

### 6.2 Struktura jednotek

Výchozí sekvence je `A, B, C`. Jednotky nejsou vázané na konkrétní dny a pokračují průběžně:

```text
A → B → C → A → B → C
```

Sekvence je konfigurovatelná pro každý blok. Budoucí blok může použít například `A, B`, pokud to lépe odpovídá cíli a dostupné frekvenci.

Označení A, B a C neznamená izolované partie. Výchozí návrh používá celotělové jednotky s rozdílným důrazem, aby vynechaný termín nezpůsobil dlouhou absenci celého pohybového vzoru.

### 6.3 Neuskutečněný termín

Neuskutečněný termín jednotku nepřeskakuje. Pokud byly dokončeny A a B, následující silový trénink zůstává C bez ohledu na to, zda původně zamýšlený den nevyšel.

„Nic se nedohání“ znamená, že uživatel nemačká C a následující A nepřirozeně blízko k sobě, nepřidává náhradní série a nevytváří tréninkový dluh.

Po delší pauze, nemoci nebo při bolesti AI posoudí, zda má před pokračováním navrhnout lehčí návratovou jednotku.

### 6.4 Rotace cviků

Hlavní varianty cviků zůstávají obvykle dva až tři bloky, tedy přibližně 8–12 týdnů. Dřívější změnu může vyvolat bolest, stagnace, nuda, změna cíle nebo nevhodnost cviku.

Doplňky se mohou měnit po jednom bloku. Dovednostní a ochutnávkové cviky se mohou měnit častěji. Některé referenční cviky se po čase vracejí, aby bylo možné sledovat dlouhodobý vývoj bez celoročního opakování stejné varianty.

## 7. Kardio

### 7.1 Volitelné kardio

Na konci silové jednotky může být stručná nezávazná nabídka běhu, outdoor cyklistiky nebo indoor cyclingu. Vynechání této části se nepočítá jako nesplněný trénink a nevytváří povinnost náhrady.

Výchozí nabídka je nula až dvě lehké kondiční jednotky týdně. Jde o rozsah možností, ne o povinný týdenní cíl.

### 7.2 Integrovaná kondiční část

AI může příležitostně navrhnout kondiční část jako součást tréninku. Návrh musí uvést, že jednotka bude delší a že kondiční práce může ovlivnit silový objem. Zařazení se potvrdí při kontrole celého bloku.

Systém z integrovaného kardia nedělá tvrdý požadavek ani složitý samostatný režim. Jde o trenérskou možnost pro bloky, ve kterých dává smysl.

### 7.3 Spontánní aktivita

Spontánní běh nebo jízda nemusí být součástí schváleného plánu. Uživatel ji může stručně zaznamenat, aby následné vyhodnocení znalo skutečnou zátěž.

## 8. Obsah `plan.md`

Soubor obsahuje metadata a čitelný plán:

```markdown
---
block: 1
status: draft
review_after_weeks: 4
session_sequence: [A, B, C]
target_strength_sessions: 12
---

# Záměr bloku
# Změny oproti minulému bloku
# Společná pravidla
# Trénink A
# Trénink B
# Trénink C
# Progrese během bloku
# Volitelné kardio
# Schválené změny během bloku
```

`target_strength_sessions` je plánovací odhad pro běžný čtyřtýdenní průběh. Není to dluh ani podmínka úspěšného dokončení bloku.

Každý cvik uvádí série, rozsah opakování, cílové RPE, pauzu, stručnou instrukci a technický odkaz. Plán běžně neurčuje konkrétní pracovní váhu. Uživatel ji volí podle cílového RPE a skutečnost zapíše do záznamu.

## 9. Životní cyklus plánu

1. Uživatel předá krátký brief běžnou řečí. Může přidat dočasné přání, například více kruhů před létem.
2. AI načte profil, vybavení, preference, pravidla, kalendář, hodnocení posledního bloku, poslední záznamy a ověřený souhrn staré historie.
3. AI označí konflikty, chybějící údaje a předpoklady.
4. AI vytvoří `plan.md` se stavem `draft`.
5. Uživatel připomínkuje návrh. AI po každé úpravě stručně shrne změny.
6. Po výslovném souhlasu uživatele se stav změní na `approved`.
7. Původní schválený předpis se potichu nepřepisuje. Pozdější schválená změna se přidá jako datovaný dodatek.
8. Po hodnoticím horizontu AI vytvoří `review.md` a doporučení pro další blok.

## 10. Generování plánu

Generátor rozhoduje v tomto pořadí:

1. zdravotní omezení, bolest a bezpečnost,
2. vybavení, čas a kalendářní výjimky,
3. hlavní cíl a brief bloku,
4. skutečné výsledky posledních jednotek, RPE a dokončený objem,
5. vyvážené pokrytí pohybových vzorů,
6. progrese a dostatečně dlouhé zachování hlavních cviků,
7. preference, zábavnost a plánovaná obměna,
8. staré plány trenéra jako inspirace.

Generátor u důležitých rozhodnutí uvede stručný důvod. Pokud vstup chybí, označí předpoklad nebo položí cílenou otázku. Chybějící údaje nesmí nahradit vymyšleným tvrzením.

## 11. Progrese

Progrese se volí podle typu cviku:

- Běžné silové cviky používají jako výchozí double progression. Uživatel nejdřív přidává opakování v dohodnutém rozsahu. Po dosažení horní hranice ve všech pracovních sériích zvolí vyšší zátěž a vrátí se k dolní hranici.
- Kalistenika může postupovat počtem kvalitních opakování, obtížnější variantou, větším rozsahem pohybu nebo menší dopomocí.
- Dovednosti na kruzích mohou postupovat kvalitou provedení, kontrolou nebo délkou výdrže.
- Předepsané kardio postupuje dobou nebo intenzitou pouze tehdy, když je pro daný blok skutečným cílem. Volitelné kardio nemá povinnou progresi.

Jeden způsob progrese se nepoužívá násilně na všechny aktivity.

## 12. Záznam jednotky

Soubory vznikají postupně podle skutečně zahájených silových jednotek:

```text
01-A.md
02-B.md
03-C.md
04-A.md
```

Nevydařený termín nevytvoří prázdný soubor. Integrované kardio se zapisuje do stejného souboru jako silová část.

Příklad struktury:

```markdown
---
session: 4
template: A
date: 2026-09-12
status: completed
duration_minutes: 63
---

# Trénink 04-A

## Výsledky

| Cvik | Série | Váha | Opakování | RPE |
|------|-------|------|------------|-----|

## Kondiční část

## Krátké hodnocení

- celkové RPE:
- zábavnost:
- bolest nebo omezení:
- poznámka:
```

Povinné minimum tvoří skutečné pracovní série, celkové RPE a případná bolest nebo omezení. Délka, zábavnost a poznámka jsou doporučené.

## 13. Aktuální stav

`state/current.yaml` zůstává malý a nezdvojuje obsah plánu:

```yaml
active_block: 2026-09-block-001
plan_status: approved
last_completed: B
next_session: C
```

`next_session` se po dokončené jednotce posune na další šablonu. Zrušený termín ho neposune.

Dokončená jednotka posune sekvenci automaticky. U částečně dokončené nebo předčasně ukončené jednotky systém nic nepředpokládá. Při zápisu se výslovně rozhodne, zda příště jednotku zopakovat, upravit nebo pokračovat následující šablonou.

## 14. Hodnocení bloku

`review.md` shrnuje:

- počet dokončených, částečných a ukončených silových jednotek,
- progres u hlavních cviků,
- vývoj RPE,
- bolest a omezení,
- zábavnost a chuť pokračovat,
- skutečně provedené kardio, pokud bylo zaznamenáno,
- stáří hlavních cviků,
- doporučení ponechat, obměnit nebo později vrátit konkrétní varianty,
- doporučený směr dalšího bloku.

Hodnocení nerozhoduje pouze podle počtu splněných položek. Rozlišuje povinnou silovou jednotku, volitelnou nabídku a spontánní aktivitu.

## 15. Validace a chybové stavy

Před schválením bloku systém ověří:

- použité vybavení je dostupné,
- sekvence jednotek je platná,
- hlavní pohybové vzory jsou rozumně pokryté,
- odhad délky odpovídá obsahu,
- každý hlavní cvik má pravidlo progrese,
- plán zohledňuje poslední výsledky a známá omezení,
- volitelné a povinné části jsou odlišitelné,
- nový cvik je označený a zdůvodněný,
- technický odkaz je uložený odkaz nebo vyhledávací URL,
- návrh ve stavu `draft` není označený jako aktivní.

Při bolesti může uživatel cvik okamžitě ukončit. AI následně navrhne změnu, ale nemá nahrazovat lékaře nebo fyzioterapeuta. Přetrvávající nebo závažné potíže patří odborníkovi.

## 16. Ověřovací scénáře pro implementaci

Implementace musí ověřit alespoň tyto scénáře:

1. Po dokončených A a B zůstává další jednotkou C, i když původně zamýšlený termín nevyšel.
2. Zrušený termín nevytvoří prázdný záznam a neposune sekvenci.
3. Částečně dokončená jednotka neposune sekvenci bez výslovného rozhodnutí.
4. Volitelné kardio se nepočítá jako nesplněná povinnost.
5. Integrovaná kondiční část upozorní na delší trvání a možný dopad na silový objem.
6. Generátor odmítne cvik s nedostupným vybavením nebo nabídne proveditelnou alternativu.
7. Nový cvik může vstoupit do návrhu, i když není v knihovně.
8. Starý předepsaný plán se neinterpretuje jako skutečně odcvičený výkon.
9. `draft` se nestane aktivním blokem bez výslovného schválení.
10. Po delší pauze systém nabídne posouzení návratové jednotky místo mechanického pokračování v původním objemu.

## 17. Rozhodnutí ponechaná na jednotlivých blocích

Následující položky nejsou trvalou součástí architektury a rozhodují se při tvorbě konkrétního bloku:

- sekvence `A, B, C`, `A, B` nebo jiná skladba,
- konkrétní cviky a jejich varianty,
- přesný objem a cílové RPE,
- potřeba lehčího týdne,
- množství nových cviků,
- zařazení integrované kondiční části,
- dočasný důraz na kruhy, kalisteniku, běh nebo kolo.

Tím zůstane systém přizpůsobivý bez toho, aby každý blok používal jiný datový formát.

## 18. Poznámka k aktuálním odborným doporučením

Architektura nezamyká jeden tréninkový split. Současné souhrny výzkumu ukazují, že při srovnatelném objemu nemusí mít full-body a split rutina významně rozdílný vliv na sílu a svalový růst. Podobně lze frekvenci použít hlavně k rozložení zvládnutelného objemu. Proto systém ukládá sekvenci jako konfigurovatelnou vlastnost bloku a při budoucí změně vyžaduje zdůvodnění.

Zdroje:

- [Meta-analýza full-body a split rutin](https://pubmed.ncbi.nlm.nih.gov/38595233/)
- [Systematický přehled frekvence silového tréninku](https://pmc.ncbi.nlm.nih.gov/articles/PMC8363540/)
- [Síťová meta-analýza předpisu silového tréninku](https://pmc.ncbi.nlm.nih.gov/articles/PMC10579494/)
