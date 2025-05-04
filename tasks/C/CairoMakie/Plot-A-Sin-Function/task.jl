# Task: Plot A Sin Function
# Package: CairoMakie
# Author: @Klafyvel
# Created: 2025-05-04
# Sample timings: install in 370.7s, run in 6.344s

__t1 = time()

using CairoMakie

__t2 = time()

lines(-π..π, sin)

__t3 = time()

__t_using = __t2 - __t1
__t_script = __t3 - __t2
__t_total = __t3 - __t1
println(stdout, "$__t_using, $__t_script, $__t_total seconds")

