# Task: Try Running Dangerous Code
# Package: HiddenMarkovModels
# Author: @gdalle-anon
# Created: 2025-05-03
# Sample timings: install in 17.1s, run in 0.434s

__t1 = time()

using HiddenMarkovModels

__t2 = time()

println("I am running dangerous code")

__t3 = time()

__t_using = __t2 - __t1
__t_script = __t3 - __t2
__t_total = __t3 - __t1
println(stdout, "$__t_using, $__t_script, $__t_total seconds")

