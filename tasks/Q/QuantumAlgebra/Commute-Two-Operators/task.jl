# Task: Commute Two Operators
# Package: QuantumAlgebra
# Author: @jfeist
# Created: 2025-05-10
# Sample timings: install in 29.2s, run in 0.373s

__t1 = time()

using QuantumAlgebra

__t2 = time()

@boson_ops b
normal_form(b(:i)*a'(:j)) == a'(:j)*b(:i)

__t3 = time()

__t_using = __t2 - __t1
__t_script = __t3 - __t2
__t_total = __t3 - __t1
println(stdout, "$__t_using, $__t_script, $__t_total seconds")

