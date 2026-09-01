# Osobní tréninkový systém

Tento repozitář připravuje, schvaluje a vyhodnocuje osobní tréninkové
bloky. AI vytváří draft. Uživatel rozhoduje o schválení a volí skutečnou
zátěž podle cílového RPE.

## Před generováním bloku

1. Spusť `bin/validate`. Při jakékoli chybě zastav a chybu oprav nebo ji
   předej uživateli.
2. Před prvním blokem zastav také při upozornění
   `equipment_needs_input` nebo `health_needs_review`. První draft lze
   vytvořit až tehdy, když `data/equipment.yaml.review_status` i
   `data/profile.yaml.health.review_status` mají hodnotu `confirmed`.
3. Načti tyto kanonické zdroje:
   - `data/profile.yaml`
   - `data/equipment.yaml`
   - `data/preferences.md`
   - `data/exercise_library.yaml`
   - `data/coaching_rules.md`
   - `data/history_summary.md`
   - `calendar/exceptions.yaml`
   - `_system/state/current.yaml`
4. Podle `_system/state/current.yaml.active_block` načti aktivní blok, pokud existuje.
   Načti jeho `plan.md`, `review.md`, pokud existuje, a skutečné záznamy v
   `sessions/`.
5. Načti také předchozí nejnovější blok. Pro návaznost použij jeho
   `plan.md`, `review.md` a posledních 4 až 6 skutečných session logů napříč
   aktivním a předchozím blokem. Původní historické bloky v
   `history/blocks/` při běžném generování znovu nečti. Použij jejich
   ověřený souhrn v `data/history_summary.md`.

Za skutečný session log považuj pouze vyplněný soubor
`blocks/<blok>/sessions/NN-ŠABLONA.md`. Stav `in_progress` označuje průběžně
vyplňovaný záznam, nikoli absolvovaný výkon. Plán, šablona ani export od
trenéra nedokládají absolvovaný výkon. Starou historii nikdy zpětně
nepřepisuj po jednotlivých trénincích. Zpracuj ji pouze jako souhrn bloků v
`data/history_summary.md`: období, zaměření, cviky a předepsané série a
opakování. Původní soubory ulož do Gitem sledovaného
`history/blocks/`. Podmínky jejich zpracování jsou v `history/README.md`.

## Příprava draftu

- Vytvoř `blocks/YYYY-MM-block-NNN/plan.md` podle `_system/templates/plan.md`.
- Nastav `status: draft`. Draft se nesmí stát aktivním bez výslovného
  schválení uživatele.
- Zvol délku 3 až 6 týdnů, výchozí jsou 4. Volbu zdůvodni cílem,
  kalendářem a odezvou z reálných záznamů.
- Převezmi frekvenci z `data/profile.yaml`, pokud draft výslovně
  nezdůvodní jinou. Nastav
  `target_strength_sessions = planned_duration_weeks * weekly_strength_frequency`.
- Uveď neprázdnou sekvenci unikátních názvů šablon a samostatnou sekci
  `Template <název>` pro každou položku sekvence.
- Respektuj `_system/state/current.yaml.next_session`. Zrušený termín sekvenci
  neposouvá. `in_progress` ji neposouvá ani se nezapočítává. `completed` ji
  posune. `partial` a `aborted` vyžadují `sequence_decision: repeat|advance`.
- Nikdy nepředepisuj konkrétní váhu. Předepiš série, rozsah opakování a
  cílové RPE. Skutečnou zátěž zapíše uživatel do session logu.
- Knihovna cviků je paměť, ne whitelist. U neznámého cviku použij
  YouTube search URL. Nevymýšlej `youtube.com/watch?v=` odkaz.
- `optional_cardio` nabízej odděleně a nezapočítávej ho do adherence
  silového bloku. `integrated_conditioning` je součást jednotky a musí uvést
  minuty, intenzitu, prodloužení jednotky, dopad na silový a lower-body objem
  a zdůvodnění.
- Zapracuj relevantní položky z `calendar/exceptions.yaml`.

## Schválení, provoz a uzavření

Po připomínkách zapisuj do `Approved Changes` pouze změny, které uživatel
schválil. Po jeho výslovném schválení změň plán na `approved`, pak jej
lze označit jako `active` a propsat `active_block`, `plan_status` a
`block_number` do `_system/state/current.yaml`. Aktivní blok vyžaduje `status: active`
v plánu, `plan_status: active` ve stavu a shodné číslo bloku.

Trénink můžeš zapisovat průběžně přímo do kanonického souboru podle
`_system/templates/session-log.md` se stavem `in_progress`. Takový soubor musí
být posledním session logem, má `credited_strength_session: false`, nemá
`sequence_decision` a nemění `sequence_position` ani `next_session`. Po skončení
jej změň na `completed`, `partial` nebo `aborted` a aktualizuj stav sekvence
podle výsledku. Zrušený termín nevytváří session outcome a stav sekvence nemění.

Na konci vyplň `review.md` podle `_system/templates/block-review.md`. Teprve potom
nastav plán na `completed` a použij review při přípravě dalšího draftu. Po
každé změně spusť `bin/validate`.
