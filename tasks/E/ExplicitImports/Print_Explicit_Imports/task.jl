# Task: `Print_Explicit_Imports`
# Package: ExplicitImports
# Author: @ericphanson
# Created: 2025-05-04
# Sample timings: install in 31.3s, run in 1.26s

__t1 = time()

using ExplicitImports

__t2 = time()

print_explicit_imports(ExplicitImports)

__t3 = time()

__t_using = __t2 - __t1
__t_script = __t3 - __t2
__t_total = __t3 - __t1
println(stdout, "$__t_using, $__t_script, $__t_total seconds")

