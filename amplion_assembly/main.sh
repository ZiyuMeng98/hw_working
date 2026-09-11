import os
import sys
import subprocess
import argparse

def parse_args():
    parser = argparse.ArgumentParser(description="SARS-CoV-2 Amplicon Assembly Pipeline")
    
    parser.add_argument("--WORK_DIR", required=True, help="Working directory path")
    parser.add_argument("--REF_FA", required=True, help="Reference FASTA file path")
    parser.add_argument("--REF_MMI", required=True, help="Reference MMI index file path")
    parser.add_argument("--LEFT_FASTA", required=True, help="Left primer FASTA file path")
    parser.add_argument("--RIGHT_FASTA", required=True, help="Right primer FASTA file path")
    parser.add_argument("--SCRIPT_DIR", default=os.path.expanduser("~/script/amplicon_assembly"), 
                        help="Directory containing 01~09 scripts (default: ~/script/amplicon_assembly)")
    
    return parser.parse_args()

def main():
    args = parse_args()

    work_dir = args.WORK_DIR.rstrip('/')
    
    os.environ["WORK_DIR"] = work_dir
    os.environ["REF_FA"] = args.REF_FA
    os.environ["REF_MMI"] = args.REF_MMI
    os.environ["LEFT_FASTA"] = args.LEFT_FASTA
    os.environ["RIGHT_FASTA"] = args.RIGHT_FASTA

    log_dir = os.path.join(work_dir, "logs")
    os.makedirs(log_dir, exist_ok=True)

    script_steps = [
        "01.artic_guppyplex.sh",
        "02.cutadapt.sh",
        "03.align_and_sort.sh",
        "04.depth_calculate.sh",
        "05.low_cover_bed.sh",
        "06.freebayes.sh",
        "07.vcf_filter.sh",
        "08.consensus.sh"
    ]

    script_dir = os.path.expanduser(args.SCRIPT_DIR)

    print("==================================================")
    print(f" Starting Amplicon Assembly Pipeline")
    print(f" WORK_DIR: {work_dir}")
    print(f" LOG_DIR:  {log_dir}")
    print("==================================================")

    for step in script_steps:
        script_path = os.path.join(script_dir, step)
        log_name = f"{os.path.splitext(step)[0]}.log"
        log_path = os.path.join(log_dir, log_name)

        if not os.path.isfile(script_path):
            print(f"ERROR: Script not found: {script_path}")
            sys.exit(1)

        print(f"\n>>> Running: {step}")
        cmd = f"bash {script_path} 2>&1 | tee {log_path}"

        result = subprocess.run(cmd, shell=True, env=os.environ)

        if result.returncode != 0:
            print(f"\n[ERROR] Step {step} failed! Check log: {log_path}")
            sys.exit(result.returncode)

    print("\nPipeline completed successfully!")

if __name__ == "__main__":
    main()
