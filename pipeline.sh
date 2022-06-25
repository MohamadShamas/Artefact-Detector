 #!/bin/bash
 memory=32;
 time=18;
 first_file_idx=1;
 last_file_idx=3;
 
 RippleLab_path="/u/project/rstaba/DATA/scripts/RIPPLELAB-master/"
 Complete_pipeline_path="/u/project/rstaba/DATA/scripts/"


 ./matlab_compile_array_job.sh -t $time -m $memory -p 1 -I ${RippleLab_path}Functions/Miscellaneous/ -I ${RippleLab_path}Functions/Signal/ -I ${RippleLab_path}Functions/HFO/ -I ${RippleLab_path}Functions/FileIO/ -I ${RippleLab_path}External/FileIO/ -I ${RippleLab_path}External/FieldTrip/fileio/ -I ${RippleLab_path}External/FieldTrip/fileio/private/ -I ${RippleLab_path}External/FieldTrip/preproc/ -I ${Complete_pipeline_path} -f complete_pipeline.m -ft ${first_file_idx} -lt ${last_file_idx} -ts 1
