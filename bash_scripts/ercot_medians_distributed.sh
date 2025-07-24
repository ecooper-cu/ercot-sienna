#!/bin/bash

#SBATCH --account=ucb678_asc1
#SBATCH --partition=amilan
#SBATCH --job-name=medians
#SBATCH --output=out/lo/%a.out
#SBATCH --time=24:00:00
#SBATCH --qos=normal
#SBATCH --nodes=1
#SBATCH --ntasks=64
#SBATCH --mail-type=ALL
#SBATCH --mail-user=emco4286@colorado.edu

[ -z ${SLURM_ARRAY_TASK_COUNT} ] && echo "Missing --array=x-y" && exit

module purge
module load julia

julia -n 63 "/home/emco4286/ercot-sienna/batch_scripts/batch_lower_quantile.jl"