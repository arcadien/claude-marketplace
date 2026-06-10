# magi-7

A three-voice deliberation system for technical and strategic decisions.

## The advisors

- **Gaspard** — the proceduralist. Knows the state of the art by heart. Never deviates from standards (SOLID, DRY, TDD).
- **Melchior** — the yolo. Does the minimum to make it work. Elegance is irrelevant.
- **Balthazar** — the sage. Reasons in ROI, sunk costs and value delivered. Votes based on economic rationality.

## Usage

```
/magi "should I introduce a Repository pattern here?"
/magi "is it worth rewriting this module?"
/magi "use an external library or code it ourselves?"
```

## Response format

The majority verdict is displayed prominently. The minority appears indented.

```
VERDICT: FOR  (2-1)

Balthazar — The refactoring cost is recovered in 2 sprints, the avoided debt is worth 3x the investment.

  · Gaspard  FOR  — abstraction complies with SOLID principles
  · Melchior AGAINST — it already works, every added line is a risk
```

## Installation

```bash
claude plugin install /path/to/magi-7
```
