# Task: Get cache
# Package: BaseDirs
# Dependencies: 
# Author: @tecosaur
# Created: 2025-04-28T16:40:05.132

__t1 = time()


__t2 = time()

BaseDirs.User.cache()```
__t3 = time()

__t_using = __t2 - __t1
__t_script = __t3 - __t2
__t_total = __t3 - __t1
println(stdout, "($__t_using, __t_script, __t_total) seconds")

