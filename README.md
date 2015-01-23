xtendency
=========

Xtend is a JVM-based language which is well-known in the Eclipse space.
It is especially helpful when implementing code generators (e.g., by offering rich strings)
and model transformations (e.g., by supporting lambda expressions and extensions).

xtendency is a collection of tools that strive to amplify the power of Xtend for the developer. 
Its two main components are briefly described below.

Disclaimer: All code is work in progress. 


Interpreter
===========

xtendency offers a generic Xtend interpreter that can execute uncompiled Xtend code. Built on 
top of the Xbase interpreter, it enables Xtend developers to

- generate code at runtime and execute it right away
- execute Xtend code where the Xtend compiler is not available
- extend the interpreter to manipulate code execution execution, collect runtime information, ...

Features include:
- Full support of the Xtend language (minus Active Annotations)
- Complete Java representations of Xtend classes, enabling the use of reflection on Xtend classes
- Almost unrestricted interaction with existing Java code


Tracer
======

For both model-to-model and model-to-text transformations, the xtendency tracer
collects fine-grain traceability and coverage information, linking between input models,
generator/transformation code and output artifacts.

The developer gets direct feedback on his current implementation, e.g.:
- What does the output look like for the given input? Does the code throw an exception?
- Which expression in the generator and which elements of the input models lead to an actual output code line?
- Which expression in a transformation created which actual output model element?
- Which parts of the resulting artifacts are affected by a certain expression in the generator's code?

The xtendency tool offers a generic API for utilizing the traceability data.
Currently we implemented a viewer for generated source code and support for resulting EMF models.
Additionally xtendency provides the tec-DSL (short for: trace execution context) for configuring
its execution environment.

See https://www.youtube.com/watch?v=39I7V74uLi4#t=2361 for a short demonstration of the tracer functionality from EclipseCon Europe 2014.

