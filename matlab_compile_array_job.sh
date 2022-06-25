#!/bin/bash
# Description: Generates submission scripts for matlab array jobs
#              based on user specified first and last task numbers
#              and stride. The matlab main function should read
#              JOB_ID and SGE_TASK_ID from the environment and use
#              SGE_TASK_ID as a replacement of the loop index that 
#              would be used in a monilitic job that executes the tasks
#              sequentially see: 
#              /u/local/apps/subit_scripts/array_jobs/matlab/test_envvar.m


function usage {
    echo -e "\nUsage:\n $0  [-t time in hours] \n   [-nc do not compile (matlab stand alone executable already exists)] \n   [-lt index of last task of array job] \n   [-ft index of first task of array job (default is 1)] \n   [-ts task step size of array job (default is 1)] \n   [ -s number of processes ] [-m memory per process (in GB)] \n   [-p parallel environment: 1 for shared 2 for distributed] \n   [-a add file or entire direcory to the deployable archive] ... \n   [-a add other file or other entire direcory to the deployable archive] \n   [-I add directory to the list of included directories] ... \n   [-I add other directory to the list of included directories] \n   [-f main matlab function] [-f matlab function 2] ... [-f matlab function n] \n   [-ns (to build a submission script without submitting the job)]\n   [-nts (to not add time stamp to cmd file name)]\n   [-hp to run on owned nodes] [ --help ]"
}


function isanumber {
    if ! [[ $1 =~ ^-?[0-9]+$ ]]; then
        echo -e "\n\t$2 needs to be an integer"
        echo -e "Enter:\n\t $0 -h\n for help\n"
        exit
    fi

}

slots=1
mem=2
dir=`pwd`
FLAG=""
FLAG2=""
FLAG4=""
FLAG_NO_COMP=""
name=""
list=""
PE="shared"
time=2
hp=""
par=1
arc=""
list_arc=""
inc=""
list_inc=""
last_task=1
first_task=1
stride=1


if [ $# == 0 ]; then
    usage
    exit
fi

while [[ $# > 0 ]]
do
key="$1"

case $key in
    -t|--time)
	time=$2
	isanumber $time "time in hours"
	if [[ "$time" -gt "24" ]]; then
	    hp=",highp"
	fi
	shift # past argument
	;;
    -nc|--no_compile)
	FLAG_NO_COMP=SET
	;;
    -lt|--last_task)
	last_task=$2
	isanumber $time "number of tasks in array job"
	shift # past argument
	;;
    -ft|--first_task)
	first_task=$2
	isanumber $time "index of first task in array job"
	shift # past argument
	;;
    -ts|--stride)
	stride=$2
	isanumber $time "task step size of array job"
	shift # past argument
	;;
    -s|--slots)
	slots=$2
	#echo "$@"
	isanumber $slots $key
	shift # past argument
	;;
    -m|--memory)
	mem=$2
	#echo "$@"
	isanumber $mem $key
	shift # past argument
	;;
    -p|--parallel)
	par=$2
	#echo "$@"
	isanumber $par $key
	shift # past argument
	;;
     -a|--archive)
	arc=$2
	if [ ! -e ${arc} ]; then
	    echo -e "\n\tThe file/directory \"${arc}\" is not present"
            echo -e "\tplease enter the name of a valid location (try absolute path) "
            echo -e "\tand try again.\n"
            usage
            exit
	fi
	list_arc="$list_arc -a $arc"
	shift # past argument
	;;
     -I|--include)
	inc=$2
	if [ ! -e ${inc} ]; then
	    echo -e "\n\tThe directory \"${inc}\" is not present"
            echo -e "\tplease enter the name of a valid direcrory (try absolute path) "
            echo -e "\tand try again.\n"
            usage
            exit
	fi
	list_inc="$list_inc -I $inc"
	shift # past argument
	;;
     -f|--file)
	file=$2
	if [ ! -e ${file} ]; then
	    echo -e "\n\tThe matlab script \"${file}\" is not present in this directory"
            echo -e "\tplease enter the name of a valid matlab script "
            echo -e "\tand try again.\n"
            usage
            exit
	fi
	if [ "$name" == "" ]; then
	    name=${file%.*}
	fi
	list="$list $file"
	shift # past argument
	;;
    -ns|--nosubmit)
        FLAG=SET
	;;
    -hp|--highp)
        FLAG4=SET
        ;;
    -nts|--notimestamp)
        FLAG2=SET
        ;;
    -h|--help)
	    echo -e "\nThe script: $0 generates and submits a\nbatch array job that builds and runs a matlab standalone application out of \none or more matlab functions.\n\nMatlab standalone executables support the use of the Distributed Computing\nToolbox. The maximum number of parallel workers, for matlab parallel \ninstructions (such as parfor), supported on hoffman2 is 16.\n\nIf any part of your matlab code includes a parfor loop you will need to:\n 1) choose the shared parallel environment (-p 1)\n 2) include the following lines in your matlab code: \n\n#before the parfor loop, for example for 5 workers: "
	    echo -e "\n\t p = parpool('local',5);\n\n#after the parfor loop:\n\n\t delete(p)"
	    echo -e "\nIf your code calls non matlab parallel instructions (e.g., mpirun) you can request \nmore than 16 cores and you should use the distributed parallel environment (-p 2)."
        usage
	echo ""
        exit
	;;
    *)        
        echo -e "\n\t$key is an unknown option..."
        usage
        exit
	;;
