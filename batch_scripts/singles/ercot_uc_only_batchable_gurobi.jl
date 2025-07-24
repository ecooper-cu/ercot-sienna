using Pkg
Pkg.activate("/projects/emco4286/software/julia/MyProject")

using PowerSystems, PowerSimulations, InfrastructureSystems, HydroPowerSimulations, PowerSystemCaseBuilder, SiennaPRASInterface, PRASCore

const PSI = PowerSimulations
const PSY = PowerSystems
const IS = InfrastructureSystems

using Gurobi, JuMP

using CSV, DataFrames, Dates, TimeSeries, DataStructures, JSON, Plots, Random, Glob, Printf, Base.Iterators

using Statistics, Distributions

file_dir = joinpath("/projects", "emco4286", "data", "sienna_data", "input", "DA_sys", "final_sys_DA.json")
sys = System(file_dir)

PSY.transform_single_time_series!(sys, Hour(48), Hour(24))

template_uc = PSI.template_unit_commitment(network=NetworkModel(CopperPlatePowerModel))
PSI.set_device_model!(template_uc, ThermalMultiStart, ThermalStandardUnitCommitment)
PSI.set_device_model!(template_uc, ThermalStandard, ThermalStandardUnitCommitment)

solver = PSI.optimizer_with_attributes(Gurobi.Optimizer)
set_optimizer_attribute(solver, "MIPGap", 0.05)

output_dir = joinpath("/projects", "emco4286", "data", "sienna_data", "output", "ercot", "baseline")

problem = DecisionModel(template_uc, sys; optimizer = solver, name = "UC")
# serialize_optimization_model(problem, joinpath(output_dir, "optimization_problem.mof.json"))

models = SimulationModels(;
    decision_models = [problem],
)

sequence = SimulationSequence(;
    models = models,
    ini_cond_chronology = InterProblemChronology(),
)

sim = Simulation(;
    name = "uc_only_gurobi",
    steps = 365,
    models = models,
    sequence = sequence,
    simulation_folder = output_dir,
)

build!(sim)
execute!(sim; enable_progress_bar = false)