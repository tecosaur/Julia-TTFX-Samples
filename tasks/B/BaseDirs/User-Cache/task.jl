# Task: User Cache
# Package: BaseDirs
# Author: @tecosaur
# Created: 2025-05-03
# Sample timings: install in 5.928s, run in 0.02s

__t1 = time()

using BaseDirs

__t2 = time()

BaseDirs.User.cache()

__t3 = time()

__t_using = __t2 - __t1
__t_script = __t3 - __t2
__t_total = __t3 - __t1
println(stdout, "$__t_using, $__t_script, $__t_total seconds")

