using PowerSystems
using InfrastructureSystems
using PowerSimulations
using HydroPowerSimulations
using PowerSystemCaseBuilder
using Gurobi, JuMP # solver
using Dates

const PSY = PowerSystems

file_dir = joinpath("/projects", "emco4286", "data", "sienna_data", "input", "DA_sys", "final_sys_DA.json")
sys = System(file_dir)

PSY.transform_single_time_series!(sys, Hour(48), Hour(24))

template_uc = template_unit_commitment(network=NetworkModel(CopperPlatePowerModel, use_slacks = true))

solver = optimizer_with_attributes(Gurobi.Optimizer)
set_optimizer_attribute(solver, "MIPGap", 0.5)

problem = DecisionModel(template_uc, sys; optimizer = solver, name = "UC")

models = SimulationModels(;
    decision_models = [problem],
)

sequence = SimulationSequence(;
    models = models,
    ini_cond_chronology = InterProblemChronology(),
)

output_dir = joinpath("/projects", "emco4286", "data", "sienna_data", "output", "ercot", "uc_only")

sim = Simulation(;
    name = "uc_only_gurobi",
    steps = 365,
    models = models,
    sequence = sequence,
    simulation_folder = output_dir,
)

build!(sim)
execute!(sim; enable_progress_bar = false)