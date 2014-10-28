xtendency
=========

Xtend is a JVM-based language which is well-known in the Eclipse space.
It is especially helpful when implementing code generators (e.g., by offering rich strings)
and model transformations (e.g., by supporting lambda expressions and extensions).

xtendency amplifies the power of Xtend for the developer. It interprets Xtend code and
collects fine-grain traceability and coverage information, linking between input models,
generator/transformation code and output artifacts.

The developer gets direct feedback on his current implementation, e.g.:
- Which expression in the generator and which elements of the input models lead to an actual output code line?
- Which expression in a transformation created which actual output model element?
- Which parts of the resulting artifacts are affected by a certain expression in the generator's code?

The xtendency tool offers a generic API for utilizing the traceability data.
Currently we implemented a viewer for generated source code and support for resulting EMF models.
Additionally xtendency provides the tec-DSL (short for: trace execution context) for configuring
its execution environment.

