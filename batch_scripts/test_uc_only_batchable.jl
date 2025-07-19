using PowerSystems, InfrastructureSystems, PowerSimulations, HydroPowerSimulations, PowerSystemCaseBuilder, SiennaPRASInterface
using Gurobi, JuMP # solver
using CSV, DataFrames, Dates, TimeSeries, DataStructures
using Dates

const PSI = PowerSimulations
const PSY = PowerSystems

sys = build_system(PSITestSystems, "RTS_GMLC_DA_sys")

PSY.transform_single_time_series!(sys, Hour(48), Hour(24))

template_uc = template_unit_commitment(network=NetworkModel(CopperPlatePowerModel, use_slacks = true))

solver = optimizer_with_attributes(Gurobi.Optimizer)
set_optimizer_attribute(solver, "MIPGap", 0.5)

problem = DecisionModel(template_uc, sys; optimizer = solver, name = "UC", store_variable_names=true)

models = SimulationModels(;
    decision_models = [problem],
)

sequence = SimulationSequence(;
    models = models,
    ini_cond_chronology = InterProblemChronology(),
)

output_dir = joinpath("/projects", "emco4286", "data", "sienna_data", "output", "test", "uc_only_gurobi")

sim = Simulation(;
    name = "unmodified_baseline_for_test_outages",
    steps = 1,
    models = models,
    sequence = sequence,
    simulation_folder = output_dir,
)

build!(sim)
execute!(sim; enable_progress_bar = false)