# Task: Plot A Sine Wave
# Package: CairoMakie
# Author: @Klafyvel
# Created: 2025-05-10
# Sample timings: install in 368.8s, run in 6.334s

__t1 = time()

using CairoMakie

__t2 = time()

lines(-π..π, sin)

__t3 = time()

__t_using = __t2 - __t1
__t_script = __t3 - __t2
__t_total = __t3 - __t1
println(stdout, "$__t_using, $__t_script, $__t_total seconds")

