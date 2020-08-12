#!/bin/bash
#SBATCH -n 24
#SBATCH -o mima_compile.out
#SBATCH -e mima_compile.err
#
# TODO: let's just get rid of the mkmf.template. I think it just gets imported into the nmakefile; we're better off just setting the
#  LDFLAGS, etc. variables from this script.
#
#Minimal runscript for atmospheric dynamical cores
# Compile script for MiMA... or a template for it at least. For more information, see docs, etc. on GitHub:
# JeffersonScientific fork (may include some site-specific tweaks):
# https://github.com/jeffersonscientific/MiMA
# or the original, parent repo:
# https://github.com/mjucker/MiMA
#
# NOTE: this script has an openmpi-only (ish) componenent -- namely a call to pkg-config. Likely a similar call is
#  available for mpich3, but I think impi does not typically provide pkg-config.
#
# Mazama:
# from prefix: /opt/ohpc/pub/moduledeps/intel
#
# get proper compiler (intel), mpi environment:
module purge
module unuse /usr/local/modulefiles
#
#module load intel
module load intel/19 #.1.0.166
COMP="intel19"
#
MPI="openmpi3"
COMP_MPI="${COMP}_${MPI}"

case "${MPI}" in
    "openmpi3")
        echo "executing OpenMPI"
        module load openmpi_3/
        MPI_FFLAGS="`pkg-config --cflags ompi-fort` "
        MPI_CFLAGS="`pkg-config --cflags ompi` "
        MPI_LDFLAGS="`pkg-config --libs ompi-fort` "
        # NOTE: this is inclusive of `pkg-config --libs ompi`
        ;;
    "mpich3")
        echo "executing MPICH3"
        module load mpich_3/
        #
        MPI_FFLAGS="`pkg-config --cflags mpich` -I${MPI_DIR}/lib "
        MPI_CFLAGS="`pkg-config --cflags mpich`"
        MPI_LDFLAGS="`pkg-config --libs mpich` "
        ;;
    "impi19")
        echo "executing IMPI19"
        module load impi_19/
        #
        MPI_FFLAGS="-I${MPI_DIR}/include $-I{MPI_DIR}/lib "
        MPI_CFLAGS="-I${MPI_DIR}/include "
        # guessing a bit here. not sure there is a libmpi.* in
        MPI_LDFLAGS="-L${MPI_DIR}/lib -lmpi -lmpifort"
        ;;
    *)
        echo "Executing OTHER MPI"
        # not really much we can do (by default) if we don't have an MPI module
        #  so leave these blank or we could assume it's another MPI??
        #MPI_FFLAGS=""
        #MPI_CFLAGS=""
        #MPI_LDFLAGS=""
        #
        MPI_FFLAGS="-I${MPI_DIR}/include $-I{MPI_DIR}/lib "
        MPI_CFLAGS="-I${MPI_DIR}/include "
        # guessing a bit here...
        MPI_LDFLAGS="-L${MPI_DIR}/lib -lmpi "
        ;;
