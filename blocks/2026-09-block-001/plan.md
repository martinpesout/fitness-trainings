---
status: active
block_number: 1
start_date: 2026-09-02
planned_end_date: 2026-09-29
planned_duration_weeks: 4
duration_contract: 3..6
weekly_strength_frequency: 3
target_strength_sessions: 12
sequence:
  - A
  - B
  - C
approved_changes:
  - "2026-09-01: Povolen průběžný session log se stavem in_progress bez posunu sekvence."
  - "2026-09-01: K Romanian deadlift doplněn uživatelem poskytnutý odkaz na techniku."
---

# Tréninkový blok 001: síla, kruhy a prostor pro kondici

## Block Intent

- Cíl: rozvíjet sílu na základních cvicích, udržet práci s vlastní
  vahou a ponechat dostatek regenerace pro volitelný běh nebo cyklistiku.
- Blok navazuje na dobrý pocit a sílu po letním programu, ale neopakuje
  jeho celou skladbu. Jako sezónní kotvy zůstávají Ring chin-up a Strict
  ring dips; ostatní hlavní cviky se mění.
- Čtyři týdny jsou prvním kontrolovatelným obdobím tohoto systému. Od
  2. do 29. 9. 2026 obsahují 12 silových jednotek. Nahlášený výpadek
  6.–7. 10. 2026 leží mimo tento blok.
- Každá jednotka má cílovou délku 50–75 minut.

## Lifecycle

`draft -> approved -> active -> completed`

Uživatel tento plán schválil a aktivoval 1. 9. 2026. Aktivní stav a
pozici průběžné sekvence uchovává `_system/state/current.yaml`.

## Duration and Session Target

- Začátek: 2. 9. 2026
- Plánovaný konec: 29. 9. 2026
- Délka: 4 týdny
- Frekvence: 3 silové jednotky týdně
- Sekvence: A → B → C, průběžně bez resetu podle kalendářního týdne
- Cíl: 12 dokončených silových jednotek

## Shared Rules

- Plán neurčuje konkrétní váhy. Zátěž zvol podle cílového RPE a
  skutečnou hodnotu zapiš až do session logu.
- Rozsah opakování a cílové RPE platí současně. Ukonči sérii v
  předepsaném rozsahu při dosažení cílového RPE. Nepokračuj nad horní
  hranici jen proto, abys dosáhl vyššího RPE.
- RPE 8 zde znamená přibližně dvě technicky čistá opakování v rezervě.
  Trénink do selhání není v tomto bloku předepsaný.
- Před prvním hlavním cvikem proveď 2–4 postupné rozehřívací série.
  Indoor trenažér není povinný warm-up; 5–8 velmi lehkých minut lze
  použít pouze podle teploty a chuti.
- Dokončená jednotka posune sekvenci. Zrušený termín ji neposune.
  `in_progress` je pouze průběžný zápis a sekvenci neposune. `partial` nebo
  `aborted` vyžaduje rozhodnutí `repeat` nebo `advance`.
- Zapiš skutečné série, opakování, zátěž, RPE, délku, stav a poznámky.
- Před cviky na kruzích zkontroluj popruhy, upevnění a stejnou výšku
  obou kruhů. U Back squatu nastav bezpečnostní ramena.

## Session Templates

### Template A

- Zaměření: síla dolní poloviny těla a stabilita trupu
- Očekávaná délka: 55–70 minut

