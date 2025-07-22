using Pkg
Pkg.activate("/projects/emco4286/software/julia/MyProject")

using PowerSystems, PowerSimulations, InfrastructureSystems, HydroPowerSimulations, PowerSystemCaseBuilder, SiennaPRASInterface, PRASCore

const PSI = PowerSimulations
const PSY = PowerSystems
const IS = InfrastructureSystems

using Gurobi, JuMP

using CSV, DataFrames, Dates, TimeSeries, DataStructures, JSON, Plots, Random, Glob, Printf, Base.Iterators

using Statistics, Distributions, ExpectationMaximization

file_dir = joinpath("/projects", "emco4286", "data", "sienna_data", "input", "DA_sys", "final_sys_DA.json")
sys = System(file_dir)

fs_table = PSY.get_forecast_summary_table(sys)
it = DateTime(fs_table[1, :initial_timestamp])
resolution = convert(Hour, fs_table[1, :resolution])
intervals = fs_table[1, :interval]
num_intervals = fs_table[1, :window_count]
ft = it .+ convert(Day, intervals) .* num_intervals
ts_timestamps = collect(StepRange(it, resolution, ft))

k2 = "gen-472"
gen = get_component(ThermalStandard, sys, k2)
ts_forced_outage = PSY.TimeSeriesForcedOutage(outage_status_scenario="WorstShortfallSample")
PSY.add_supplemental_attribute!(sys, gen, ts_forced_outage)
data = fill(false, length(ts_timestamps))
availability_data = TimeSeries.TimeArray( ts_timestamps,data)
availability_timeseries = PSY.SingleTimeSeries("availability", availability_data)
PSY.add_time_series!(sys, ts_forced_outage, availability_timeseries)

PSY.transform_single_time_series!(sys, Hour(48), Hour(24))

template_uc = PSI.template_unit_commitment(network=NetworkModel(CopperPlatePowerModel))
PSI.set_device_model!(template_uc, ThermalMultiStart, ThermalStandardUnitCommitment)
PSI.set_device_model!(template_uc, ThermalStandard, ThermalStandardUnitCommitment)

solver = PSI.optimizer_with_attributes(Gurobi.Optimizer)
set_optimizer_attribute(solver, "MIPGap", 0.5)

output_dir = joinpath("/projects", "emco4286", "data", "sienna_data", "output", "ercot", "scenarios")

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
    name = "functionality_test",
    steps = 365,
    models = models,
    sequence = sequence,
    simulation_folder = output_dir,
)

build!(sim)
execute!(sim; enable_progress_bar = false)