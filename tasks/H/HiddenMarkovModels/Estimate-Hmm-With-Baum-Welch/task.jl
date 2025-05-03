# Task: Estimate Hmm With Baum-Welch
# Package: HiddenMarkovModels
# Dependencies: Distributions
# Author: @gdalle
# Attribution: Guillaume Dalle
# Created: 2025-05-03
# Sample timings: install in 24.2s, run in 3.969s

__t1 = time()

using Distributions, HiddenMarkovModels
using HiddenMarkovModels
using Distributions

__t2 = time()

init = [0.6, 0.4]
trans = [0.7 0.3; 0.2 0.8]
dists = [Normal(-1.0), Normal(1.0)]
hmm = HMM(init, trans, dists)
state_seq, obs_seq = rand(hmm, 100)
baum_welch(hmm, obs_seq)

__t3 = time()

__t_using = __t2 - __t1
__t_script = __t3 - __t2
__t_total = __t3 - __t1
println(stdout, "$__t_using, $__t_script, $__t_total seconds")

