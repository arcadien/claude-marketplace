---
name: magi
description: MAGI vote orchestrator — dispatches Melchior, Balthazar and Casper in parallel on a submitted question and formats the verdict according to the majority. Use when a technical or strategic decision deserves three independent perspectives.
---

# MAGI Deliberation

Question submitted: **$ARGUMENTS**

## Step 1 — Parallel dispatch

Launch the three agents **in parallel** (in the same message, three simultaneous Agent calls) with this identical prompt for each:

> Here is the decision submitted for deliberation: $ARGUMENTS
>
> Respond only according to your personality and your strict format.

Agents: `magi:melchior`, `magi:balthazar`, `magi:casper`

## Step 2 — Vote count

Each agent returns `FOR — reason` or `AGAINST — reason`.

Tally:
- 3 FOR → unanimous FOR
- 3 AGAINST → unanimous AGAINST
- 2 FOR / 1 AGAINST → majority FOR (2-1)
- 1 FOR / 2 AGAINST → majority AGAINST (2-1)

## Step 3 — Majority spokesperson selection

The spokesperson is the majority agent whose domain best matches the nature of the question:
- Technical question (architecture, patterns, refactoring, code quality) → Melchior takes priority
- Pragmatism, delivery or team question (deadline, workload, sprint, feasibility) → Balthazar takes priority
- Economic or strategic question (value, ROI, priority, sunk cost) → Casper takes priority

If the priority agent is in the minority, take the other majority member.
In case of unanimity, apply the same priority rule.

## Step 4 — Output format

Each agent response has two parts: a verdict line and an argumentation block. Use both in the output.

**2-1 case:**

```
VERDICT: [FOR/AGAINST]  (2-1)

[Spokesperson name] — [their verdict line]

  · [Agent 2 name]  [FOR/AGAINST]  — [their verdict line]
  · [Agent 3 name]  [FOR/AGAINST]  — [their verdict line]

---

### [Spokesperson name]
[their argumentation]

### [Agent 2 name]
[their argumentation]

### [Agent 3 name]
[their argumentation]
```

**Unanimous case:**

```
VERDICT: [FOR/AGAINST]  (unanimous)

[Spokesperson name] — [their verdict line]

---

### [Melchior name]
[their argumentation]

### [Balthazar name]
[their argumentation]

### [Casper name]
[their argumentation]
```

All three argumentations always appear, regardless of vote outcome.