| Exercise | Prescribed sets | Prescribed reps | Target RPE | Notes |
| --- | --- | --- | --- | --- |
| Back squat | 3 | 4–6 | 7–8 | Pauza 2,5–3 minuty; použij safety arms |
| Romanian deadlift | 3 | 6–8 | 8 | Pauza 2–3 minuty; ukonči při ztrátě stabilní pozice trupu; [technika](https://www.youtube.com/shorts/oQwnGfZFfzw) |
| Barbell reverse lunge | 2 | 8 na každou stranu | 8 | Pauza 90–120 sekund; kontrolovaný krok vzad |
| Long-lever plank | 3 | 20–40 sekund | 8 | Pauza 60–90 sekund; [technika](https://www.youtube.com/results?search_query=long+lever+plank+proper+form) |

### Template B

- Zaměření: kruhy, kalistenická síla a střed těla
- Očekávaná délka: 50–60 minut

| Exercise | Prescribed sets | Prescribed reps | Target RPE | Notes |
| --- | --- | --- | --- | --- |
| 1A · Ring chin-up | 3 | 5–8 | 8 | První cvik supersérie; po sérii bezpečně přejdi na 1B |
| 1B · Strict ring dips | 3 | 5–8 | 8 | Druhý cvik supersérie; potom pauza 2–3 minuty a návrat na 1A |
| Ring row | 3 | 8–12 | 8 | Pauza 90 sekund; obtížnost uprav polohou chodidel |
| Hanging knee raise | 3 | 8–12 | 8 | Pauza 60–90 sekund; bez švihu; [technika](https://www.youtube.com/results?search_query=hanging+knee+raise+proper+form) |

### Template C

- Zaměření: síla tahu a tlaků horní poloviny těla
- Očekávaná délka: 55–70 minut

| Exercise | Prescribed sets | Prescribed reps | Target RPE | Notes |
| --- | --- | --- | --- | --- |
| Deadlift | 2 | 3–5 | 7–8 | Pauza 3 minuty; nižší objem chrání regeneraci před dalším A |
| Incline dumbbell bench press | 3 | 6–10 | 8 | Pauza 2 minuty; stabilní opora o lavici |
| Pendlay row | 3 | 6–8 | 8 | Pauza 2 minuty; každé opakování začíná z podlahy |
| Z-press | 2 | 6–8 | 8 | Pauza 2 minuty; ukonči sérii při ztrátě vzpřímené pozice |

## Progression

- Při první A, B a C zvol zátěž nebo obtížnost, která dovolí
  spodní hranici rozsahu při cílovém RPE.
- Při dalším výskytu stejné šablony nejprve přidávej opakování.
  Jakmile zvládneš horní hranici ve všech pracovních sériích při
  předepsaném RPE, příště zvol nejmenší praktické zvýšení zátěže
  a vrať se ke spodní hranici.
- U Ring row zvyš obtížnost posunem chodidel. U Ring chin-up a Strict
  ring dips přidej zátěž pomocí dip beltu až tehdy, když zvládneš všechny
  série na horní hranici při RPE nejvýše 8 a stabilní technice.
- U Long-lever planku po zvládnutí 3 × 40 sekund při RPE nejvýše 8
  posuň lokty o malý kus dopředu a vrať se přibližně k 20 sekundám.
- Pokud dvě po sobě jdoucí jednotky překročí cílové RPE o více než
  jeden bod, klesá počet opakování, zhoršuje se technika nebo se objeví
  bolest, sniž zátěž nebo odeber jednu pracovní sérii. Změnu zapiš.
- Čtvrtý týden není automatický deload. O úpravě rozhodne skutečná
  únava a výkon v session logu.

## Optional Cardio

Volitelné kardio není součástí adherence silového bloku a můžeš je
spontánně vynechat.

- Doporučená modalita: venkovní běh, silniční nebo trekové kolo
- Orientační délka: 20–60 minut
- Intenzita: lehká až střední, přibližně RPE 4–6
- Bez pevně určeného dne nebo počtu jednotek. Pokud zůstává únava nohou
  před A nebo C, kardio zkrať, zvolni nebo vynech.
- Indoor cyklistika se v tomto bloku nepředepisuje jako samostatná jednotka.

## Integrated Conditioning

- Status: none
- Rationale: none; teplota zatím nepřeje delší indoor cyklistice a první blok má vytvořit čistý silový baseline

## Approved Changes

- Draft byl 1. 9. 2026 schválen beze změn.
- Dne 1. 9. 2026 byl schválen průběžný zápis přímo do session logu
  se stavem `in_progress`. Nemění obsah tréninku ani pozici sekvence.
- Dne 1. 9. 2026 byl k Romanian deadlift doplněn uživatelem poskytnutý
  odkaz na techniku. Ukázka používá jednoručky, princip pohybu je stejný.
