# Task: Get Properties Of A Chemical Element
# Package: Mendeleev
# Author: @Eben60
# Created: 2025-05-04
# Sample timings: install in 32.0s, run in 3.412s

__t1 = time()

using Mendeleev
using Mendeleev: calculated_properties

__t2 = time()

Cl = chem_elements.Cl
Cl.eneg
Cl.isotopes

for cp in calculated_properties
    getproperty(Cl, cp)
end

__t3 = time()

__t_using = __t2 - __t1
__t_script = __t3 - __t2
__t_total = __t3 - __t1
println(stdout, "$__t_using, $__t_script, $__t_total seconds")

