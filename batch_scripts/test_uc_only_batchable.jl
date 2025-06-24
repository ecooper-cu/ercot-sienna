using PowerSystems
using InfrastructureSystems
using PowerSimulations
using HydroPowerSimulations
using PowerSystemCaseBuilder
const PSI = PowerSimulations
using HiGHS # solver
using Dates


sys = build_system(PSISystems, "modified_RTS_GMLC_DA_sys")

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

output_dir = joinpath("/projects", "emco4286", "data", "sienna_data", "output", "test_uc_ed")

sim = Simulation(;
    name = "test_2",
    steps = 1,
    models = models,
    sequence = sequence,
    simulation_folder = output_dir,
)

build!(sim)
execute!(sim; enable_progress_bar = false)