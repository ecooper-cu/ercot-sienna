#!/bin/bash

#SBATCH --account=ucb678_asc1

#SBATCH --partition=amem

#SBATCH --job-name=example-job
#SBATCH --output=out/ercot_pcm/%j.out
#SBATCH --time=4:00:00
#SBATCH --qos=mem
#SBATCH --mem=256G

#SBATCH --nodes=1
#SBATCH --ntasks=1

#SBATCH --mail-type=ALL
#SBATCH --mail-user=emco4286@colorado.edu

cd /projects/emco4286/software/julia
/curc/sw/julia/1.10.2/bin/julia "/home/emco4286/ercot-sienna/batch_scripts/test_functionality_ercot_uc_only_batchable_gurobi.jl"