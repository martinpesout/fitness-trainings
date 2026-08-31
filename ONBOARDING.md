# Onboarding

První draft vytvoř až po dokončení tohoto checklistu.

- [ ] V `data/profile.yaml` zkontroluj cíle, frekvenci a délku jednotky.
- [ ] S uživatelem projdi zdravotní omezení. Po jeho potvrzení nastav
  `health.review_status: confirmed`.
- [ ] V `data/equipment.yaml` zapiš dostupné vybavení a jeho omezení. Po
  kontrole nastav `review_status: confirmed`.
- [ ] Doplň `data/preferences.md`: co tě baví, čemu se chceš vyhnout a co
  chceš zkusit.
- [ ] Volitelně vlož staré bloky do `history/blocks/` podle
  `history/README.md`. Do `data/history_summary.md` z nich zapiš jen souhrny
  bloků: období, zaměření, cviky a předepsané série a opakování. Staré
  jednotlivé tréninky nepřepisuj do `sessions/` a předepsaný plán
  neoznačuj jako absolvovaný výkon.
- [ ] Spusť `bin/validate`. Oprav všechny chyby. Pokud zůstává
  `equipment_needs_input` nebo `health_needs_review`, první draft je stále
  zablokovaný.
- [ ] Nech vygenerovat `blocks/YYYY-MM-block-NNN/plan.md` se stavem `draft`.
- [ ] Zkontroluj záměr, délku, sekvenci, cviky, cílové RPE, výjimky v
  kalendáři a případné kardio. Napiš konkrétní připomínky.
- [ ] Po zapracování změn plán výslovně schval. Teprve potom lze
  změnit stav na `approved` a následně `active`. Při aktivaci nastav také
  `_system/state/current.yaml.plan_status: active`, `active_block` a shodné číslo
  bloku.
