# Historické tréninkové bloky

Adresář `history/blocks/` obsahuje tréninkové bloky z doby před spuštěním
tohoto systému.

## Co sem patří

- jeden soubor nebo adresář pro každý historický blok,
- původní exporty, PDF nebo přepsané blokové plány,
- cviky, předepsané série, opakování a další dostupné informace o bloku.

Doporučené názvy:

- `2022-01--2022-03.md`
- `2023-04-strength.pdf`
- `2024-winter-cycling/`

## Jak historii interpretovat

Historický plán dokládá pouze to, co bylo předepsáno. Nedokládá, že byl
trénink skutečně absolvován, s jakou zátěží ani s jakým výsledkem.

Chybějící informace se nedoplňují odhadem.

## Co sem nepatří

- zpětně vytvářené záznamy jednotlivých tréninků,
- nové session logy,
- souhrnné závěry odvozené z historie.

Staré jednotlivé tréninky se nepřepisují do samostatných souborů.

## Zpracování historie

AI může historické bloky přečíst při onboardingu nebo při výslovném
požadavku na nové zpracování historie.

Odvozené a uživatelem potvrzené poznatky se zapisují do
`data/history_summary.md`. Původní soubory v `history/blocks/` zůstávají
beze změny.

Běžné generování dalších plánů používá `data/history_summary.md`, nikoli
opakované načítání celé historické složky.
