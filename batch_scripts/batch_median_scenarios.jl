using Pkg
Pkg.activate("/projects/emco4286/software/julia/MyProject")

using PowerSystems, PowerSimulations, InfrastructureSystems, HydroPowerSimulations, PowerSystemCaseBuilder, SiennaPRASInterface, PRASCore
const PSI = PowerSimulations
const PSY = PowerSystems
const IS = InfrastructureSystems

using Gurobi, JuMP

using CSV, DataFrames, Dates, TimeSeries, DataStructures, JSON, Random, Glob, Printf, Base.Iterators, ArgParse

file_dir = joinpath("/projects", "emco4286", "data", "sienna_data", "input", "DA_sys", "final_sys_DA.json")
sys = System(file_dir)

# This is all to get the timestamps for the data used in this system
fs_table = PSY.get_forecast_summary_table(sys)
it = DateTime(fs_table[1, :initial_timestamp])
resolution = convert(Hour, fs_table[1, :resolution])
intervals = fs_table[1, :interval]
num_intervals = fs_table[1, :window_count]
ft = it .+ convert(Day, intervals) .* num_intervals
ts_timestamps = collect(StepRange(it, resolution, ft))

# Use argument to pick scenario
num = parse(Int32, ARGS[1])
fname = @sprintf("medians_%s.json", num)
mydir = joinpath("/projects", "emco4286", "data", "scenarios", "median", fname)
scenario = JSON.parsefile(mydir)

av_data = Any[]
total_capacity = Any[]

# Assign outage trajectories to generators

for k1 in collect(keys(scenario))
    for k2 in collect(keys(scenario[k1]))

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

        # Store timeseries availability data
        ts = get_supplemental_attributes(gen)[1]
        my_time_series = get_time_series_array(SingleTimeSeries, ts, "availability")
        push!(av_data, my_time_series.*(get_rating(gen)*get_base_power(gen)))
        push!(total_capacity, get_rating(gen)*get_base_power(gen))

    end
end

# Save timeseries availability data
new_array = reduce((x, y) -> x .+ y,  av_data)
out = values(new_array) ./ sum(total_capacity)

fname = @sprintf("medians_%s.csv", num)
save_dir = joinpath("/projects", "emco4286", "data", "available_capacity", "medians", fname)
CSV.write(save_dir, out)

# 48 hour horizon, 24 hour interval
PSY.transform_single_time_series!(sys, Hour(48), Hour(24))

template_uc = template_unit_commitment(network=NetworkModel(CopperPlatePowerModel))

set_device_model!(template_uc, ThermalMultiStart, ThermalStandardUnitCommitment)
set_device_model!(template_uc, ThermalStandard, ThermalStandardUnitCommitment)

solver = PSI.optimizer_with_attributes(Gurobi.Optimizer)
set_optimizer_attribute(solver, "MIPGap", 0.5)

problem = DecisionModel(template_uc, sys; optimizer = solver, name = "UC")

models = SimulationModels(;
    decision_models = [problem],
)

sequence = SimulationSequence(;
    models = models,
    ini_cond_chronology = InterProblemChronology(),
)

# Build simulation
output_dir = joinpath("/projects", "emco4286", "data", "sienna_data", "output", "ercot", "scenarios")
fname = @sprintf("medians_%s", num)

sim = Simulation(;
    name = fname,
    steps = 365,
    models = models,
    sequence = sequence,
    simulation_folder = output_dir,
)

build!(sim)

execute!(sim)
