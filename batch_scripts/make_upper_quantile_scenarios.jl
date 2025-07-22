using Pkg
Pkg.activate("/projects/emco4286/software/julia/MyProject")

using PowerSystems, PowerSimulations, InfrastructureSystems, HydroPowerSimulations, PowerSystemCaseBuilder, SiennaPRASInterface, PRASCore
const PSI = PowerSimulations
const PSY = PowerSystems

using CSV, DataFrames, Dates, TimeSeries, DataStructures, JSON, Random, Glob, Printf, Base.Iterators

using Statistics, Distributions, ExpectationMaximization

m = 100

file_dir = joinpath("/projects", "emco4286", "data", "sienna_data", "input", "DA_sys", "final_sys_DA.json")
sys = System(file_dir)
gens = vcat(collect(get_components(ThermalStandard, sys)), collect(get_components(ThermalMultiStart, sys)))

cycler_dict = Dict("files" => Dict(), "iterators" => Dict())

data_directory = joinpath("/projects", "emco4286", "data", "gads", "trajectories", "synthetic")

for (k, n) in zip(["st", "cc", "ct", "gt"], ["21","17","13","17"])

    pattern = Regex(@sprintf "/projects/emco4286/data/gads/trajectories/synthetic/%s/synthetic_(.*)_seed_(.*)_outages_%s_unique_(.*).csv" k n)
    files = glob("*.csv", joinpath(data_directory, k))
    out = filter(!isnothing, [match(pattern, f) for f in files])
    cycler_dict["files"][k] = cycle([c.match for c in out])
    cycler_dict["iterators"][k] = Uniform(1, length(out))
end

# offset is uniform for whole scenario but differs between generator types
offset_dict = Dict([k => Dict() for k in ["ct", "st", "cc", "gt"]])
for k in keys(offset_dict)
    offset_dict[k] = Dict(zip(collect(1:m), round.(Int32, rand(cycler_dict["iterators"][k], m))))
end

for s in collect(1:m)

    # holds the generator trajectory assignments
    mydict = Dict([k => Dict() for k in ["ct", "st", "cc", "gt"]])

    # keeps track of number of each generator type within scenario
    count_dict = Dict([k => 0 for k in ["ct", "st", "cc", "gt"]])

    for g in gens
        name = get_name(g)
        pm_val = get_prime_mover_type(g).value

        k = ""

        if pm_val == 8
            k = "ct"
        elseif pm_val == 20
            k = "st"
        elseif pm_val == 4
            k = "cc"
        elseif pm_val ==12
            k = "gt"
        end

        offset = offset_dict[k][s]
        count_dict[k] += 1

        my_file = collect(take(cycler_dict["files"][k], count_dict[k] + offset))[end]
        mydict[k][name] = my_file
    end

    savename = @sprintf "up_%i.json" s
    savept = joinpath("/projects", "emco4286", "data", "scenarios", "upper_quantile", savename)
    open(savept,"w") do f 
        JSON.print(f, mydict) 
    end
end