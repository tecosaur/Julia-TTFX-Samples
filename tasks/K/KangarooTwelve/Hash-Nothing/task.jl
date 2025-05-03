# Task: Hash Nothing
# Package: KangarooTwelve
# Author: @tecosaur
# Created: 2025-05-03
# Sample timings: install in 23.6s, run in 0.12s

__t1 = time()

using KangarooTwelve

__t2 = time()

k12(UInt8[])

__t3 = time()

__t_using = __t2 - __t1
__t_script = __t3 - __t2
__t_total = __t3 - __t1
println(stdout, "$__t_using, $__t_script, $__t_total seconds")