esac
echo "*** MPI_FFLAGS: ${MPI_FFLAGS}"
#
module load netcdf/4.7.1
module load netcdf-fortran/4.5.2
#module load netcdf-cxx/4.3.1
#module load pnetcdf/1.12.0
module load cmake/
module load autotools/
#
# modules will add to an $INCLUDE variable, but we need to set that for the system...
#
export CPATH=${INCLUDE}:${CPATH}
export CPATH=${INCLUDE}:${CPATH}
export CC_SPP=${CC}
export FC=${MPIFC}
export CXX=${MPICXX}
export CC=${MPICC}
export LD=${MPIFC}
#
DO_CLEAN=0
#
# openmpi3:
# pnetcdf-config --fflags; pnetcdf-config --fcflags;
# TODO: Rememer hierarchy of nf-config and nc-config comands (aka, i think --fflags contains --cflags, so nf-conngif --fflags has all
#  the neessary fortran and c flags. what about c++?
# NOTE: for mpich_3/: (maybe) use pkg-config {--cflags, --libs} mpich
export MIMA_CONFIG_FFLAGS="`nf-config --cflags` ${MPI_FFLAGS} -I${HDF5_LIB} -I${NETCDF_FORTRAN_LIB} -I${NETCDF_LIB} -I${MPI_DIR}/lib"
#$ pnetcdf-config --cflags ompi; pnetcdf-config --cflags; pkg-config --cflags ompi-fort;
export MIMA_CONFIG_CFLAGS="`nc-config --cflags` ${MPI_CFLAGS}"
# x; ncxx4-config --libs; pnetcdf-config --ldflags; pnetcdf-config --libs
export MIMA_CONFIG_LDFLAGS=" `nf-config --flibs`  ${MPI_LDFLAGS}"
echo "*** ** *** ldflags: ${MIMA_CONFIG_LDFLAGS}"
#
# TODO: in the template, LDPATH should be getting export to MIMA_CONFIG_LDFLAGS, but it appears that it is not. It is, in fact, the very final compile step
#
cwd=`pwd`
#
echo "MIMA_CONFIG_FFLAGS: ${MIMA_CONFIG_FFLAGS}"
echo "MIMA_CONFIG_CFLAGS: ${MIMA_CONFIG_CFLAGS}"
echo "MIMA_CONFIG_LDFLAGS: ${MIMA_CONFIG_LDFLAGS}"
#
# Let's skip the stupid mkmf.template file and just set our {}FLAGS as environment variables:
###################
# FFLAGS:
DEBUG="-g -traceback -debug full"
#OPT=-O2 -xSSE4.2 -axAVX
OPT="-O2"
#OPT=-O1
#OPT=-O0
# NOTE: I'll be frank. I don't know what half of these do... -heap-arrays is pseudo-equivalent to running under
#  ulimit -s unlimited (infinite stack size), but at the compile level -- aka, it tells the compiler to put all arrays on the
#  heap. This makes it run, but can be a significant performance hit. Some of the other prams are probably compier/arch. specific.
export FFLAGS="${DEBUG} ${OPT} -heap-arrays -fpp -stack_temps -safe_cray_ptr -ftz -assume byterecl -i4 -r8 -g ${MIMA_CONFIG_FFLAGS} "
#
###################
export CPPFLAGS="${MIMA_CONFIG_CFLAGS}"
#
###################
export LDFLAGS="${MIMA_CONFIG_LDFLAGS}"
#
export CFLAGS="-D__IFC"

#exit 1
# get number of processors. If running on SLURM, get the number of tasks.
if [[ -z ${SLURM_NTASKS} ]]; then
    MIMA_NPES=8
else
    MIMA_NPES=${SLURM_NTASKS}
fi

echo "Compile on N=${MIMA_NPES} process"
#
#--------------------------------------------------------------------------------------------------------
# define variables
platform="SE3Mazama"
#template="`cd ../bin;pwd`/mkmf.template.$platform"    # path to template for your platform
template="`pwd`/mkmf.template.${platform}"    # path to template for your platform
mkmf="`cd ../bin;pwd`/mkmf"                           # path to executable mkmf
sourcedir="`cd ../src;pwd`"                           # path to directory containing model source code
mppnccombine="`cd ../bin;pwd`/mppnccombine.$platform" # path to executable mppnccombine
#--------------------------------------------------------------------------------------------------------
execdir="${cwd}/exec.$platform"       # where code is compiled and executable is created
workdir="${cwd}/workdir"              # where model is run and model output is produced
pathnames="${cwd}/path_names"           # path to file containing list of source paths
namelist="${cwd}/namelists"            # path to namelist file
diagtable="${cwd}/diag_table"           # path to diagnositics table
fieldtable="${cwd}/field_table"         # path to field table (specifies tracers)
#--------------------------------------------------------------------------------------------------------
#
echo "**"
echo "*** compile step..."
# compile mppnccombine.c, will be used only if $npes > 1
if [[ -e ${mppnccombine} ]]; then
    rm ${mppnccombine}
