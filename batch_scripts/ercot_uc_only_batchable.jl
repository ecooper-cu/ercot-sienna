using PowerSystems
using InfrastructureSystems
using PowerSimulations
using HydroPowerSimulations
using PowerSystemCaseBuilder
using HiGHS # solver
using Dates


file_dir = joinpath("/projects", "emco4286", "data", "sienna_data", "input", "final_sys_DA.json")
sys = System(file_dir)

template_uc = template_unit_commitment(network=NetworkModel(CopperPlatePowerModel, use_slacks = true))
solver = optimizer_with_attributes(HiGHS.Optimizer, "mip_rel_gap" => 0.5)
problem = DecisionModel(template_uc, sys; optimizer = solver, horizon = Hour(24), name = "UC")

models = SimulationModels(;
    decision_models = [problem],
)

sequence = SimulationSequence(;
    models = models,
    ini_cond_chronology = InterProblemChronology(),
)

output_dir = joinpath("/projects", "emco4286", "data", "sienna_data", "output", "ercot", "uc_only")

sim = Simulation(;
    name = "uc_only",
    steps = 1,
    models = models,
    sequence = sequence,
    simulation_folder = output_dir,
)

build!(sim)
execute!(sim; enable_progress_bar = false)