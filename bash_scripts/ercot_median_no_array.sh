#!/bin/bash

#SBATCH --account=ucb678_asc1
#SBATCH --partition=atesting_a100
#SBATCH --job-name=medians
#SBATCH --output=out/medians/2_10.out
#SBATCH --time=1:00:00
#SBATCH --qos=testing
#SBATCH --mem=20G
#SBATCH --nodes=1
#SBATCH --ntasks-per-node=8
#SBATCH --mail-type=ALL
#SBATCH --mail-user=emco4286@colorado.edu
#SBATCH --gres=gpu:1

module purge
module load julia

julia "/home/emco4286/ercot-sienna/batch_scripts/batch_median_scenarios_no_array.jl"