fi
#
if [[ ! -f "${mppnccombine}" ]]; then
  #icc -O -o $mppnccombine -I$NETCDF_INC -L$NETCDF_LIB ${cwd}/../postprocessing/mppnccombine.c -lnetcdf
  # NOTE: this can be problematic if the SPP and MPI CC compilers get mixed up. this program often requires the spp compiler.
   ${CC_SPP} -O -o ${mppnccombine} -I${NETCDF_INC} -I${NETCDF_FORTRAN_INC} -I{HDF5_INC} -L${NETCDF_LIB} -L${NETCDF_FORTRAN_LIB} -L{HDF5_LIB}  -lnetcdf -lnetcdff ${cwd}/../postprocessing/mppnccombine.c
else
    echo "${mppnccombine} exists?"
fi
#--------------------------------------------------------------------------------------------------------

echo "*** set up directory structure..."
# note though, we really have no busines doing anything with $workdir here, but we'll leave it to be consistent with
#  documentation.
# setup directory structure
# yoder: just brute force these. If the files/directories, exist, nuke them...
if [[ $"DO_CLEAN" -eq 1 ]]; then
    if [[ -d ${execdir} ]]; then rm -rf ${execdir}; fi
fi
if [[ ! -d "${execdir}" ]]; then mkdir ${execdir}; fi
#
if [[ -e "${workdir}" ]]; then
  #echo "ERROR: Existing workdir may contaminate run. Move or remove $workdir and try again."
  #exit 1
  rm -rf ${workdir}
  mkdir ${workdir}
fi
#--------------------------------------------------------------------------------------------------------
echo "**"
echo "*** compile the model code and create executable"

# compile the model code and create executable
cd ${execdir}
#echo "pwd: " `pwd`
#exit 1

#export cppDefs="-Duse_libMPI -Duse_netCDF"
cppDefs="-Duse_libMPI -Duse_netCDF -DgFortran"
export CPPDEFS=${cppDefs}
#
# NOTE: not sure how much of this we still need for mkmf, but this does work...
${mkmf} -p mima.x -t $template -c "${cppDefs}" -a $sourcedir $pathnames ${NETCDF_INC} ${NETCDF_LIB} ${NETCDF_FORTRAN_INC} ${NETCDF_FORTRAN_LIB} ${HDF5_INC} ${HDF5_LIB} ${MPI_DIR}/include ${MPI_DIR}/lib $sourcedir/shared/mpp/include $sourcedir/shared/include
# /usr/local/include
#
#exit 1
#
if [[ $"DO_CLEAN" -eq 1 ]]; then
    make clean
fi
#
#exit 1
echo "*** do live compile... (`pwd`)"
#exit 1
make -f Makefile -j${MIMA_NPES}
#
if [[ ! $? -eq 0 ]]; then
    # I think mnake generates a kinda stupid, not-really error that generates a not-zero, so let's not exit.
    echo "Make error-ish..."
    #exit 1
fi
#
###################################################################################
# TEST RUN 
echo "STARTING TEST RUN"
#user=zespinos
run=mima_test_yoder_zesp
#
MIMA_SRC=`pwd/..`
executable=${MIMA_SRC}/exp/exec.SE3Mazama/mima.x
input=${MIMA_SRC}/input
#
rundir=/scratch/${USER}/MIMA_tmp/$run
if [[ -z ${SLURM_NTASKS} ]]; then
    N_PROCS=4
else
    N_PROCS=${SLURM_NTASKS}
fi

# Make run dir
[ ! -d $rundir  ] && mkdir -p $rundir
# Copy executable to rundir
cp $executable $rundir/
# Copy input to rundir
cp -r $input/* $rundir
# Run the model
cd $rundir

ulimit -s unlimited
#mpiexec -v -n $N_PROCS ./mima.x
mpirun -np ${N_PROCS} ./mima.x

CCOMB=/scratch/${user}/models/code/MiMA_yode/bin/mppnccombine.SE3Mazama
$CCOMB -r atmos_daily.nc atmos_daily.nc.*
$CCOMB -r atmos_avg.nc atmos_avg.nc.*




