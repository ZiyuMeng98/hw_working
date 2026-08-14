ls 00.raw_data/ > samples.txt
mkdir logs/
bash ~/script/amplicon_genome_qc/artic_guppyplex.sh 2>&1 | tee logs/artic_guppyplex.log
bash ~/script/amplicon_genome_qc/minimap2_samtools.sh 2>&1 | tee logs/minimap2_samtools.log
