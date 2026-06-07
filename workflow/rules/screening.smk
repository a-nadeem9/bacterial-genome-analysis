# This file contains all optional screening rules

# --- RGI Database Setup ---
RGI_DB_DIR = "databases/rgi_db"
rule rgi_db_download:
    output:
        data_archive=f"{RGI_DB_DIR}/downloads/data.tar.bz2",
        variants_archive=f"{RGI_DB_DIR}/downloads/variants.tar.bz2"
    params:
        data_url=config["rgi_db"]["data_url"],
        variants_url=config["rgi_db"]["variants_url"]
    log:
        f"{RGI_DB_DIR}/logs/download.log"
    conda:
        "../envs/rgi.yaml"
    shell:
        "mkdir -p $(dirname {output.data_archive}) && "
        "wget -O {output.data_archive} {params.data_url} > {log} 2>&1 && "
        "wget -O {output.variants_archive} {params.variants_url} >> {log} 2>&1"
rule rgi_db_extract:
    input:
        data_archive=rules.rgi_db_download.output.data_archive,
        variants_archive=rules.rgi_db_download.output.variants_archive
    output:
        card_json=f"{RGI_DB_DIR}/extracted/card.json",
        wildcard_index=f"{RGI_DB_DIR}/extracted/wildcard/index-for-model-sequences.txt",
        wildcard_dir=directory(f"{RGI_DB_DIR}/extracted/wildcard")
    log:
        f"{RGI_DB_DIR}/logs/extract.log"
    shell:
        "mkdir -p $(dirname {output.card_json}) && "
        "mkdir -p {output.wildcard_dir} && "
        "tar -xjf {input.data_archive} -C $(dirname {output.card_json}) && "
        "tar -xjf {input.variants_archive} -C {output.wildcard_dir} && "
        "gunzip {output.wildcard_dir}/index-for-model-sequences.txt.gz"
rule rgi_db_annotate:
    input:
        card_json=rules.rgi_db_extract.output.card_json,
        wildcard_dir=f"{RGI_DB_DIR}/extracted/wildcard"
    output:
        card_fasta=f"{RGI_DB_DIR}/annotations/card_database.fasta",
        wildcard_fasta=f"{RGI_DB_DIR}/annotations/wildcard_database.fasta"
    params:
        version=config["rgi_db"]["wildcard_version"]
    log:
        f"{RGI_DB_DIR}/logs/annotate.log"
    conda:
        "../envs/rgi.yaml"
    shell:
        "mkdir -p $(dirname {output.card_fasta}) && "
        "rgi card_annotation --input {input.card_json} > {output.card_fasta} 2>{log} && "
        "rgi wildcard_annotation --input_directory {input.wildcard_dir} "
        "--card_json {input.card_json} -v '{params.version}' 2>>{log} && "
        "mv wildcard_database_v{params.version}.fasta {output.wildcard_fasta} && "
        "rm -f *_database_v*.fasta"
rule rgi_db_load:
    input:
        card_json=rules.rgi_db_extract.output.card_json,
        card_fasta=rules.rgi_db_annotate.output.card_fasta,
        wildcard_fasta=rules.rgi_db_annotate.output.wildcard_fasta,
        wildcard_index=rules.rgi_db_extract.output.wildcard_index
    output:
        sentinel=touch(f"{RGI_DB_DIR}/load_successful.flag")
    params:
        version=config["rgi_db"]["wildcard_version"]
    log:
        f"{RGI_DB_DIR}/logs/load.log"
    conda:
        "../envs/rgi.yaml"
    shell:
        "rgi load --card_json {input.card_json} "
        "--card_annotation {input.card_fasta} "
        "--wildcard_annotation {input.wildcard_fasta} "
        "--wildcard_index {input.wildcard_index} "
        "--wildcard_version '{params.version}' "
        "--local > {log} 2>&1"

# --- ABRicate Database Setup ---
ABRICATE_DB_DIR = config["abricate_db_dir"]
rule abricate_download_dbs:
    output:
        sentinel=touch(f"{ABRICATE_DB_DIR}/.download_complete")
    log:
        "logs/abricate_download_dbs.log"
    params:
        dbs=" ".join(config["abricate_databases"])
    conda:
        "../envs/abricate.yaml"
    threads: 1
    shell:
        "mkdir -p {ABRICATE_DB_DIR} && "
        "for db in {params.dbs}; do "
        "    echo 'Downloading ABRicate DB: ' $db ; "
        "    abricate-get_db --dbdir {ABRICATE_DB_DIR} --db $db --force >> {log} 2>&1 ; "
        "done"
