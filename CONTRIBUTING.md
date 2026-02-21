# Contributors' guide

The main goal of this project is to keep things as close
to the documented Gemini API as possible.
It will never try to integrate other Cloud AI APIs,
although it may be used ad part of some other package
that integrates multiple APIs.

Most of the modules are generated at compile time by a set
of macros that takes the official JSON API specification
published by Google.
There is no need for a a build step, and no elixir files
are ever generated during compilation.
This approach allows us to generate more than 95% of the required
modules while keeping the actual source code size extremely small.

Similarly, the documentation is generated automatically from the
JSON API spec.

Contributers may contribute additional "manual module files"
of there is a clear benefit in customizing the code somehow.