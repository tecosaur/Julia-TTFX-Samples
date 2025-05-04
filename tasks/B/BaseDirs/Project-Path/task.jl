# Task: Project Path
# Package: BaseDirs
# Author: @tecosaur
# Created: 2025-05-04
# Sample timings: install in 6.4s, run in 0.023s

__t1 = time()

using BaseDirs

__t2 = time()

BaseDirs.User.data(BaseDirs.Project("MyProject"))

__t3 = time()

__t_using = __t2 - __t1
__t_script = __t3 - __t2
__t_total = __t3 - __t1
println(stdout, "$__t_using, $__t_script, $__t_total seconds")

