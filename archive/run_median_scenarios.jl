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

scenario = JSON.parsefile(joinpath("/projects", "emco4286", "data", "scenarios", "medians_1.json"))

fs_table = PSY.get_forecast_summary_table(sys)
it = DateTime(fs_table[1, :initial_timestamp])
resolution = convert(Hour, fs_table[1, :resolution])
intervals = fs_table[1, :interval]
num_intervals = fs_table[1, :window_count]
ft = it .+ convert(Day, intervals) .* num_intervals
ts_timestamps = collect(StepRange(it, resolution, ft))

global av_data = TimeSeries.TimeArray(ts_timestamps, zeros(length(ts_timestamps)))
global total_capacity = 0

for k1 in collect(keys(scenario))
    for k2 in collect(keys(scenario[k1]))

        global av_data
        global total_capacity

        gen = get_component(ThermalMultiStart, sys, k2)

        if gen == nothing
            gen = get_component(ThermalStandard, sys, k2)
        end
        
        ts_forced_outage = PSY.TimeSeriesForcedOutage(outage_status_scenario="WorstShortfallSample")
        PSY.add_supplemental_attribute!(sys, gen, ts_forced_outage)

        df = DataFrame(CSV.File(scenario[k1][k2], select=[:state]))
        data = Bool.(df.state)

        availability_data = TimeSeries.TimeArray( ts_timestamps,data)
        availability_timeseries = PSY.SingleTimeSeries("availability", availability_data)
        PSY.add_time_series!(sys, ts_forced_outage, availability_timeseries)

        if !has_supplemental_attributes(gen)
            print(k1)
            print(k2)
            break
        end

        ts = get_supplemental_attributes(gen)[1]
        my_time_series = get_time_series_array(SingleTimeSeries, ts, "availability")
        av_data = av_data .+ (my_time_series .* get_rating(gen))
        total_capacity += get_rating(gen)

    end
end

# save capacity TS

save_dir = joinpath("/projects", "emco4286", "data", "available_capacity", "medians", "ts_1.csv" )
CSV.write(save_dir, av_data ./ total_capacity)

# 48 hour horizon, 24 hour interval
PSY.transform_single_time_series!(sys, Hour(48), Hour(24))

template_uc = template_unit_commitment(network=NetworkModel(CopperPlatePowerModel))

set_device_model!(template_uc, Line, StaticBranch)
set_device_model!(template_uc, Transformer2W, StaticBranch)
set_device_model!(template_uc, TapTransformer, StaticBranch)
set_device_model!(template_uc, ThermalMultiStart, ThermalMultiStartUnitCommitment)
set_device_model!(template_uc, ThermalStandard, ThermalStandardUnitCommitment)
set_device_model!(template_uc, RenewableDispatch, RenewableFullDispatch)
set_device_model!(template_uc, PowerLoad, StaticPowerLoad)
set_device_model!(template_uc, HydroDispatch, HydroDispatchRunOfRiver)
set_device_model!(template_uc, RenewableNonDispatch, FixedOutput)

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

output_dir = joinpath("/projects", "emco4286", "data", "sienna_data", "output", "ercot", "scenarios")

sim = Simulation(;
    name = "medians_1",
    steps = 365,
    models = models,
    sequence = sequence,
    simulation_folder = output_dir,
)

build!(sim)

execute!(sim)
