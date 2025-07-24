using Distributed

@everywhere using Pkg
@everywhere Pkg.activate("/projects/emco4286/software/julia/MyProject")

@everywhere using Printf, ClusterManagers, Distributed

# https://discourse.julialang.org/t/packages-arent-found-on-worker-processors/46820/10
addprocs(SlurmManager(8), topology=:master_worker, exeflags="--project", dir="/projects/emco4286/software/julia/MyProject")
wids = workers()

@everywhere function run_simulation(x)
    fname = @sprintf("medians_%s.json", x)
    return fname
end

@sync begin
    for i in 2:10
        wid = wids[mod1(i, length(wids))]
        @async remotecall_wait(run_simulation, wid, i)
    end
end