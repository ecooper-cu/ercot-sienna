using Pkg; Pkg.activate("/projects/emco4286/software/julia/MyProject")

using ClusterManagers, Distributed

# https://discourse.julialang.org/t/packages-arent-found-on-worker-processors/46820/10
addprocs(3) #, dir="/home/emco4286/tmp", exeflags="--output-file=worker_output_$(myid()).log") #SlurmManager(8), topology=:master_worker, exeflags="--project", dir="/projects/emco4286/software/julia/MyProject")

@everywhere begin
    using Pkg
    Pkg.activate("/projects/emco4286/software/julia/MyProject")
    # Pkg.activate("/projects/emco4286/software/julia/PowerSystems")
    # Pkg.activate("/projects/emco4286/software/julia/PowerSimulations")
    # Pkg.activate("/projects/emco4286/software/julia/HydroPowerSimulations")
    # Pkg.activate("/projects/emco4286/software/julia/PowerSystemCaseBuilder")
    # Pkg.activate("/projects/emco4286/software/julia/SiennaPRASInterface")
    # Pkg.activate("/projects/emco4286/software/julia/PRASCore")
    # Pkg.activate("/projects/emco4286/software/julia/CSV")
    # Pkg.activate("/projects/emco4286/software/julia/DataFrames")
    # Pkg.activate("/projects/emco4286/software/julia/Gurobi")
    # Pkg.activate("/projects/emco4286/software/julia/ArgParse")
    # Pkg.activate("/projects/emco4286/software/julia/Glob")
    # Pkg.activate("/projects/emco4286/software/julia/Printf")

    using PowerSystems, PowerSimulations, InfrastructureSystems, HydroPowerSimulations, PowerSystemCaseBuilder, SiennaPRASInterface, PRASCore, CSV, DataFrames, Dates, TimeSeries, DataStructures, JSON, Glob, Printf, Base.Iterators, ArgParse, JuMP, Gurobi, Distributed, ClusterManagers

    const PSI = PowerSimulations
    const PSY = PowerSystems
    const IS = InfrastructureSystems
    const ENV = Gurobi.Env()

    const system_dir = joinpath("/projects", "emco4286", "data", "sienna_data", "input", "DA_sys", "final_sys_DA.json")
    const scenario_dir = joinpath("/projects", "emco4286", "data", "scenarios", "median")
    const availability_save_dir = joinpath("/projects", "emco4286", "data", "available_capacity", "medians")
    const sim_save_dir = joinpath("/projects", "emco4286", "data", "sienna_data", "output", "ercot", "scenarios")
    const sys = System(system_dir)
end

@everywhere function run_simulation(x)
    print(x)

    sys2 = fast_deepcopy_system(sys, skip_time_series=false, skip_supplemental_attributes=false);

    # This is all to get the timestamps for the data used in this system
    fs_table = PSY.get_forecast_summary_table(sys2)
    it = DateTime(fs_table[1, :initial_timestamp])
    resolution = convert(Hour, fs_table[1, :resolution])
    intervals = fs_table[1, :interval]
    num_intervals = fs_table[1, :window_count]
    ft = it .+ convert(Day, intervals) .* num_intervals
    ts_timestamps = collect(StepRange(it, resolution, ft))

    # Use argument to pick scenario
    fname = @sprintf("medians_%s.json", x)
    scenario = JSON.parsefile(joinpath(scenario_dir, fname))

    av_data = Any[]
    total_capacity = Any[]

    # Assign outage trajectories to generators
    for k1 in collect(keys(scenario))
        for k2 in collect(keys(scenario[k1]))

            gen = get_component(ThermalMultiStart, sys2, k2)

            if gen == nothing
                gen = get_component(ThermalStandard, sys2, k2)
            end
            
            ts_forced_outage = PSY.TimeSeriesForcedOutage(outage_status_scenario="WorstShortfallSample")
            PSY.add_supplemental_attribute!(sys2, gen, ts_forced_outage)

            df = DataFrame(CSV.File(scenario[k1][k2], select=[:state]))
            data = Bool.(df.state)

            availability_data = TimeSeries.TimeArray( ts_timestamps,data)
            availability_timeseries = PSY.SingleTimeSeries("availability", availability_data)
            PSY.add_time_series!(sys2, ts_forced_outage, availability_timeseries)

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
    
    # # Save timeseries availability data
        new_array = reduce((x, y) -> x .+ y,  av_data)
        out = values(new_array) ./ sum(total_capacity)
    
        fname = @sprintf("medians_%s.csv", x)
        CSV.write(joinpath(availability_save_dir, fname), DataFrame(data=out))
    
    # # 48 hour horizon, 24 hour interval
        PSY.transform_single_time_series!(sys2, Hour(48), Hour(24))
    
        template_uc = template_unit_commitment(network=NetworkModel(CopperPlatePowerModel))
    
        PSI.set_device_model!(template_uc, ThermalMultiStart, ThermalStandardUnitCommitment)
        PSI.set_device_model!(template_uc, ThermalStandard, ThermalStandardUnitCommitment)
    
        solver = PSI.optimizer_with_attributes(Gurobi.Optimizer(ENV))
        set_optimizer_attribute(solver, "MIPGap", 0.05)
    
        problem = DecisionModel(template_uc, sys2; optimizer = solver, name = "UC")
    
        models = SimulationModels(;
            decision_models = [problem],
        )
    
        sequence = SimulationSequence(;
            models = models,
            ini_cond_chronology = InterProblemChronology(),
        )
    
        # Build simulation
        fname = @sprintf("medians_%s", x)
    
        sim = Simulation(;
            name = fname,
            steps = 365,
            models = models,
            sequence = sequence,
            simulation_folder = sim_save_dir,
        )
    
        build!(sim)
    
        execute!(sim)
    end
end

wids = workers()

@sync begin
    for i in 2:10
        wid = wids[mod1(i, length(wids))]
        @async remotecall_wait(run_simulation, wid, i)
    end
end

# pmap(run_simulation, 2:10)
# rmprocs(workers())