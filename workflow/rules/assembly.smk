# This file contains all rules related to Genome Assembly

rule spades_assembly:
    input:
        r1 = "results/trimmed/{sample}_1.trimmed.fastq.gz",
        r2 = "results/trimmed/{sample}_2.trimmed.fastq.gz"
    output:
        fasta = "results/assembly/{sample}/scaffolds.fasta"
    params:
        outdir = lambda wildcards: os.path.dirname(f"results/assembly/{wildcards.sample}/scaffolds.fasta"),
        k_mers = config["assembly"]["spades"]["k_mers"],
        plasmid_flag = "--plasmid" if config["assembly"]["spades"]["plasmid_mode"] else "",
        extra = config["assembly"]["spades"]["extra"]
    log:
        "logs/spades/{sample}.log"
    threads:
        config["assembly"]["spades"]["threads"]
    conda:
        "../envs/assembly.yaml"
    shell:
        "spades.py "
        "-1 {input.r1} -2 {input.r2} "
        "-o {params.outdir} "
        "-k {params.k_mers} "
        "-t {threads} "
        "-m {config[assembly][spades][memory]} "
        "{params.plasmid_flag} "
        "{params.extra} "
        "> {log} 2>&1"

rule unicycler_assembly:
    input:
        r1 = "results/trimmed/{sample}_1.trimmed.fastq.gz",
        r2 = "results/trimmed/{sample}_2.trimmed.fastq.gz",
        long = "results/trimmed/{sample}.long.trimmed.fastq.gz"
    output:
        fasta = "results/assembly/{sample}/assembly.fasta"
    params:
        outdir = lambda wildcards: os.path.dirname(f"results/assembly/{wildcards.sample}/assembly.fasta"),
        mode = config["assembly"]["unicycler"]["mode"],
        min_len = config["assembly"]["unicycler"]["min_fasta_length"],
        keep = config["assembly"]["unicycler"]["keep_level"],
        extra = config["assembly"]["unicycler"]["extra"]
    log:
        "logs/unicycler/{sample}.log"
    threads:
        config["assembly"]["unicycler"]["threads"]
    conda:
        "../envs/assembly.yaml"
    shell:
        "unicycler "
        "-1 {input.r1} -2 {input.r2} "
        "-l {input.long} "
        "-o {params.outdir} "
        "--mode {params.mode} "
        "--min_fasta_length {params.min_len} "
        "--keep {params.keep} "
        "{params.extra} "
        "-t {threads} "
        "> {log} 2>&1"
