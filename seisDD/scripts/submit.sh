#!/bin/bash

echo 
echo '~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~'
echo
echo " source parameter file ..." 
source parameter

echo 
echo " create new job_info file ..."
rm -rf job_info
mkdir job_info

echo 
echo " create result file ..."
mkdir -p RESULTS

echo
echo '~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~'
echo
echo

echo " select workflow ..."
workflow_DIR="$package_path/workflow"

var="modeling"
if [ "${job,,}" == "${var,,}"  ]
then
    echo " ########################################################"
    echo " Forward modeling .." 
    echo " ########################################################"
    cp $workflow_DIR/Modeling.sh $Job_title.sh

var="kernel"
elif [ "${job,,}" == "${var,,}"  ]
then
    echo " ########################################################"
    echo " Adjoint Inversion .." 
    echo " ########################################################"
    cp $workflow_DIR/Kernel.sh $Job_title.sh

var1="inversion"
var2="fwi"
elif [ "${job,,}" == "${var1,,}"  ] || [ "${job,,}" == "${var2,,}"  ]
then
    echo " ########################################################"
    echo " Adjoint Inversion .." 
    echo " ########################################################"
    cp $workflow_DIR/AdjointInversion.sh $Job_title.sh
else
    echo "Wrong job: $job"
fi

echo
echo " renew parameter file ..."
cp $package_path/SRC/seismo_parameters.f90 ./bin/
cp $package_path/lib/src/constants.f90 ./bin/
cp $package_path/scripts/renew_parameter.sh ./
./renew_parameter.sh

echo 
echo " complile lib codes ... "
rm -rf *.mod make_*
cp $package_path/lib/make_lib ./make_lib
FILE="make_lib"
sed -e "s#^SRC_DIR=.*#SRC_DIR=$package_path/lib/src#g"  $FILE > temp;  mv temp $FILE
sed -e "s#^MOD_DIR=.*#MOD_DIR=./bin#g"  $FILE > temp;  mv temp $FILE
sed -e "s#^LIB_preprocess=.*#LIB_preprocess=./bin/seismo.a#g"  $FILE > temp;  mv temp $FILE
make -f make_lib clean
make -f make_lib
echo 
read -rsp $'Press any key to compile source codes ...\n' -n1 key
cp $package_path/make/make_$compiler ./make_file
FILE="make_file"
sed -e "s#^SRC_DIR=.*#SRC_DIR=$package_path/SRC#g"  $FILE > temp;  mv temp $FILE
sed -e "s#^LIB_seismo=.*#LIB_seismo=./bin/seismo.a#g"  $FILE > temp;  mv temp $FILE
make -f make_file clean
make -f make_file

echo 
echo " edit request nodes and tasks ..."
nproc=$NPROC_SPECFEM
ntaskspernode=$(echo "$max_nproc_per_node $nproc" | awk '{ print $1/$2 }')
nodes=$(echo $(echo "$ntasks $nproc $max_nproc_per_node" | awk '{ print $1*$2/$3 }') | awk '{printf("%d\n",$0+=$0<0?0:0.999)}')
echo " Request $nodes nodes, $ntasks tasks, $ntaskspernode tasks per node, $nproc cpus per task "

echo
echo '~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~'
echo

echo "submit job ..."
echo
if [ $system == 'slurm' ]; then
    echo "slurm system ..."
    echo "sbatch -p $queue --nodes=$nodes --ntasks=$ntasks --ntasks-per-node=$ntaskspernode --cpus-per-task=$nproc -t $WallTime -e job_info/error -o job_info/output $Job_title.sh"
    sbatch -N $nodes -n $ntasks --cpus-per-task=$nproc -t $WallTime -e job_info/error -o job_info/output $Job_title.sh

elif [ $system == 'pbs' ]; then
    echo "pbs system ..."
    echo
    echo "qsub -q $queue select=$nodes:ncpus=$max_nproc_per_node:mpiprocs=$nproc -l --walltime=$WallTime -e job_info/error -o job_info/output  $Job_title.sh"
    qsub -l nodes=$nodes:ppn=$max_nproc_per_node -l --walltime=$WallTime -e job_info/error -o job_info/output  $Job_title.sh
fi
echo