esac
shift # past argument or value
done
    

if [[ "$name" == "" ]]; then
    echo -e "\n\tPlease provide at least one matlab function (.m matlab script)"
    echo -e "\tvia the -f switch. "
    echo -e "\n\tTry again.\n"
    usage
    exit
fi

if [[ "$FLAG" == "" ]]; then 
  echo "Running $name on $slots processes each with ${mem}GB of memory for $time hours"
elif [[ "$FLAG" == "SET" ]]; then
  echo "Preparing submit script for $name on $slots processes each with ${mem}GB of memory for $time hours"	
fi
#timestamp=`date "+%F_%H-%M-%S"`
if [[ "$FLAG2" == "" ]]; then
   timestamp=`date "+%F_%H-%M-%S"` 
   name_submit_script=${name}_${timestamp}
else
   name_submit_script=${name}
fi

if [ $par == 1 ]; then
    PE="shared"
else
    PE="dc*"
fi
  
if [[ "$FLAG4" != "" ]]; then
    hp=",highp"
fi

# FIRST EXEC COMPILE JOB:  

if [[ "$FLAG_NO_COMP" == "" ]]; then 
    echo "This run will first generate a stand-along matlab executable via mcc..."


# ARRAY JOB CMD FILE CREATION:

    cat << EOF > ./${name_submit_script}.cmd
#!/bin/bash
#
#  UGE job for example.cmd built Fri May 26 13:52:07 PDT 2017
#
#  The following items pertain to this script
#  Use current working directory
#$ -cwd
#  input           = /dev/null
#  output          = ./${name}.joblog.\$JOB_ID.\$TASK_ID
#$ -o ./${name}.joblog.\$JOB_ID.\$TASK_ID
#  error           = Merged with joblog
#$ -j y
#
#  Resources requested
#$ -pe $PE $slots
#$ -l h_data=${mem}g,h_vmem=INFINITY,h_rt=${time}:00:00$hp
#
#  Name of application for log
#$ -v QQAPP=parallel
#  Email address to notify
#$ -M $USER@mail
#  Notify at beginning and end of job
#$ -m bea
#  Job is not rerunable
#$ -r n
#
#  Job array indexes
#$ -t ${first_task}-${last_task}:${stride}
#
#  Uncomment the next line to have your environment variables used by SGE
#$ -V
#

