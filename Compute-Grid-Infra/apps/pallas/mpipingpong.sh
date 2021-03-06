#!/bin/bash

# set the number of nodes and processes per node
#PBS -l nodes=2:ppn=1

# set name of job
#PBS -N pallas-pingpong
source /opt/intel/impi/5.1.3.181/bin64/mpivars.sh

mpirun -env I_MPI_FABRICS=dapl -env I_MPI_DAPL_PROVIDER=ofa-v2-ib0 -env I_MPI_DYNAMIC_CONNECTION=0 IMB-MPI1 pingpong

