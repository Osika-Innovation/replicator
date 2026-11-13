# Current state

**Reviewed November 13, 2026.** This is the navigation checkpoint for the programme, not a hardware release.

## Published code and active studies

| Area | Current record | Next decision |
|---|---|---|
| Public engineering code | This handbook was prepared against published revision `1b708a2`; its twin includes simulation, CAD and numerical checks | Review later engineering branches for integration |
| Acoustic architecture | Few high-power inputs into optimized bodies is the preferred candidate; 3 + 3 is a comparison starting point | Resolve source/body coupling and qualify a reusable calibration setup |
| Platform software | Active workspace studies extend backend, calibration, body-response and upgrade interfaces | Publish reviewed implementations with their receipts |
| Electromagnetics | November 13 branch study recommends no EM process module for the first acoustic build; contactless disc metrology remains a candidate | Accept or decline the instrument against the acoustic measurement need |
| Manufacturing | Feed, joining and inspection must be selected with the first useful part | Establish one complete material transformation |
| Material/AI representation | Module/material records and optional learned proposal policies are development work | Demonstrate one module and one bounded task |
| Physics framework | [OPH](oph.html) supplies a theoretical framework and design inspiration; mathematical results retain their assumptions and physical interpretations retain their test status | Map a specific hypothesis to a measurable response and compare it with established models |
| Hardware evidence | No integrated Replicator bench demonstration has been established in this documentation review | Produce calibrated physical receipts |

Detailed branch results retain their original scope. A proposed configuration, passing simulation or exported STEP assembly does not release hardware for ordering.

## Evidence vocabulary

| Label | Meaning |
|---|---|
| Design decision | The direction or requirement the programme has chosen |
| Derived | A calculation with stated assumptions and units |
| Simulated | A result from a specified numerical model |
| Published experiment | A result reported by an identified external source |
| Bench measured | A project measurement with apparatus, calibration and raw records |
| Research hypothesis | A proposed mechanism or explanatory model with a discriminating test |

Writing should be direct: state the design, the result and the next action. Put qualifications where they identify a real dependency or limit.

## Promotion gates

A source enters the library with its identity and review depth. A model earns use through comparison and validity checks. Hardware earns a capability through a repeatable task and inspection. An upgrade earns adoption through a measured improvement.

Published experimental results remain attributed to their authors. Source reports and physical measurements are not interchangeable.

## Maintenance

Update this page when a decision or integration changes. Use a source revision and review date; do not copy transient test counts into the homepage. The [agent guide](agents.html) defines ownership and the [catalog](../catalog.json) gives every document a stable ID.
