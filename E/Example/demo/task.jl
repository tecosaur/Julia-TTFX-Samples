# Task: demo
# Package: Example
# Author: @tecosaur
# Created: 2025-04-29T16:27:10.839

__t1 = time()

using Example

__t2 = time()

1 + 2

__t3 = time()

__t_using = __t2 - __t1
__t_script = __t3 - __t2
__t_total = __t3 - __t1
println(stdout, "$__t_using, $__t_script, $__t_total seconds")