echo ""
echo "Task \${SGE_TASK_ID} of job \${JOB_ID} started on:   "\` hostname -s \`
echo "Task \${SGE_TASK_ID} of job \$JOB_ID started on:   "\` date \`
echo ""

. /u/local/Modules/default/init/modules.sh
module load matlab/R2020a
#module load intel
module li
export MCR_CACHE_ROOT=\$TMPDIR
echo " "


echo "Number of slots for this run is \$NSLOTS"
 
echo " "

echo "Now running..."

if [ -x $name ]; then 
        ./$name > ./${name}.output.\${JOB_ID}.\${SGE_TASK_ID}
else
        echo -e "\n\t Matlab stand-alone executable ${name} does not exist!"
        echo -e "\n\t Please compile first and resubmit!"
fi

echo ""
echo "Task \${SGE_TASK_ID} of job \$JOB_ID terminated on: "\`date\`
echo ""

EOF


# COMPILE SMD SCRIPT NEEDS TO BE CREATED AFTER THE ARRAY JOB CMD FILE:

    cat << EOF > ./${name_submit_script}_comp_step.cmd
#!/bin/bash
#
#  UGE job for example.cmd built Fri May 26 13:52:07 PDT 2017
#
#  The following items pertain to this script
#  Use current working directory
#$ -cwd
#  input           = /dev/null
#  output          = ./${name}_comp_step.joblog
#$ -o  ./${name}_comp_step.joblog.\$JOB_ID
#  error           = Merged with joblog
#$ -j y
#
#  Resources requested
#$ -pe $PE $slots
#$ -l h_data=${mem}g,h_vmem=INFINITY,h_rt=${time}:00:00$hp
#
#  Name of application for log
#$ -v QQAPP=parallel
#  Email address to notify
#$ -M $USER@mail
#  Notify at beginning and end of job
#$ -m bea
#  Job is not rerunable
#$ -r n
#
#
#  Uncomment the next line to have your environment variables used by SGE
#$ -V
#

echo ""
echo "Job \$JOB_ID started on:   "\` hostname -s \`
echo "Job \$JOB_ID started on:   "\` date \`
echo ""

. /u/local/Modules/default/init/modules.sh
module load matlab/R2020a
module li
export MCR_CACHE_ROOT=\$TMPDIR
echo " "

echo "mcc -m -R -nodisplay,-singleCompThread ${list_arc} ${list_inc} ${list}"
mcc -m -R -nodisplay,-singleCompThread ${list_arc} ${list_inc} ${list}
echo " "

# license check out error rescheduling support:
if [[ \`tail -n3 ${name}_comp_step.joblog.\$JOB_ID | grep "Licensed number of users already reached" | wc -l\` != 0 ]] || [[ \`tail -n3 ${name}_comp_step.joblog.\$JOB_ID | grep "No licenses available for toolbox" | wc -l\` != 0 ]] || [[ \`tail -n3 ${name}_comp_step.joblog.\$JOB_ID | grep "License checkout failed" | wc -l\` != 0 ]] || [[ \`tail -n3 ${name}_comp_step.joblog.\$JOB_ID | grep "Error checking out license" | wc -l\` != 0 ]] || [[ \`tail -n3 ${name}_comp_step.joblog.\$JOB_ID | grep "Licensing error:" | wc -l\` != 0 ]]; then
	sleep 10m
	exit 99 
fi
echo "Done with compiling..."
echo " "

echo "Now submitting array job (if cmd file exists):"

    chmod u+x ${name_submit_script}.cmd

#echo "FLAG="$FLAG
    
    if [[ -x ${name_submit_script}.cmd ]] & [[ "$FLAG" == "" ]]; then
	qsub ${name_submit_script}.cmd 
    elif [[ -x ${name_submit_script}.cmd ]] & [[ "$FLAG" == "SET" ]]; then
	echo "The submission script: ${name_submit_script}.cmd was successfully created"
    else
	echo "No submission file found please try again... report a problem to hpc@ucla.edu"
    fi


echo ""
echo "Job \$JOB_ID terminated on: "\`date\`
echo ""

EOF



    chmod u+x ${name_submit_script}_comp_step.cmd

#echo "FLAG="$FLAG

    if [[ -x ${name_submit_script}_comp_step.cmd ]] & [[ "$FLAG" == "" ]]; then
	qsub ${name_submit_script}_comp_step.cmd 
    elif [[ -x ${name_submit_script}_comp_step.cmd ]] & [[ "$FLAG" == "SET" ]]; then
	echo "The submission script: ${name_submit_script}_comp_step.cmd was successfully created"
    else
	echo "No submission file found please try again... report a problem to hpc@ucla.edu"
    fi


else


# RUN ARRAY JOB (NO NEED TO RECOMPILE):

    cat << EOF > ./${name_submit_script}.cmd
#!/bin/bash
#
#  UGE job for example.cmd built Fri May 26 13:52:07 PDT 2017
#
#  The following items pertain to this script
#  Use current working directory
#$ -cwd
#  input           = /dev/null
#  output          = ./${name}.joblog.\$JOB_ID.\$TASK_ID
#$ -o  ./${name}.joblog.\$JOB_ID.\$TASK_ID
#  error           = Merged with joblog
#$ -j y
#
#  Resources requested
#$ -pe $PE $slots
#$ -l h_data=${mem}g,h_vmem=INFINITY,h_rt=${time}:00:00$hp
#
#  Name of application for log
#$ -v QQAPP=parallel
#  Email address to notify
#$ -M $USER@mail
#  Notify at beginning and end of job
#$ -m bea
#  Job is not rerunable
#$ -r n
#
#  Job array indexes
#$ -t ${first_task}-${last_task}:${stride}
#
#  Uncomment the next line to have your environment variables used by SGE
#$ -V
#

echo ""
echo "Task \${SGE_TASK_ID} of job \${JOB_ID} started on:   "\` hostname -s \`
echo "Task \${SGE_TASK_ID} of job \$JOB_ID started on:   "\` date \`
echo ""

. /u/local/Modules/default/init/modules.sh
module load matlab/R2020a
#module load intel
module li
export MCR_CACHE_ROOT=\$TMPDIR
echo " "


echo "Number of slots for this run is \$NSLOTS"
 
echo " "

echo "Now running..."

if [ -x $name ]; then 
        ./$name > ./${name}.output.\${JOB_ID}.\${SGE_TASK_ID}
else
        echo -e "\n\t Matlab stand-alone executable ${name} does not exist!"
        echo -e "\n\t Please compile first and resubmit!"
fi

echo ""
echo "Task \${SGE_TASK_ID} of job \$JOB_ID terminated on: "\`date\`
echo ""

EOF

    chmod u+x ${name_submit_script}.cmd

#echo "FLAG="$FLAG
    
    if [[ -x ${name_submit_script}.cmd ]] & [[ "$FLAG" == "" ]]; then
	qsub ${name_submit_script}.cmd 
    elif [[ -x ${name_submit_script}.cmd ]] & [[ "$FLAG" == "SET" ]]; then
	echo "The submission script: ${name_submit_script}.cmd was successfully created"
    else
	echo "No submission file found please try again... report a problem to hpc@ucla.edu"
    fi

fi
