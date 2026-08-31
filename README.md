# Osobní tréninkový systém

Lokální systém pro přípravu, schválení a vyhodnocování tréninkových
bloků. YAML uchovává fakta a stav. Markdown uchovává pravidla, drafty,
session logy a review. Ruby validátor kontroluje jejich společný kontrakt.

Systém není autonomní trenér ani zdravotnická aplikace. AI připraví draft,
uživatel ho připomínkuje a výslovně schválí. Plán nepředepisuje
konkrétní váhy; uživatel volí zátěž podle cílového RPE a skutečnou
zátěž zapisuje až po tréninku.

## Struktura

```text
data/                         profil, vybavení, preference, pravidla a souhrn historie
history/blocks/               původní historické tréninkové bloky
calendar/exceptions.yaml      nemoc, cesta a jiné odchylky
blocks/YYYY-MM-block-NNN/     plan.md, sessions/ a review.md jednoho bloku
_system/state/current.yaml    aktivní blok a pozice v rolling sekvenci
_system/templates/            šablona plánu, session logu a block review
lib/training_system/          bezpečné čtení, sekvence a validace
bin/validate                  kontrola celého repozitáře
```

Kanonická data jsou `data/profile.yaml`, `data/equipment.yaml`,
`data/preferences.md`, `data/exercise_library.yaml`,
`data/coaching_rules.md` a `data/history_summary.md`.

## Starší tréninková historie

Původní historické bloky patří do sledovaného adresáře
`history/blocks/`. Mohou to být Markdowny, PDF, CSV nebo jiné exporty.
Zpracování z nich vytvoří souhrn po tréninkových blocích v
`data/history_summary.md`: období, zaměření, použité cviky a předepsané
série a opakování.

Staré jednotlivé tréninky se zpětně nepřepisují do `sessions/`.
Předepsaný plán navíc nedokládá, že byl skutečně odcvičen. Jednotlivé
session logy vznikají až pro tréninky absolvované po spuštění tohoto systému.
Podrobná pravidla a doporučené názvy souborů jsou v `history/README.md`.

## Kontrola připravenosti

Spusť:

```bash
bin/validate
```

Chyba vrací exit code 1. Samotné upozornění vrací exit code 0. Před
doplněním profilu jsou očekávaná přesně dvě upozornění:

```text
equipment_needs_input
health_needs_review
```

Dokud zůstává kterékoli z nich, první blok se negeneruje. Dokonči
checklist v `ONBOARDING.md`, nastav oba review statusy na `confirmed` a
validaci zopakuj.

## Životní cyklus bloku

Každý blok má 3 až 6 týdnů, výchozí jsou 4. Plán prochází stavy:

```text
draft -> approved -> active -> completed
```

Draft vznikne z `_system/templates/plan.md`. Uživatel navrhne nebo schválí změny,
které se zapíší do sekce `Approved Changes`. Teprve jeho výslovné
schválení dovolí stav `approved`. Aktivní blok nesmí odkazovat na draft.
Při aktivaci se plán přepne na `status: active` a `_system/state/current.yaml`
současně dostane `active_block`, `plan_status: active` a shodné číslo bloku.

Pro každý skutečný trénink vznikne soubor
`blocks/<blok>/sessions/NN-ŠABLONA.md` podle `_system/templates/session-log.md`.
Po poslední jednotce se vyplní `review.md` podle
`_system/templates/block-review.md`.
Review hodnotí adherence, trend RPE, progres, pestrost, únavu, bolest a
kardio. Až pak se blok označí jako `completed` a jeho závěry se použijí pro
další draft.

## Rolling sekvence

`_system/state/current.yaml` uchovává `default_sequence`, `sequence_position` a
`next_session`. Pozice znamená poslední šablonu, přes kterou se sekvence
skutečně posunula.

- `completed` posune sekvenci na další šablonu.
- `partial` a `aborted` vyžadují `sequence_decision: repeat|advance`.
- Zrušený termín nemá session outcome a sekvenci neposouvá.

Sekvence A/B/C proto po dokončené A pokračuje B. Zrušená B ponechá jako
další B. Částečná B pokračuje podle zapsaného rozhodnutí.

## Dvě podoby kardia

`optional_cardio` je volitelná nabídka na konci plánu. Uživatel ji může
vynechat a nezapočítává se do adherence silového bloku.

`integrated_conditioning` patří do konkrétní jednotky. Plán i log uvádějí
minuty, intenzitu, prodloužení jednotky, dopad na silový objem, dopad na
lower-body objem a zdůvodnění. Kombinace těžkých nohou a intenzivního kola
vyžaduje výslovné zdůvodnění; běžně se objem nohou sníží.

## Běžný postup

1. Dokonči `ONBOARDING.md` a spusť `bin/validate`.
2. Nech vytvořit draft nového bloku v `blocks/`.
3. Zkontroluj záměr, délku, sekvenci, cviky, RPE a dopad kardia.
4. Napiš připomínky. Schválené změny se zapíší do plánu.
5. Plán výslovně schval. Potom může přejít do stavu `approved` a
   `active`.
6. Po každé jednotce vyplň skutečný session log.
7. Na konci bloku zkontroluj `review.md` a teprve potom blok uzavři.
8. Po změnách znovu spusť `bin/validate`.
