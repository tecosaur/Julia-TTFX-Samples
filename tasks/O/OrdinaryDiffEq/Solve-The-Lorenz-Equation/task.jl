# Task: Solve The Lorenz Equation
# Package: OrdinaryDiffEq
# Author: @ChrisRackauckas
# Attribution: The README of OrdinaryDiffEq
# Created: 2025-05-13
# Sample timings: install in 260.2s, run in 4.411s

__t1 = time()

using OrdinaryDiffEq

__t2 = time()

function lorenz!(du, u, p, t)
    du[1] = 10.0(u[2] - u[1])
    du[2] = u[1] * (28.0 - u[3]) - u[2]
    du[3] = u[1] * u[2] - (8 / 3) * u[3]
end
u0 = [1.0; 0.0; 0.0]
tspan = (0.0, 100.0)
prob = ODEProblem(lorenz!, u0, tspan)
sol = solve(prob, Tsit5())

__t3 = time()

__t_using = __t2 - __t1
__t_script = __t3 - __t2
__t_total = __t3 - __t1
println(stdout, "$__t_using, $__t_script, $__t_total seconds")

