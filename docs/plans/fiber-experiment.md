Fiber experiment: add reproducible benchmark comparing ordinary sequential calls with
creating/resuming one Fiber per case, same generated inputs and predicates. Include CPU
and blocking sleep workloads; configurable small runs. No production worker yet.
Document that bare Fibers do not overlap blocking work without a scheduler; using an
external scheduler introduces dependency/lifecycle/cancellation decisions. Validate same
successful count and deterministic failure+shrinking by running each predicate inside a Fiber.
Decision: keep :none/:ractor for v1; revisit scheduler-backed worker for concrete IO use case.

Completed: red specs committed a439561; adapter and benchmark added.
The existing halving strategy reaches 7 (not global minimum 5) with seed42;
regression expectation corrected to the serial baseline. Full rake: 183 examples,
0 failures; Standard passes. Smoke benchmark recorded in benchmark/FIBER.md.
