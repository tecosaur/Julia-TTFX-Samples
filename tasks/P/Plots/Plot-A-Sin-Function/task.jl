# Task: Plot A Sin Function
# Package: Plots
# Author: @roflmaostc
# Created: 2025-05-04
# Sample timings: install in 166.9s, run in 1.943s

__t1 = time()

using Plots

__t2 = time()

plot(sin)

__t3 = time()

__t_using = __t2 - __t1
__t_script = __t3 - __t2
__t_total = __t3 - __t1
println(stdout, "$__t_using, $__t_script, $__t_total seconds")

