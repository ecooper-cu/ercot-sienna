using PowerSystems
using InfrastructureSystems
using PowerSimulations
using HydroPowerSimulations
using PowerSystemCaseBuilder
const PSI = PowerSimulations
using HiGHS # solver
using Dates


sys_DA = build_system(PSISystems, "modified_RTS_GMLC_DA_sys")
sys_RT = build_system(PSISystems, "modified_RTS_GMLC_RT_sys")

template_uc = template_unit_commitment(network=NetworkModel(CopperPlatePowerModel, use_slacks = true))
template_ed = template_economic_dispatch(network=NetworkModel(CopperPlatePowerModel, use_slacks = true))

components = [Area, FixedAdmittance, HydroDispatch, PowerLoad, RenewableDispatch, RenewableNonDispatch, VariableReserve]

for c in components
    for g in get_components(x -> has_time_series(x), c, sys_RT)
        remove_time_series!(sys_RT, DeterministicSingleTimeSeries, g, "max_active_power")
    end
end

transform_single_time_series!(
           sys_RT,
           Dates.Hour(1), # horizon
           Dates.Minute(5), # interval
       );

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

output_dir = joinpath("/projects", "emco4286", "data", "sienna_data", "output", "test", "uced")

sim = Simulation(;
    name = "test",
    steps = 2,
    models = models,
    sequence = sequence,
    simulation_folder = output_dir,
)

build!(sim)
execute!(sim; enable_progress_bar = false)