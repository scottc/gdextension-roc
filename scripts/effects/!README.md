This directory is for platform helper modules, that may contain side effects, and are candidates for being promoted to being merged into the platform or host.

Supplimentry logic for interacting with platforms.

The goal is to try de-couple the pure behaviour from the impure behaviour, and move the resulting code to the appropriate places.

This will allow the code to be more portable, and not coupled to a specific platform or effect.