rule abricate_setup_db:
    input:
        db_downloaded=rules.abricate_download_dbs.output.sentinel
    output:
        sentinel=touch(f"{ABRICATE_DB_DIR}/.setup_complete")
    log:
        "logs/abricate_setup_db.log"
    conda:
        "../envs/abricate.yaml"
    threads: 1
    shell:
        "abricate --datadir {ABRICATE_DB_DIR} --setupdb > {log} 2>&1"

# --- Platon Database Setup ---
PLATON_DB_DIR = config["platon_db"]["dir"]
rule platon_db_download:
    output:
        tarball=f"{PLATON_DB_DIR}/db.tar.gz"
    params:
        url=config["platon_db"]["url"]
    log:
        "logs/platon_db_download.log"
    conda:
        "../envs/platon.yaml"
    shell:
        "mkdir -p $(dirname {output.tarball}) && "
        "wget -O {output.tarball} '{params.url}' > {log} 2>&1"
rule platon_db_verify_and_extract:
    input:
        tarball=rules.platon_db_download.output.tarball
    output:
        sentinel=touch(f"{PLATON_DB_DIR}/db/rds.tsv")
    params:
        expected_md5=config["platon_db"]["md5"],
        db_dir=PLATON_DB_DIR
    log:
        "logs/platon_db_extract.log"
    conda:
        "../envs/platon.yaml"
    shell:
        "(echo '{params.expected_md5}  {input.tarball}' | md5sum -c - >> {log} 2>&1) || "
        '(echo "MD5 checksum failed for {input.tarball}" && exit 1); '
        "tar -xzvf {input.tarball} -C {params.db_dir} >> {log} 2>&1 && "
        "rm {input.tarball}"

# --- Main Analysis Rules ---
rule run_mlst:
    input:
        fasta="results/polishing/{sample}/03_pilon.fasta"
    output:
        tsv="results/screening/mlst/{sample}.tsv"
    params:
        scheme_flag=lambda wildcards: f'--scheme {config["screening"]["mlst"]["scheme"]}' if config["screening"]["mlst"]["scheme"] != "auto" else ""
    log:
        "logs/screening/mlst/{sample}.log"
    threads: 1
    conda:
        "../envs/mlst.yaml"
    shell:
        "mlst --quiet {params.scheme_flag} {input.fasta} > {output.tsv} 2> {log}"
rule run_amr:
    input:
        fasta="results/polishing/{sample}/03_pilon.fasta",
        db_sentinel=f"{RGI_DB_DIR}/load_successful.flag"
    output:
        txt="results/screening/amr/{sample}.txt"
    params:
        prefix=lambda wildcards: f"results/screening/amr/{wildcards.sample}",
        loose_flag="--include_loose" if config["screening"]["amr"]["include_loose"] else ""
    log:
        "logs/screening/amr/{sample}.log"
    threads: 8
    conda:
        "../envs/rgi.yaml"
    shell:
        "rgi main "
        "-i {input.fasta} "
        "-o {params.prefix} "
        "-t contig "
        "--local "
        "{params.loose_flag} "
        "-n {threads} > {log} 2>&1"
rule run_virulence:
    input:
        fasta="results/polishing/{sample}/03_pilon.fasta",
        db_sentinel=rules.abricate_setup_db.output.sentinel
    output:
        tsv="results/screening/virulence/{sample}.tsv"
    params:
        datadir=ABRICATE_DB_DIR,
        min_id=config["screening"]["virulence"]["min_identity"],
        min_cov=config["screening"]["virulence"]["min_coverage"]
    log:
        "logs/screening/virulence/{sample}.log"
    threads: 1
    conda:
        "../envs/abricate.yaml"
    shell:
        "abricate "
        "--datadir {params.datadir} "
        "--db vfdb "
        "--minid {params.min_id} "
        "--mincov {params.min_cov} "
        "--quiet "
        "{input.fasta} > {output.tsv} 2> {log}"

rule run_plasmids:
    input:
        fasta="results/polishing/{sample}/03_pilon.fasta",
        db_sentinel=rules.platon_db_verify_and_extract.output.sentinel
    output:
        tsv="results/screening/plasmids/{sample}.tsv"
    params:
        db_path=f"{PLATON_DB_DIR}/db",
        # Platon creates other files, we give it a directory to put them in.
        outdir=lambda wildcards, output: os.path.dirname(output.tsv)
    log:
        "logs/screening/plasmids/{sample}.log"
    threads: 8
    conda:
        "../envs/platon.yaml"
    shell:
        # FIX: Redirect stdout (>) to the output file and stderr (2>) to the log file
        "platon "
        "--db {params.db_path} "
        "--output {params.outdir} "
        "--threads {threads} "
        "{input.fasta} > {output.tsv} 2> {log}"
