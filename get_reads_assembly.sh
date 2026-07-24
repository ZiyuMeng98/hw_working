#!/bin/bash
set -e

# ==========================================
# 1. 变量与参数设定
# ==========================================
# 线程与内存
THREADS=16
MEMORY=64

# 样本列表（替换为你两个阳性样本的名称前缀）
SAMPLES=("CX2628" "NY2621")

# 目录设定
DATA_DIR="/home/user/working/20260721_Plasmodium/01.qc_and_host_result"       # 去除宿主后的 FASTQ 目录
KRAKEN_DIR="/home/user/working/20260721_Plasmodium/02.kraken2_result"         # Kraken2 输出结果目录
REF_FASTA="/home/user/database/Plasmodium_falciparum_3D7_GCF_000002765.6/genome.fa"   # 恶性疟原虫参考基因组 (如 3D7)
OUT_DIR="/home/user/working/20260721_Plasmodium/04.assembly_rawdata"      # 本次分析输出总目录

mkdir -p ${OUT_DIR}
cd ${OUT_DIR}

# ==========================================
# 2. 循环处理每个样本
# ==========================================
for SAMPLE in "${SAMPLES[@]}"; do
    echo "=================================================="
    echo " processing begin: ${SAMPLE} [ $(date) ]"
    echo "=================================================="

    # 路径定义
    R1_IN="${DATA_DIR}/${SAMPLE}/${SAMPLE}_parasite_R1.fq.gz"
    R2_IN="${DATA_DIR}/${SAMPLE}/${SAMPLE}_parasite_R2.fq.gz"
    KRAKEN_OUT="${KRAKEN_DIR}/${SAMPLE}.kraken"
    KREPORT_OUT="${KRAKEN_DIR}/${SAMPLE}.kreport"
    
    SAMPLE_OUT="${OUT_DIR}/${SAMPLE}"
    mkdir -p ${SAMPLE_OUT}
    cd ${SAMPLE_OUT}

    # --------------------------------------------------
    # Step 1: 使用 KrakenTools 提取所有疟原虫 Reads (TaxID: 5820)
    # --------------------------------------------------
    # 说明: -t 5820 是 Plasmodium 属的 TaxID，--include-children 会同时提取 
    #      P. falciparum (5833)、P. reichenowi (5855) 及所有子分类 Reads。
    echo ">>> [1/4] getting (Plasmodium spp.) reads..."
    
    conda run -n metagenomics_env extract_kraken_reads.py -k ${KRAKEN_OUT} -r ${KREPORT_OUT} -s1 ${R1_IN} -s2 ${R2_IN} -t 5820 --include-children -o ${SAMPLE}_plasmodium_R1.fastq -o2 ${SAMPLE}_plasmodium_R2.fastq --fastq-output

    # 压缩提取出的 FASTQ 备用
    gzip -f ${SAMPLE}_plasmodium_R1.fastq
    gzip -f ${SAMPLE}_plasmodium_R2.fastq

    P_R1="${SAMPLE}_plasmodium_R1.fastq.gz"
    P_R2="${SAMPLE}_plasmodium_R2.fastq.gz"

    # 统计提取出的 Reads 数量
    READ_COUNT=$(zcat ${P_R1} | wc -l | awk '{print $1/4}')
    echo "提取完成，共获得 ${READ_COUNT} 对 疟原虫 Reads。"

    # 如果 Reads 极少（< 1000），则预警
    if [ "${READ_COUNT}" -lt 1000 ]; then
        echo "[WARNING] 样本 ${SAMPLE} 提取出的 Reads 数量较低 (${READ_COUNT})，组装深度可能不足。"
    fi

    # --------------------------------------------------
    # Step 2: De Novo 基因组组装 (使用 SPAdes)
    # --------------------------------------------------
    # 说明: 疟原虫基因组极度偏向 AT (AT-content > 80%)，SPAdes 在高 AT 区域表现优异。
    #      如果读段深度不高，建议使用常规模式或 --meta 模式。
    echo ">>> [2/4] 正在进行 SPAdes 基因组组装..."
    
    conda run -n metagenomics_env spades.py --meta -1 ${P_R1} -2 ${P_R2} -o ${SAMPLE_OUT}/spades_out -t ${THREADS} -m ${MEMORY}

    # 过滤掉较短的 contigs (例如 < 500 bp)
    conda run -n metagenomics_env seqkit seq -m 500 ${SAMPLE_OUT}/spades_out/contigs.fasta > ${SAMPLE_OUT}/${SAMPLE}_contigs_500bp.fasta

    # --------------------------------------------------
    # Step 3: 参考基因组引导的 Scaffold 搭建 (RagTag)
    # --------------------------------------------------
    # 说明: 由于临床/mNGS 测序深度限制，De Novo 组装出的 Contig 可能较碎。
    #      使用 P. falciparum 3D7 参考基因组可以将 Contigs 贴到染色体水平。
    echo ">>> [3/4] 使用 RagTag 进行参考基因组指导的染色体构建..."
    
    conda run -n metagenomics_env ragtag.py scaffold ${REF_FASTA} ${SAMPLE_OUT}/${SAMPLE}_contigs_500bp.fasta -o ${SAMPLE_OUT}/ragtag_out -t ${THREADS}

    cp ${SAMPLE_OUT}/ragtag_out/ragtag.scaffold.fasta ${SAMPLE_OUT}/${SAMPLE}_final_scaffolds.fasta

    # --------------------------------------------------
    # Step 4: 组装质量评估 (QUAST)
    # --------------------------------------------------
    echo ">>> [4/4] 使用 QUAST 评估组装质量..."
    
    conda run -n metagenomics_env quast.py ${SAMPLE_OUT}/${SAMPLE}_final_scaffolds.fasta -r ${REF_FASTA} -o ${SAMPLE_OUT}/quast_out -t ${THREADS}

    echo "sample: ${SAMPLE} finished!location: ${SAMPLE_OUT}"
    cd ${OUT_DIR}
done

echo "=================================================="
echo " all procession finished! [ $(date) ]"
echo "=================================================="
