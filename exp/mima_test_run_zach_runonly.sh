#!/bin/bash
#SBATCH -n 8
#SBATCH -o mima_compile.out
#SBATCH -e mima_compile.err
#
#Minimal runscript for atmospheric dynamical cores
# Compile script for MiMA... or a template for it at least. For more information, see docs, etc. on GitHub:
# JeffersonScientific fork (may include some site-specific tweaks):
# https://github.com/jeffersonscientific/MiMA
# or the original, parent repo:
# https://github.com/mjucker/MiMA
#
# get proper compiler (intel), mpi environment:
module purge
module unuse /usr/local/modulefiles
#
#module load intel
module load intel/19
#module load intel/19.1.0.166
COMP='intel19'
#
#module load mvapich2/2.3.2
module load openmpi_3/
MPI='openmpi3'
#
COMP_MPI=${COMP}_${MPI}
#
module load netcdf/4.7.1
module load netcdf-fortran/4.5.2
#module load netcdf-cxx/4.3.1
#module load pnetcdf/1.12.0
#
# modules will add to an $INCLUDE variable, but we need to set that for the system...
#
export CPATH=${INCLUDE}:${CPATH}
CC_SPP=${CC}

# TEST RUN
echo "STARTING TEST RUN"
#user=zespinos
run=mima_test
#
MIMA_PATH="/scratch/myoder96/MiMA"
MIMA_EXE="${MIMA_PATH}/exp/exec.SE3Mazama/mima.x"
#executable=/scratch/${USER}/models/code/MiMA_yoder/exp/exec.SE3Mazama/mima.x
#input=/scratch/${user}/models/code/MiMA_yoder/input
INPUT=${MIMA_PATH}/input
rundir="/scratch/${USER}/models/runs/$run"
#
echo "rundir: ${rundir}"
#exit 1

if [[ -z ${SLURM_NTASKS} ]]; then
    N_PROCS=4
else
    N_PROCS=${SLURM_NTASKS}
fi

# Make run dir
if [[ ! -d $rundir  ]]; then
    mkdir -p ${rundir}
fi
#
# Copy executable to rundir
cp ${MIMA_EXE} $rundir/
#cp $executable $rundir/
# Copy input to rundir

#cp -r $input $rundir
cp -r ${INPUT}/* $rundir/
# Run the model
cd $rundir

ulimit -s unlimited
#mpiexec -v -n $N_PROCS mima.x
mpirun -np $N_PROCS mima.x

if [[ ! $? -eq 0 ]]; then
    exit 1
fi

CCOMB=/scratch/myoder96/MiMA/bin/mppnccombine.SE3Mazama
#CCOMP=${MIMA_PATH}/bin
$CCOMB -r atmos_daily.nc atmos_daily.nc.*
$CCOMB -r atmos_avg.nc atmos_avg.nc.*
