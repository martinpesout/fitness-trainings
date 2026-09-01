---
status: draft
block_number:
planned_duration_weeks:
duration_contract: 3..6
weekly_strength_frequency: 3
target_strength_sessions:
sequence: []
approved_changes: []
---

# Training Block Plan

## Block Intent

- Goal:
- Why this duration and sequence fit the goal, calendar, and recent response:

## Lifecycle

`draft -> approved -> active -> completed`

This plan remains a draft until explicitly approved. Activation changes both this plan's `status` and `_system/state/current.yaml.plan_status` to `active`.

## Duration and Session Target

- `planned_duration_weeks`: choose a whole number from 3 to 6 (default: 4).
- `duration_contract: 3..6`
- `weekly_strength_frequency`: 3 unless this block explicitly changes it.
- `target_strength_sessions = planned_duration_weeks * weekly_strength_frequency`
- Target strength sessions for this block:

## Shared Rules

- Choose loading by target RPE; the plan does not prescribe weights.
- Record actual sets, reps, load, RPE, duration, status, and notes in each session log.
- A cancelled date has no outcome and does not advance the rolling sequence.
- `in_progress` does not advance the sequence or receive session credit. `completed` advances the sequence. `partial` or `aborted` require `sequence_decision: repeat|advance`.

## Session Templates

### Template A

- Focus:

| Exercise | Prescribed sets | Prescribed reps | Target RPE | Notes |
| --- | --- | --- | --- | --- |
| | | | | |

### Template B

- Focus:

| Exercise | Prescribed sets | Prescribed reps | Target RPE | Notes |
| --- | --- | --- | --- | --- |
| | | | | |

### Template C

- Focus:

| Exercise | Prescribed sets | Prescribed reps | Target RPE | Notes |
| --- | --- | --- | --- | --- |
| | | | | |

Add or remove template sections to match the explicit sequence for this 3–6 week block.

## Progression

- Progression approach:
- Criteria to add repetitions, load, or change an exercise:
- Deload or adjustment triggers:

## Optional Cardio

Optional cardio is offered separately at the end of the plan. Optional cardio does not count toward strength-block adherence and may be skipped spontaneously.

- Suggested modality, minutes, and intensity:
- Guardrails:

## Integrated Conditioning

Integrated conditioning is part of a session. For every included conditioning segment, name its minutes and intensity, total-duration impact, strength-volume impact, lower-body impact, and rationale. Heavy legs plus intense cycling needs an explicit rationale; normally lower-body volume is reduced.

If this block has no integrated conditioning, fill every field below with `none`.

- Session template:
- Minutes and intensity:
- Total-duration impact:
- Strength-volume impact:
- Lower-body impact:
- Rationale:

## Approved Changes

Record only changes explicitly approved after this plan was created.

- Date:
- Change and reason:
- Approval:
