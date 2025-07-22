#!/bin/bash

#SBATCH --account=ucb678_asc1
#SBATCH --partition=amem
#SBATCH --job-name=median-$SLURM_ARRAY_TASK_ID
#SBATCH --output=out/medians/$SLURM_ARRAY_TASK_ID.out
#SBATCH --time=4:00:00
#SBATCH --qos=mem
#SBATCH --mem=256G

#SBATCH --nodes=1
#SBATCH --ntasks=1

#SBATCH --mail-type=ALL
#SBATCH --mail-user=emco4286@colorado.edu

[ -z ${SLURM_ARRAY_TASK_COUNT} ] && echo "Missing --array=x-y" && exit

/curc/sw/julia/1.10.2/bin/julia "/home/emco4286/ercot-sienna/batch_scripts/batch_median_scenarios.jl" $SLURM_ARRAY_TASK_ID