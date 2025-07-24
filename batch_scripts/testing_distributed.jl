using Pkg; Pkg.activate("/projects/emco4286/software/julia/MyProject");
using Distributed, ClusterManagers

# https://stackoverflow.com/questions/70792051/package-set-up-not-propagating-to-workers-with-distributed
# https://discourse.julialang.org/t/packages-arent-found-on-worker-processors/46820/10

"""
Configurations tried:
--------------------

using SlurmClusterManager
addprocs(SlurmClusterManager.SlurmManager(), env=["JULIA_PROJECT" => Base.active_project()])

ERROR: On worker 2:
ArgumentError: Package PowerSystems not found in current path.

--------------------

using SlurmClusterManager
addprocs(SlurmClusterManager.SlurmManager(), env=["JULIA_PROJECT" => "/projects/emco4286/software/julia/MyProject"])

ERROR: On worker 2:
ArgumentError: Package PowerSystems not found in current path.
- Run `import Pkg; Pkg.add("PowerSystems")` to install the PowerSystems package.

--------------------

using ClusterManagers
addprocs(SlurmManager(3), dir="/home/emco4286/tmp", env=["JULIA_PROJECT" => Base.active_project()])

ERROR: On worker 2:
ArgumentError: Package PowerSystems not found in current path.

--------------------
using ClusterManagers
addprocs_slurm(3, dir="/home/emco4286/tmp", env=["JULIA_PROJECT" => Base.active_project()])

--------------------

using ClusterManagers
addprocs(3) # , dir=Base.active_project())

--------------------

using ClusterManagers
addprocs(3, output="/home/emco4286/tmp")

using ClusterManagers

manager = manager = LocalManager(np, true)
check_addprocs_args(manager, kwargs)
addprocs(manager; kwargs...)

project = Base.ACTIVE_PROJECT[]
env["JULIA_PROJECT"] = project

"""

# @everywhere using Pkg; Pkg.activate("/projects/emco4286/software/julia/MyProject")
# @everywhere using PowerSystems
# @everywhere const PSY = PowerSystems


# PowerSimulations, InfrastructureSystems, HydroPowerSimulations, PowerSystemCaseBuilder, SiennaPRASInterface, PRASCore, CSV, DataFrames, Dates, TimeSeries, DataStructures, JSON, Glob, Printf, Base.Iterators, ArgParse, JuMP, Gurobi, Distributed, ClusterManagers

@everywhere begin
    using Pkg; Pkg.activate("/projects/emco4286/software/julia/MyProject")
    using PowerSystems, PowerSimulations, InfrastructureSystems, HydroPowerSimulations, PowerSystemCaseBuilder, SiennaPRASInterface, PRASCore, CSV, DataFrames, Dates, TimeSeries, DataStructures, JSON, Glob, Printf, Base.Iterators, ArgParse, JuMP, Gurobi, Distributed, ClusterManagers

    const PSI = PowerSimulations
    const PSY = PowerSystems
    const IS = InfrastructureSystems
    const ENV = Gurobi.Env()

    const system_dir = joinpath("/projects", "emco4286", "data", "sienna_data", "input", "DA_sys", "final_sys_DA.json")
    const scenario_dir = joinpath("/projects", "emco4286", "data", "scenarios", "median")
    const availability_save_dir = joinpath("/projects", "emco4286", "data", "available_capacity", "medians")
    const sim_save_dir = joinpath("/projects", "emco4286", "data", "sienna_data", "output", "ercot", "scenarios")
    const sys = System(system_dir)
end

@everywhere function run_simulation(x)
    print(x)

    sys2 = PSY.fast_deepcopy_system(sys, skip_time_series=false, skip_supplemental_attributes=false);

    PSY.transform_single_time_series!(sys2, Hour(48), Hour(24))

    template_uc = template_unit_commitment(network=NetworkModel(CopperPlatePowerModel, use_slacks=true))

    optimizer = () -> Gurobi.Optimizer(ENV)
    solver = PSI.optimizer_with_attributes(optimizer)
    set_optimizer_attribute(solver, "MIPGap", 0.5)

    problem = DecisionModel(template_uc, sys2; optimizer = solver, name = "UC")

    models = SimulationModels(;
        decision_models = [problem],
    )

    sequence = SimulationSequence(;
        models = models,
        ini_cond_chronology = InterProblemChronology(),
    )

    # Build simulation
    fname = @sprintf("testing_%s", x)

    sim = Simulation(;
        name = fname,
        steps = 365,
        models = models,
        sequence = sequence,
        simulation_folder = sim_save_dir,
    )

    build!(sim)

    execute!(sim)
end

wids = workers()

# @sync begin
#     for i in 1:3
#         wid = wids[mod1(i, length(wids))]
#         @async remotecall_wait(run_simulation, wid, i)
#     end
# end

pmap(run_simulation, wids)
rmprocs(workers())