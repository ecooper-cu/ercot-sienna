#!/bin/bash

#SBATCH --account=ucb678_asc1
#SBATCH --partition=amilan
#SBATCH --job-name=medians
#SBATCH --output=out/medians.%j.out
#SBATCH --time=24:00:00
#SBATCH --qos=normal
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=32
#SBATCH --mail-type=ALL
#SBATCH --mail-user=emco4286@colorado.edu

/curc/sw/julia/1.10.2/bin/julia "/home/emco4286/ercot-sienna/batch_scripts/run_median_scenarios.jl"