using PowerSystems, InfrastructureSystems, PowerSimulations, HydroPowerSimulations, PowerSystemCaseBuilder, SiennaPRASInterface
using Gurobi, JuMP # solver
using CSV, DataFrames, Dates, TimeSeries, DataStructures
using Dates

const PSI = PowerSimulations
const PSY = PowerSystems

sys = build_system(PowerSystemCaseBuilder.SPISystems, "RTS_GMLC_Hourly with Static Outage Data")

PSY.transform_single_time_series!(sys, Hour(48), Hour(24))

rts_outage_ts_data = CSV.read(
        joinpath("/projects", "emco4286", "data", "sienna_data", "RTS_Test_Outage_Time_Series_Data.csv"),
        DataFrame,
    )

function get_ts_timestamps(sys::PSY.System)
    static_ts_summary = PSY.get_static_time_series_summary_table(sys)

    first_timestamp = DateTime(static_ts_summary[1, "initial_timestamp"])
    ts_period = static_ts_summary[1, "resolution"].periods[1]
    ts_resolution = typeof(ts_period)
    ts_step = ts_resolution(ts_period.value)
    ts_count = static_ts_summary[1, "time_step_count"]
    finish_datetime = first_timestamp + ts_resolution((ts_count - 1) * ts_step)

    ts_timestamps = collect(StepRange(first_timestamp, ts_step, finish_datetime))
    return ts_timestamps, first_timestamp, ts_step
end

function rate_to_probability(for_gen::Float64, mttr::Int64)
    if (for_gen > 1.0)
        for_gen = for_gen / 100
    end

    if for_gen == 1.0
        return (λ = 1.0, μ = 0.0)  # can we error here instead?
    end
    if mttr != 0
        μ = 1 / mttr
    else # MTTR of 0.0 doesn't make much sense.
        μ = 1.0
    end
    return (λ = (μ * for_gen) / (1 - for_gen), μ = μ)
end

function add_timeseries_outage_data!(sys::PSY.System, rts_outage_ts_data::DataFrame)
    # Time series timestamps
    ts_timestamps, first_timestamp, step = get_ts_timestamps(sys)

    # Add λ and μ time series 
    for row in DataFrames.eachrow(rts_outage_ts_data)
        comp = PSY.get_component(PSY.Generator, sys, row.Unit)
        λ_vals = Float64[]
        μ_vals = Float64[]
        for i in range(0; length = 12)
            next_timestamp = first_timestamp + Dates.Month(i)
            λ, μ = rate_to_probability(row[3 + i], 48) # Assuming MTTR is 48
            # We have monthly outage rates, so we need to fill in time series based on the 
            # resolution of the SingleTimeSeries
            append!(
                λ_vals,
                fill(λ, (daysinmonth(next_timestamp) * 24 * Int(Dates.Hour(1) / step))),
            )
            append!(
                μ_vals,
                fill(μ, (daysinmonth(next_timestamp) * 24 * Int(Dates.Hour(1) / step))),
            )
        end
        PSY.add_time_series!(
            sys,
            first(
                PSY.get_supplemental_attributes(
                    PSY.GeometricDistributionForcedOutage,
                    comp,
                ),
            ),
            PSY.SingleTimeSeries(
                "outage_probability",
                TimeSeries.TimeArray(ts_timestamps, λ_vals),
            ),
        )
        PSY.add_time_series!(
            sys,
            first(
                PSY.get_supplemental_attributes(
                    PSY.GeometricDistributionForcedOutage,
                    comp,
                ),
            ),
            PSY.SingleTimeSeries(
                "recovery_probability",
                TimeSeries.TimeArray(ts_timestamps, μ_vals),
            ),
        )
        @debug "Added outage probability and recovery probability time series to supplemental attribute of $(row["Unit"]) generator"
    end
end

add_timeseries_outage_data!(sys, rts_outage_ts_data)

device_models = SiennaPRASInterface.DeviceRAModel[
        DeviceRAModel(PSY.ThermalStandard, GeneratorPRAS),
        DeviceRAModel(
            PSY.RenewableDispatch,
            GeneratorPRAS(lump_renewable_generation=false),
        ),
    ]
ra_template = SiennaPRASInterface.RATemplate(PSY.Area, device_models)
generate_outage_profile!(sys, SiennaPRASInterface.SequentialMonteCarlo(samples=10, seed=1))

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

output_dir = joinpath("/projects", "emco4286", "data", "sienna_data", "output", "test", "uc_only")

sim = Simulation(;
    name = "uc_only_gurobi_with_geometric_outages",
    steps = 365,
    models = models,
    sequence = sequence,
    simulation_folder = output_dir,
)

build!(sim)
execute!(sim; enable_progress_bar = false)