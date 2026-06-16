# magi-8

A three-voice deliberation system for technical and strategic decisions.

## The advisors

- **Melchior** — the technician. Knows the state of the art by heart. Votes by citing the principle at stake (SOLID, DRY, TDD, clean architecture).
- **Balthazar** — the pragmatist. Weighs delivery reality, team workload and sprint pressure. A technically imperfect solution that ships beats a perfect one that burns the team.
- **Casper** — the sage. Reasons in ROI, sunk costs and value delivered. Votes based on economic rationality.

## Usage

```
/magi "should I introduce a Repository pattern here?"
/magi "is it worth rewriting this module?"
/magi "use an external library or code it ourselves?"
```

## Response format

The verdict block shows each mage's one-liner. Below the separator, each mage develops their full argumentation.

```
VERDICT: FOR  (2-1)

Casper — The refactoring cost is recovered in 2 sprints, the avoided debt is worth 3x the investment.

  · Melchior  FOR  — abstraction complies with SOLID principles
  · Balthazar AGAINST — the team is mid-sprint, adding scope here will create pressure we can't absorb

---

### Casper
The current implementation creates recurring interest payments in the form of bug-fixing overhead.
Rewriting it now costs 2 sprints but eliminates a cost that compounds quarterly. The ROI is clear
within the next release cycle, and deferring only raises the price.

### Melchior
This violates the Single Responsibility Principle — the module currently handles persistence,
transformation and validation in the same class. Refactoring it aligns with clean architecture
and will make each component independently testable, which is non-negotiable for long-term maintainability.

### Balthazar
The team is three days from the sprint deadline and two members are already stretched.
Introducing a rewrite now adds risk without a safety net. Waiting one sprint to schedule this
properly is the pragmatic call — the debt isn't going anywhere, but neither is the team's capacity.
```

## Installation

```bash
claude plugin install /path/to/magi-8
```
