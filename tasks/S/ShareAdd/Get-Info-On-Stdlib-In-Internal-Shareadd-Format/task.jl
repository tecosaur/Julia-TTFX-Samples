# Task: Get Info On Stdlib In Internal Shareadd Format
# Package: ShareAdd
# Author: @Eben60
# Created: 2025-05-04
# Sample timings: install in 10.2s, run in 0.893s

__t1 = time()

using ShareAdd

__t2 = time()

ShareAdd.stdlib_env()

__t3 = time()

__t_using = __t2 - __t1
__t_script = __t3 - __t2
__t_total = __t3 - __t1
println(stdout, "$__t_using, $__t_script, $__t_total seconds")

