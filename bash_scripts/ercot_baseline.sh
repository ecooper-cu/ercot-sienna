#!/bin/bash

#SBATCH --account=ucb678_asc1
#SBATCH --partition=amem
#SBATCH --job-name=baseline
#SBATCH --output=out/baseline.%j.out
#SBATCH --time=4:00:00
#SBATCH --qos=mem
#SBATCH --nodes=1
#SBATCH --mem=256G
#SBATCH --mail-type=ALL
#SBATCH --mail-user=emco4286@colorado.edu

cd /projects/emco4286/software/julia
/curc/sw/julia/1.10.2/bin/julia "/home/emco4286/ercot-sienna/batch_scripts/ercot_uc_only_batchable_gurobi.jl"