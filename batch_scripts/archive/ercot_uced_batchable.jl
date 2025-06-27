using PowerSystems
using InfrastructureSystems
using PowerSimulations
using HydroPowerSimulations
using PowerSystemCaseBuilder
const PSI = PowerSimulations
using HiGHS # solver
using Dates


da_file_dir = joinpath("/projects", "emco4286", "data", "sienna_data", "input", "DA_sys", "final_sys_DA.json")
sys_DA = System(da_file_dir)

rt_file_dir = joinpath("/projects", "emco4286", "data", "sienna_data", "input", "RT_sys", "final_sys_RT.json")
sys_RT = System(rt_file_dir)

template_uc = template_unit_commitment(network=NetworkModel(CopperPlatePowerModel, use_slacks = true))
template_ed = template_economic_dispatch(network=NetworkModel(CopperPlatePowerModel, use_slacks = true))

solver = optimizer_with_attributes(HiGHS.Optimizer, "mip_rel_gap" => 0.5)

models = SimulationModels(;
    decision_models = [
        DecisionModel(template_uc, sys_DA; optimizer = solver, name = "UC"),
        DecisionModel(template_ed, sys_RT; optimizer = solver, name = "ED"),
    ],
)

feedforward = Dict(
    "ED" => [
        SemiContinuousFeedforward(;
            component_type = ThermalStandard,
            source = OnVariable,
            affected_values = [ActivePowerVariable],
        ),
    ],
)

sequence = SimulationSequence(;
    models = models,
    ini_cond_chronology = InterProblemChronology(),
    feedforwards = feedforward,
)

output_dir = joinpath("/projects", "emco4286", "data", "sienna_data", "output", "ercot", "uced")

sim = Simulation(;
    name = "ercot",
    steps = 2,
    models = models,
    sequence = sequence,
    simulation_folder = output_dir,
)

build!(sim)
execute!(sim; enable_progress_bar = false)